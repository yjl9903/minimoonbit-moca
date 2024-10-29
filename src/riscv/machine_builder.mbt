pub fn build_machine_ir(world : @ssa.World) -> MachineWorld {
  let machine = { globals: Map::new(), methods: [], ssa: world }
  // 1. Add global variables
  world.global.each(
    fn { v => machine.globals.set(v.id, MachineVar::from_ssa(v)) },
  )
  // 2. Add methods
  machine.methods.push(
    create_machine_method(machine, world.main_method, is_main=true),
  )
  world.methods
  .values()
  .each(fn { m => machine.methods.push(create_machine_method(machine, m)) })
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
    is_closure: method.is_closure,
    free_vars: method.formal_free_vars,
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
    size: var.size,
    offset: -1,
    param_offset: None,
    is_this: var.is_this,
    is_param: var.is_param,
    is_global: var.is_global,
    is_mut: var.is_mut,
    is_live: true,
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
  mut vars_counter : Int

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
  let max_id = vars
    .values()
    .fold(fn { acc, var => @math.maximum(acc, var.id + 1) }, init=0)
  Builder::{ method, vars, vars_counter: max_id + 1, world }
}

fn Builder::get_var(self : Builder, var : @ssa.Var) -> MachineVar {
  if var.is_global {
    match self.world.globals.get(var.id) {
      Some(v) => v
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
  let id = self.vars_counter
  self.vars_counter = self.vars_counter + 1
  let var = {
    id,
    name: None,
    ty,
    size: @ssa.get_type_size(ty),
    offset: -1,
    param_offset: None,
    is_this: false,
    is_param: false,
    is_global: false,
    is_mut: false,
    is_phi: false,
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
  let id = self.vars_counter
  self.vars_counter = self.vars_counter + 1
  let var = {
    id,
    name: None,
    ty: Int,
    size: @ssa.get_type_size(Int),
    offset: -1,
    param_offset: None,
    is_this: false,
    is_param: false,
    is_global: false,
    is_mut: false,
    is_live: true,
    is_phi: false,
    const_value: Some(Int(value)),
    incoming_vars: [],
    outcoming_var: None,
  }
  self.vars.set(id, var)
  self.method.local_vars.push(var)
  var
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
}

fn Builder::build_stmt(self : Builder, stmt : @ssa.Stmt) -> Array[StmtKind] {
  match stmt.stmt {
    Definition(var, rvalue) => {
      let (rvalue, stmts) = self.build_rvalue(rvalue)
      match var {
        Some(var) =>
          if var.is_const() {
            []
          } else if var.is_global {
            @util.die("todo")
          } else {
            let def = self.get_var(var)
            match rvalue {
              Var(rvalue, kind) => {
                let mut found_tmp = false
                let transformed_stmts = stmts.map(
                  fn {
                    stmt =>
                      match stmt {
                        Definition(Some(tmp), _ as body) =>
                          if tmp.id == rvalue.id {
                            found_tmp = true
                            tmp.is_live = false
                            Definition(Some(def), body)
                          } else {
                            stmt
                          }
                        Store((tmp, offset), expr, kind) =>
                          if tmp.id == rvalue.id {
                            Store((def, offset), expr, kind)
                          } else {
                            stmt
                          }
                        StoreLabel((tmp, offset), label) =>
                          if tmp.id == rvalue.id {
                            StoreLabel((def, offset), label)
                          } else {
                            stmt
                          }
                        _ => stmt
                      }
                  },
                )
                if not(found_tmp) {
                  transformed_stmts.push(
                    Definition(Some(def), Var(rvalue, kind)),
                  )
                }
                transformed_stmts
              }
              _ => {
                stmts.push(Definition(Some(def), rvalue))
                stmts
              }
            }
          }
        None =>
          match rvalue {
            InvokeDirect(_) | InvokeClosure(_) => [Definition(None, rvalue)]
            _ => []
          }
      }
    }
    PutArray(recv, idx, value) => {
      let ty = @closure.extract_array_type(recv.ty)
      let addr = self.add_temp_var(Int)
      let offset = self.add_temp_var(Int)
      let (kind, width) = match ty {
        Double => (PrimKind::Double, @ssa.f64_size)
        _ => (PrimKind::Int, @ssa.i32_size)
      }
      let size_var = self.add_int_const_var(width)
      [
        Definition(Some(offset), Prim(self.get_var(idx), size_var, Mul, Int)),
        Definition(Some(addr), Prim(self.get_var(recv), offset, Add, Int)),
        Store((addr, 0), self.get_var(value), kind),
      ]
    }
    IfGoto(cond, true_branch, false_branch, _) => {
      let kind = match cond {
        Eq(lhs, _) | Le(lhs, _) =>
          match lhs.ty {
            Double => PrimKind::Double
            _ => PrimKind::Int
          }
      }
      let cond = match cond {
        Eq(lhs, rhs) => Eq(self.get_var(lhs), self.get_var(rhs), kind)
        Le(lhs, rhs) => Le(self.get_var(lhs), self.get_var(rhs), kind)
      }
      [IfGoto(cond, true_branch, false_branch)]
    }
    Goto(l) => [Goto(l)]
    Break(_, l) => [Goto(l)]
    Continue(l) => [Goto(l)]
    Nop => [Nop]
    Return(v) => [Return(v.map(fn { v => self.get_var(v) }))]
  }
}

fn Builder::build_rvalue(
  self : Builder,
  rvalue : @ssa.RValue
) -> (RValue, Array[StmtKind]) {
  match rvalue {
    Unit => (Int(0), [])
    Int(x) => (Int(x), [])
    Double(x) => @util.die("todo")
    Neg(v, kind) => (Neg(self.get_var(v), kind), [])
    Prim(lhs, rhs, op, kind) =>
      (Prim(self.get_var(lhs), self.get_var(rhs), op, kind), [])
    Var(v) => {
      let var = self.get_var(v)
      match var.const_value {
        Some(Int(x)) => (Int(x), [])
        Some(Double(x)) => @util.die("todo")
        None =>
          if var.is_global {
            // TODO
            @util.die("todo")
          } else {
            (
              Var(
                self.get_var(v),
                match v.ty {
                  Double => Double
                  _ => Int
                },
              ),
              [],
            )
          }
      }
    }

    // 
    Tuple(els) => {
      let size = @ssa.get_tuple_types_size(els)
      let def = self.add_temp_var(Tuple(els.map(fn { e => e.ty })))
      let def_stmt = Definition(Some(def), Malloc(size))
      let stmts = [def_stmt]
      let mut offset = 0
      for i = 0; i < els.length(); i = i + 1 {
        let el = els[i]
        match el.ty {
          Double => {
            stmts.push(Store((def, offset), self.get_var(el), Double))
            offset += @ssa.f64_size
          }
          _ => {
            stmts.push(Store((def, offset), self.get_var(el), Int))
            offset += @ssa.i32_size
          }
        }
      }
      (Var(def, Int), stmts)
    }
    Closure(label, fvs) => {
      let size = @ssa.get_free_vars_size(fvs.map(fn { fv => fv.0 }))
      let def = self.add_temp_var(Type::Ptr)
      let def_stmt = Definition(Some(def), Malloc(size))
      let stmts = [def_stmt]
      // 1. Store fp
      let mut offset = @ssa.i32_size
      stmts.push(StoreLabel((def, 0), create_method_label(label)))
      // 2. Store fields
      fvs.sort_by_key(fn { (fv, _) => fv.slot })
      fvs.each(
        fn {
          (fv, var) =>
            match fv.ty {
              Double => {
                stmts.push(Store((def, offset), self.get_var(var), Double))
                offset += @ssa.f64_size
              }
              _ => {
                stmts.push(Store((def, offset), self.get_var(var), Int))
                offset += @ssa.i32_size
              }
            }
        },
      )
      (Var(def, Int), stmts)
    }

    //
    GetTuple(var, idx) => {
      let types = @closure.extract_tuple_type(var.ty)
      let offset = @ssa.get_tuple_size(types, slice=Some(idx))
      (
        Load(
          (self.get_var(var), offset),
          match types[idx] {
            Double => Double
            _ => Int
          },
        ),
        [],
      )
    }
    GetClosure(recv, fv, all_fvs) => {
      let offset = @ssa.get_free_vars_size(all_fvs, target=Some(fv))
      (
        Load(
          (self.get_var(recv), offset),
          match fv.ty {
            Double => Double
            _ => Int
          },
        ),
        [],
      )
    }
    GetArray(recv, idx) => {
      let ty = @closure.extract_array_type(recv.ty)
      let addr = self.add_temp_var(Int)
      let offset = self.add_temp_var(Int)
      let (kind, width) = match ty {
        Double => (PrimKind::Double, @ssa.f64_size)
        _ => (PrimKind::Int, @ssa.i32_size)
      }
      let size_var = self.add_int_const_var(width)
      let def_var = self.add_temp_var(ty)
      let stmts = [
        Definition(Some(offset), Prim(self.get_var(idx), size_var, Mul, Int)),
        Definition(Some(addr), Prim(self.get_var(recv), offset, Add, Int)),
        Definition(Some(def_var), Load((addr, 0), kind)),
      ]
      (
        Var(
          def_var,
          match ty {
            Double => Double
            _ => Int
          },
        ),
        stmts,
      )
    }

    // Invoke
    InvokeDirect(label, args) => {
      let ty = self.world.ssa.get_method_type(label).unwrap()
      let ret_type = @closure.extract_return_type(ty)
      let invoke = InvokeDirect(
        create_method_label(label),
        args.map(fn { a => self.get_var(a) }),
        match ret_type {
          Double => Double
          _ => Int
        },
      )
      (invoke, [])
    }
    InvokeClosure(callee, args) => {
      let ret_type = @closure.extract_return_type(callee.ty)
      let invoke = InvokeClosure(
        self.get_var(callee),
        args.map(fn { a => self.get_var(a) }),
        match ret_type {
          Double => Double
          _ => Int
        },
      )
      (invoke, [])
    }

    // Phi
    Phi(vars) => (Phi(vars.map(fn { v => self.get_var(v) })), [])
  }
}
