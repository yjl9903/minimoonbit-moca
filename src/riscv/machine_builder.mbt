let vars_counter : Ref[Int] = { val: 0 }

pub fn build_machine_world(world : @ssa.World) -> MachineWorld {
  vars_counter.val = @ssa.global_vars_counter.val + 1
  let machine = {
    globals: Map::new(),
    doubles: Map::new(),
    methods: [],
    ssa: world,
  }
  // 1. Add global variables
  world.global.each(
    fn {
      v =>
        machine.globals.set(
          v.id,
          (create_global_variable_label(v), MachineVar::from_ssa(v)),
        )
    },
  )
  // 2. Add methods
  machine.methods.push(
    create_machine_method(machine, world.main_method, is_main=true),
  )
  world.methods
  .values()
  .each(fn { m => machine.methods.push(create_machine_method(machine, m)) })
  cached_world.val = Some(machine)
  machine
}

fn create_machine_method(
  world : MachineWorld,
  method : @ssa.Method,
  ~is_main : Bool = false
) -> MachineMethod {
  let local_vars = method.local_vars.map(fn { p => MachineVar::from_ssa(p) })
  let param_vars = local_vars.filter(fn { v => v.is_param })
  let this_var = match
    local_vars.search_by(fn { v => v.is_this && v.is_param }) {
    Some(idx) => Some(local_vars[idx])
    None => None
  }
  let machine = {
    id: method.slot,
    name: if is_main {
      "minimbt_main"
    } else {
      method.name
    },
    label: if is_main {
      "minimbt_main"
    } else {
      create_method_label(method.name)
    },
    ty: method.ty,
    is_main,
    this: this_var,
    params: param_vars,
    local_vars,
    body: { stmts: [], blocks: [] },
    stack_vars: Map::new(),
    stack_size: 0,
    tail_calls: @hashset.new(),
    is_closure: method.is_closure,
    free_vars: method.formal_free_vars,
    ssa_method: Some(method),
  }
  let builder = Builder::new(world, machine)
  builder.build(method)
  machine
}

fn MachineVar::from_ssa(var : @ssa.Var) -> MachineVar {
  {
    id: var.id,
    name: var.name,
    ty: var.ty,
    width: Width::from_low_type(var.ty),
    size: get_type_size(var.ty),
    offset: -1,
    param_offset: None,
    is_this: var.is_this,
    is_param: var.is_param,
    is_global: var.is_global,
    is_mut: var.is_mut,
    is_live: true,
    is_stack: not(var.is_const()),
    const_value: match var.const_value {
      Some(Int(x)) => Some(Int(x))
      Some(Double(x)) => Some(Double(x))
      _ => None
    },
    is_phi: false,
    incoming_vars: [],
    outcoming_var: None,
  }
}

struct Builder {
  method : MachineMethod
  vars : Map[Int, MachineVar]

  // for global vars
  world : MachineWorld
}

fn Builder::new(world : MachineWorld, method : MachineMethod) -> Builder {
  let vars = Map::new()
  match method.this {
    Some(this) => vars.set(this.id, this)
    None => ()
  }
  method.params.each(fn { p => vars.set(p.id, p) })
  method.local_vars.each(fn { v => vars.set(v.id, v) })
  Builder::{ method, vars, world }
}

fn Builder::get_var(self : Builder, var : @ssa.Var) -> MachineVar {
  if var.is_global {
    match self.world.globals.get(var.id) {
      Some(v) => v.1
      None => @util.die("unreachable")
    }
  } else {
    match self.vars.get(var.id) {
      Some(v) => v
      None => @util.die("unreachable")
    }
  }
}

fn Builder::add_temp_var(self : Builder, ty : Type) -> MachineVar {
  let id = vars_counter.val
  vars_counter.val = vars_counter.val + 1
  let var = {
    id,
    name: None,
    ty,
    width: Width::from_low_type(ty),
    size: get_type_size(ty),
    offset: -1,
    param_offset: None,
    is_this: false,
    is_param: false,
    is_global: false,
    is_mut: false,
    is_phi: false,
    is_stack: true,
    is_live: true,
    const_value: None,
    incoming_vars: [],
    outcoming_var: None,
  }
  self.vars.set(id, var)
  self.method.local_vars.push(var)
  var
}

fn Builder::add_int_const_var(self : Builder, value : Int) -> MachineVar {
  let id = vars_counter.val
  vars_counter.val = vars_counter.val + 1
  let var = {
    id,
    name: None,
    ty: Int,
    width: Width::from_low_type(Int),
    size: get_type_size(Int),
    offset: -1,
    param_offset: None,
    is_this: false,
    is_param: false,
    is_global: false,
    is_mut: false,
    is_live: true,
    is_stack: false,
    is_phi: false,
    const_value: Some(Int(value)),
    incoming_vars: [],
    outcoming_var: None,
  }
  self.vars.set(id, var)
  self.method.local_vars.push(var)
  var
}

fn Builder::add_double_const(world : MachineWorld, value : Double) -> String {
  match world.doubles.get(value) {
    Some(label) => label
    None => {
      let label = create_double_label(value)
      world.doubles.set(value, label)
      label
    }
  }
}

fn Builder::build(self : Builder, method : @ssa.Method) -> Unit {
  // 1. Build phi vars
  method.body.stmts.each(
    fn {
      stmt =>
        match stmt.stmt {
          Definition(Some(lhs), Phi(vars)) => {
            let lhs = self.get_var(lhs)
            lhs.incoming_vars.push_iter(
              vars
              .iter()
              .map(
                fn {
                  v => {
                    let incoming = self.get_var(v)
                    // Should connect self -> self
                    if incoming.id != lhs.id {
                      incoming.is_live = false
                      match incoming.outcoming_var {
                        Some(_) =>
                          @util.die("phi var could not be merged twice")
                        None => incoming.outcoming_var = Some(lhs)
                      }
                    }
                    incoming
                  }
                },
              ),
            )
            lhs.is_phi = true
            lhs.is_live = true
          }
          _ => ()
        }
    },
  )
  // 2. Build stmts
  let body = self.method.body
  let stmts_map = Map::new()
  method.body.stmts.each(
    fn {
      ssa_stmt => {
        let machine = self
          .build_stmt(ssa_stmt)
          .mapi(
            fn { i, stmt => Stmt::new(body.stmts.length() + i, stmt, ssa_stmt) },
          )
        stmts_map.set(ssa_stmt.slot, machine)
        body.stmts.push_iter(machine.iter())
      }
    },
  )
  // 3. Build blocks
  method.body.blocks.each(
    fn {
      blk => {
        let machine_blk = { label: blk.label, stmts: [] }
        body.blocks.push(machine_blk)
        blk.stmts.each(
          fn {
            stmt =>
              machine_blk.stmts.push_iter(
                stmts_map.get(stmt.slot).unwrap().iter(),
              )
          },
        )
      }
    },
  )
  // 4. Prune dead branches
  // let graph = body.build_stmts_graph()
  // let visited = @hashset.new()
  // let queue = @queue.new()
  // queue.push(0)
  // while not(queue.is_empty()) {
  //   let cur = queue.pop().unwrap()
  //   graph
  //   .get_succs(cur)
  //   .each(
  //     fn {
  //       v =>
  //         if not(visited.contains(v)) {
  //           visited.insert(v)
  //           queue.push(v)
  //         }
  //     },
  //   )
  // }
  // body.stmts.each(
  //   fn {
  //     stmt =>
  //       if not(visited.contains(stmt.slot)) {
  //         match stmt.stmt {
  //           Nop | Comment(_) => ()
  //           _ => {
  //             @shared.debug(
  //               "Remove unreachable stmt: \{stmt.slot} \{stmt.stmt} in \{method.name}",
  //             )
  //             let _ = stmt.update(Nop)
  //             ()
  //           }
  //         }
  //       }
  //   },
  // )
}

fn Builder::build_stmt(self : Builder, stmt : @ssa.Stmt) -> Array[StmtKind] {
  let stmts = []
  match self.method.ssa_method {
    Some(method) =>
      stmts.push(StmtKind::Comment("SSA => " + method.print_stmt(stmt.stmt)))
    None => ()
  }
  match stmt.stmt {
    Definition(var, rvalue) => {
      let def_stmts = self.build_definition(var, rvalue)
      stmts.push_iter(def_stmts.iter())
    }
    PutArray(recv, idx, value) => {
      let ty = value.ty
      let width = Width::from_low_type(ty)
      let pos = match idx.const_value {
        Some(Int(x)) => {
          let recv = self.build_get_var(recv, stmts)
          let offset = width.to_int() * x
          if -2048 <= offset && offset < 2048 {
            Some((recv, offset))
          } else {
            None
          }
        }
        _ => None
      }
      let (addr, offset) = match pos {
        Some(pos) => pos
        None => {
          let addr = self.add_temp_var(Type::Ptr)
          let offset = self.add_temp_var(Type::Ptr)
          let recv = self.build_get_var(recv, stmts)
          let size_var = self.add_int_const_var(width.to_int())
          let idx = self.build_get_var(idx, stmts)
          stmts.push(Definition(Some(offset), Prim(idx, size_var, Mul, Ptr)))
          stmts.push(Definition(Some(addr), Prim(recv, offset, Add, Ptr)))
          (addr, 0)
        }
      }
      let value = self.build_get_var(value, stmts)
      stmts.push(Store((addr, offset), value, width, 210)) // store value to addr
    }
    IfGoto(cond, true_branch, false_branch, _) => {
      let kind = match cond {
        Eq(lhs, _) | Le(lhs, _) => Width::from_low_type(lhs.ty)
      }
      let cond = match cond {
        Eq(lhs, rhs) => {
          let lhs = self.build_get_var(lhs, stmts)
          let rhs = self.build_get_var(rhs, stmts)
          Eq(lhs, rhs, kind)
        }
        Le(lhs, rhs) => {
          let lhs = self.build_get_var(lhs, stmts)
          let rhs = self.build_get_var(rhs, stmts)
          Le(lhs, rhs, kind)
        }
      }
      stmts.push(IfGoto(cond, true_branch, false_branch))
    }
    Goto(l) | Break(_, l) | Continue(l) => stmts.push(Goto(l))
    Return(v) =>
      match v {
        Some(v) => {
          let v = self.build_get_var(v, stmts)
          stmts.push(Return(Some(v)))
        }
        None => stmts.push(Return(None))
      }
    Nop => ()
  }
  stmts
}

fn Builder::build_definition(
  self : Builder,
  def : @ssa.Var?,
  rvalue : @ssa.RValue
) -> Array[StmtKind] {
  let stmts : Array[StmtKind] = []
  let mut global_label = None
  let local_def = match def {
    Some(var) =>
      if var.is_const() {
        None
      } else if var.is_global {
        let (label, _) = self.world.globals.get(var.id).unwrap()
        global_label = Some(label)
        let tmp = self.add_temp_var(var.ty)
        Some(tmp)
      } else {
        Some(self.get_var(var))
      }
    None => None
  }
  let rvalue = self.build_rvalue(rvalue, local_def, stmts)
  match local_def {
    Some(local_def) => {
      let _ = match rvalue {
        // Some(rvalue) should add def stmts
        Some(rvalue) => stmts.push(Definition(Some(local_def), rvalue))
        // None means it has been defined
        None => ()
      }
      match global_label {
        Some(label) => {
          let addr = self.add_temp_var(Type::Ptr)
          stmts.push(Definition(Some(addr), LoadLabel(label)))
          stmts.push(Store((addr, 0), local_def, local_def.width, 220))
          stmts
        }
        None => stmts
      }
    }
    None => stmts
  }
}

fn Builder::build_rvalue(
  self : Builder,
  rvalue : @ssa.RValue,
  def : MachineVar?,
  stmts : Array[StmtKind]
) -> RValue? {
  match rvalue {
    Unit => Some(Int(0))
    Int(x) => Some(Int(x))
    Double(x) => {
      if def.is_empty() {
        return None
      }
      let label = add_double_const(self.world, x)
      let addr = self.add_temp_var(Type::Ptr)
      stmts.push(Definition(Some(addr), LoadLabel(label)))
      Some(Load((addr, 0), Double, 201))
    }
    Neg(v, kind) => {
      if def.is_empty() {
        return None
      }
      let v = self.build_get_var(v, stmts)
      let width = Width::from_prim_kind(kind)
      if width == Ptr {
        @util.die("should not be Ptr")
      }
      Some(Neg(v, width))
    }
    Prim(lhs, rhs, op, kind) => {
      if def.is_empty() {
        return None
      }
      let lhs = self.build_get_var(lhs, stmts)
      let rhs = self.build_get_var(rhs, stmts)
      let width = Width::from_prim_kind(kind)
      if width == Ptr {
        @util.die("should not be Ptr")
      }
      Some(Prim(lhs, rhs, op, width))
    }

    // Var
    Var(v) => {
      if def.is_empty() {
        return None
      }
      let var = self.get_var(v)
      match var.const_value {
        Some(Int(x)) => Some(Int(x))
        Some(Double(x)) => {
          let label = add_double_const(self.world, x)
          let addr = self.add_temp_var(Ptr)
          stmts.push(Definition(Some(addr), LoadLabel(label)))
          Some(Load((addr, 0), Double, 202))
        }
        None => {
          let width = Width::from_low_type(var.ty)
          if var.is_global {
            let (label, _) = self.world.globals.get(var.id).unwrap()
            let addr = self.add_temp_var(Ptr)
            stmts.push(Comment("Get global var \{v}"))
            stmts.push(Definition(Some(addr), LoadLabel(label)))
            Some(Load((addr, 0), width, 203))
          } else {
            Some(Var(var, width))
          }
        }
      }
    }

    // 
    Tuple(els) =>
      match def {
        Some(def) => {
          let mut offset = 0
          let size = get_tuple_types_size(els)
          stmts.push(Definition(Some(def), Malloc(size)))
          for i = 0; i < els.length(); i = i + 1 {
            let el = els[i]
            let width = Width::from_low_type(el.ty)
            match width {
              Int => {
                let el = self.build_get_var(el, stmts)
                stmts.push(Store((def, offset), el, width, 240))
                offset += width.to_int()
              }
              Double => {
                let el = self.build_get_var(el, stmts)
                stmts.push(Store((def, offset), el, width, 230))
                offset += width.to_int()
              }
              Ptr => {
                let el = self.build_get_var(el, stmts)
                stmts.push(Store((def, offset), el, width, 230))
                offset += width.to_int()
              }
            }
          }
          None
        }
        None => None
      }
    Closure(label, fvs) =>
      match def {
        Some(def) => {
          let size = get_free_vars_size(fvs.map(fn { fv => fv.0 }))
          let addr = self.add_temp_var(Type::Ptr)
          // 1. Malloc
          stmts.push(Definition(Some(def), Malloc(size)))
          if enable_sanitizer {
            stmts.push(Sanitizer(def, 155))
          }
          // 2. Store function label
          stmts.push(
            Definition(Some(addr), LoadLabel(create_method_label(label))),
          )
          if enable_sanitizer {
            stmts.push(Sanitizer(def, 156))
          }
          stmts.push(Store((def, 0), addr, Ptr, 250))
          // 3. Store fields
          let mut offset = Width::Ptr.to_int()
          fvs.sort_by_key(fn { (fv, _) => fv.slot })
          fvs.each(
            fn {
              (fv, var) => {
                let width = Width::from_low_type(fv.ty)
                match width {
                  Int => {
                    let el = self.build_get_var(var, stmts)
                    stmts.push(Store((def, offset), el, width, 180))
                    offset += width.to_int()
                  }
                  Double => {
                    let el = self.build_get_var(var, stmts)
                    stmts.push(Store((def, offset), el, width, 190))
                    offset += width.to_int()
                  }
                  Ptr => {
                    let el = self.build_get_var(var, stmts)
                    stmts.push(Store((def, offset), el, width, 190))
                    offset += width.to_int()
                  }
                }
              }
            },
          )
          None
        }
        None => None
      }

    //
    GetTuple(base, idx) => {
      if def.is_empty() {
        return None
      }
      let types = @closure.extract_tuple_type(base.ty)
      let el_type = types[idx]
      let offset = get_tuple_size(types, slice=Some(idx))
      let base = self.build_get_var(base, stmts)
      Some(Load((base, offset), Width::from_low_type(el_type), 204))
    }
    GetClosure(recv, fv, all_fvs) => {
      if def.is_empty() {
        return None
      }
      let offset = get_free_vars_size(all_fvs, target=Some(fv))
      let recv = self.build_get_var(recv, stmts)
      Some(Load((recv, offset), Width::from_low_type(fv.ty), 205))
    }
    GetArray(recv, idx) => {
      if def.is_empty() {
        return None
      }
      let ty = @closure.extract_array_type(recv.ty)
      let width = Width::from_low_type(ty)
      let pos = match idx.const_value {
        Some(Int(x)) => {
          let recv = self.build_get_var(recv, stmts)
          let offset = width.to_int() * x
          if -2048 <= offset && offset < 2048 {
            Some((recv, offset))
          } else {
            None
          }
        }
        _ => None
      }
      let (addr, offset) = match pos {
        Some(pos) => pos
        None => {
          let addr = self.add_temp_var(Type::Ptr)
          let offset = self.add_temp_var(Type::Ptr)
          let recv = self.build_get_var(recv, stmts)
          let size_var = self.add_int_const_var(width.to_int())
          let idx = self.build_get_var(idx, stmts)
          stmts.push(Definition(Some(offset), Prim(idx, size_var, Mul, Ptr)))
          stmts.push(Definition(Some(addr), Prim(recv, offset, Add, Ptr)))
          (addr, 0)
        }
      }
      Some(Load((addr, offset), width, 206))
    }

    // Invoke
    InvokeDirect(label, args) =>
      match (label, enable_int_float_conversion) {
        ("minimbt_int_of_float" | "minimbt_truncate", true) => {
          let arg = args[0]
          let arg = self.build_get_var(arg, stmts)
          Some(IntOfFloat(arg))
        }
        ("minimbt_float_of_int", true) => {
          let arg = args[0]
          let arg = self.build_get_var(arg, stmts)
          Some(FloatOfInt(arg))
        }
        _ => {
          let ty = self.world.ssa.get_method_type(label).unwrap()
          let ret_type = @closure.extract_return_type(ty)
          let invoke = InvokeDirect(
            create_method_label(label),
            args.map(fn { a => self.build_get_var(a, stmts) }),
            Width::from_low_type(ret_type),
          )
          if def.is_empty() {
            stmts.push(Definition(None, invoke))
            None
          } else {
            Some(invoke)
          }
        }
      }
    InvokeClosure(callee, args) => {
      let ret_type = @closure.extract_return_type(callee.ty)
      let callee = self.build_get_var(callee, stmts)
      let invoke = InvokeClosure(
        callee,
        args.map(fn { a => self.build_get_var(a, stmts) }),
        Width::from_low_type(ret_type),
      )
      if def.is_empty() {
        stmts.push(Definition(None, invoke))
        None
      } else {
        Some(invoke)
      }
    }

    // Phi
    Phi(vars) => Some(Phi(vars.map(fn { v => self.get_var(v) })))
  }
}

fn Builder::build_get_var(
  self : Builder,
  var : @ssa.Var,
  stmts : Array[StmtKind]
) -> MachineVar {
  if var.is_const() {
    match self.world.globals.get(var.id) {
      Some((_, v)) =>
        match v.const_value {
          Some(Int(_)) => v
          Some(Double(x)) => self.build_double_const(x, stmts)
          None => @util.die("unreachable")
        }
      None =>
        match self.vars.get(var.id) {
          Some(v) =>
            match v.const_value {
              Some(Int(_)) => v
              Some(Double(x)) => self.build_double_const(x, stmts)
              None => @util.die("unreachable")
            }
          None => @util.die("unreachable")
        }
    }
  } else if var.is_global {
    match self.world.globals.get(var.id) {
      Some((label, g)) => {
        let addr = self.add_temp_var(Type::Ptr)
        let tmp = self.add_temp_var(var.ty)
        stmts.push(Comment("Get global var \{var}"))
        stmts.push(Definition(Some(addr), LoadLabel(label)))
        stmts.push(Definition(Some(tmp), Load((addr, 0), g.width, 207)))
        tmp
      }
      None => @util.die("unreachable")
    }
  } else {
    match self.vars.get(var.id) {
      Some(v) => v
      None => @util.die("unreachable")
    }
  }
}

fn Builder::build_double_const(
  self : Builder,
  value : Double,
  stmts : Array[StmtKind]
) -> MachineVar {
  let label = add_double_const(self.world, value)
  let addr = self.add_temp_var(Type::Ptr)
  stmts.push(Definition(Some(addr), LoadLabel(label)))
  let local_const = self.add_temp_var(Double)
  stmts.push(Definition(Some(local_const), Load((addr, 0), Double, 208)))
  local_const
}
