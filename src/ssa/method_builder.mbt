struct MethodBuilder {
  id : Int
  name : String
  ty : Type
  args : Array[(Name, Type)]
  /// main method has a special name
  old_name : Name

  /// Closure
  is_closure : Bool
  formal_free_vars : Array[(Name, Type)]

  /// Builders
  ssa_builder : SsaBuilder
}

fn MethodBuilder::new_main(world_builder : WorldBuilder) -> MethodBuilder {
  let name = "$main"
  let old_name = Name::name_only(name)
  let ty = @closure.LowType::DirectFn([], Unit)
  {
    id: 0,
    name,
    old_name,
    ty,
    args: [],
    is_closure: false,
    formal_free_vars: [],
    ssa_builder: SsaBuilder::new(world_builder, name, old_name, ty),
  }
}

fn MethodBuilder::new(
  world_builder : WorldBuilder,
  def : @closure.FuncDef
) -> MethodBuilder {
  let free_vars = def.formal_free_vars
  // Filter global var
  let free_vars = free_vars.filter(
    fn {
      (name, _) =>
        not(world_builder.global_vars.contains(name)) &&
        not(world_builder.direct_closure.contains(name))
    },
  )
  let is_closure = free_vars.length() > 0
  let builder = {
    id: def.id,
    name: def.name._,
    old_name: def.old_name,
    ty: def.ty,
    args: def.args,
    is_closure,
    formal_free_vars: free_vars,
    ssa_builder: SsaBuilder::new(
      world_builder,
      def.name._,
      def.old_name,
      def.ty,
    ),
  }
  // Build this and free vars
  if is_closure {
    builder.ssa_builder.add_this()
    builder.ssa_builder.add_free_vars(free_vars)
  }
  // Build parms
  builder.ssa_builder.add_param_vars(builder.args)
  builder
}

struct SsaBuilder {
  name : String
  old_name : Name
  ty : Type
  mut this : Var?
  formal_free_vars : Map[Name, FreeVar]
  params : Array[Var]

  // Stmts
  stmts : Array[Stmt]
  blocks : Array[Block]
  mut current_block : Block

  // Transform name to var
  free_vars : Map[Name, Var]
  local_vars : Map[Name, Var]
  local_temp_vars : Array[Var]
  mut free_vars_counter : Int

  // Builder
  loops : Map[Name, LoopBuilder]
  world_builder : WorldBuilder
}

struct LoopBuilder {
  label : Int
  args : Array[(Var, Array[Var])]
}

fn SsaBuilder::new(
  world_builder : WorldBuilder,
  name : String,
  old_name : Name,
  ty : Type
) -> SsaBuilder {
  let current_block = Block::new(0)
  {
    name,
    old_name,
    ty,
    this: None,
    formal_free_vars: Map::new(),
    params: [],
    stmts: [],
    blocks: [current_block],
    current_block,
    free_vars: Map::new(),
    local_vars: Map::new(),
    local_temp_vars: [],
    free_vars_counter: 0,
    loops: Map::new(),
    world_builder,
  }
}

fn SsaBuilder::add_this(self : SsaBuilder) -> Unit {
  self.this = Some(
    {
      id: self.world_builder.global_vars_counter,
      name: Some("%this"),
      ty: self.ty,
      is_this: true,
      is_param: true,
      is_global: false,
      is_mut: false,
      const_value: None,
      is_phi: false,
      outcoming: None,
    },
  )
  self.world_builder.global_vars_counter = self.world_builder.global_vars_counter +
    1
}

fn SsaBuilder::add_free_vars(
  self : SsaBuilder,
  free_vars : Array[(Name, @closure.LowType)]
) -> Unit {
  let this = self.this.or_else(fn() { @util.die("should have this var") })
  let free_local_vars = free_vars.map(
    fn {
      fv => {
        let free_var = {
          id: self.free_vars_counter,
          name: fv.0.name,
          slot: self.free_vars_counter,
          ty: fv.1,
        }
        let local_var = self.add_local_var(fv.0, fv.1)
        self.free_vars_counter = self.free_vars_counter + 1
        self.formal_free_vars.set(fv.0, free_var)
        self.free_vars.set(fv.0, local_var)
        (local_var, free_var)
      }
    },
  )
  let free_vars = free_local_vars.map(fn { (_, fv) => fv })
  free_local_vars.each(
    fn {
      (lv, fv) => {
        // let _i = this->_fv
        let _ = self.emit(Definition(Some(lv), GetClosure(this, fv, free_vars)))
        ()
      }
    },
  )
}

fn SsaBuilder::add_param_vars(
  self : SsaBuilder,
  params : Array[(Name, @closure.LowType)]
) -> Unit {
  self.params.push_iter(
    params.map(fn { p => self.add_local_var(p.0, p.1, is_param=true) }).iter(),
  )
}

fn SsaBuilder::add_local_var(
  self : SsaBuilder,
  name : Name,
  typ : Type,
  ~is_param : Bool = false
) -> Var {
  match self.free_vars.get(name) {
    Some(var) => var
    None =>
      match self.world_builder.global_vars.get(name) {
        Some(var) => var
        None => {
          let var = {
            id: self.world_builder.global_vars_counter,
            name: name.name,
            ty: typ,
            is_this: false,
            is_param,
            is_global: false,
            is_mut: false,
            const_value: get_const_value(name),
            is_phi: false,
            outcoming: None,
          }
          self.world_builder.global_vars_counter = self.world_builder.global_vars_counter +
            1
          self.local_vars.set(name, var)
          var
        }
      }
  }
}

fn SsaBuilder::add_local_temp_var(
  self : SsaBuilder,
  typ : Type,
  ~is_phi : Bool = false
) -> Var {
  let var = {
    id: self.world_builder.global_vars_counter,
    name: None,
    ty: typ,
    is_this: false,
    is_param: false,
    is_global: false,
    is_mut: false,
    const_value: None,
    is_phi,
    outcoming: None,
  }
  self.local_temp_vars.push(var)
  self.world_builder.global_vars_counter = self.world_builder.global_vars_counter +
    1
  var
}

fn SsaBuilder::get_var(self : SsaBuilder, name : Name) -> Var {
  // 1. Find in the local env
  match self.local_vars.get(name) {
    Some(var) => var
    None =>
      // 2. Recursion
      if name == self.old_name {
        self.this.or_else(
          fn() {
            // Build a closure for usage
            let this_closure = self.add_local_temp_var(self.ty)
            let _ = self.emit(
              Definition(Some(this_closure), Closure(self.name, [])),
            )
            this_closure
          },
        )
      } else {
        match self.free_vars.get(name) {
          // 3. Find in the closure env
          Some(var) => var
          None =>
            // 4. Find in the global env
            match self.world_builder.global_vars.get(name) {
              Some(var) => var
              None => @util.die("Unknown identifier \{name}")
            }
        }
      }
  }
}

fn SsaBuilder::emit(self : SsaBuilder, stmt : StmtKind) -> Stmt {
  let stmt = Stmt::new(self.stmts.length(), stmt)
  self.stmts.push(stmt)
  self.current_block.stmts.push(stmt)
  stmt
}

fn SsaBuilder::create_new_block(self : SsaBuilder) -> Block {
  let block = Block::new(self.blocks.length())
  self.blocks.push(block)
  block
}

// --- Build ---

fn MethodBuilder::build(self : MethodBuilder, expr : @closure.Expr) -> Method {
  let _ = self.visit_stmt(expr)
  let local_vars = []
  match self.ssa_builder.this {
    Some(this) => local_vars.push(this)
    None => ()
  }
  local_vars.push_iter(self.ssa_builder.local_vars.values())
  local_vars.push_iter(self.ssa_builder.local_temp_vars.iter())
  self.post_process()
  {
    name: self.name,
    slot: self.id,
    ty: self.ty,
    this: self.ssa_builder.this,
    params: self.ssa_builder.params,
    local_vars,
    body: { stmts: self.ssa_builder.stmts, blocks: self.ssa_builder.blocks },
    is_closure: self.is_closure,
    formal_free_vars: self.ssa_builder.formal_free_vars.values().collect(),
    local_free_vars: self.ssa_builder.free_vars.values().collect(),
  }
}

/// Build the stmt
/// Return the final stmt
fn MethodBuilder::visit_stmt(
  self : MethodBuilder,
  expr : @closure.Expr,
  ~cont : ((RValue) -> Unit)? = None,
  ~visiting_loop : Bool = false
) -> Unit {
  match expr {
    Let((name, typ), expr, rest) => {
      let _ = self.visit_expr(
        expr,
        fn {
          rvalue =>
            if typ != Unit {
              let _ = self.ssa_builder.emit(
                Definition(
                  Some(self.ssa_builder.add_local_var(name, typ)),
                  rvalue,
                ),
              )
              ()
            } else {
              // Should not define Unit
              let _ = self.ssa_builder.emit(Definition(None, rvalue))
              // Leave this for its usages
              let _ = self.ssa_builder.emit(
                Definition(
                  Some(self.ssa_builder.add_local_var(name, typ)),
                  Unit,
                ),
              )
              ()
            }
        },
        visiting_loop=false,
      )
      self.visit_stmt(rest, ~cont, ~visiting_loop)
    }
    LetTuple(els, expr, rest) => {
      let rvalue = self.ssa_builder.get_var(expr)
      els.eachi(
        fn {
          i, el => {
            let local_var = self.ssa_builder.add_local_var(el.0, el.1)
            let _ = self.ssa_builder.emit(
              Definition(Some(local_var), GetTuple(rvalue, i)),
            )
            ()
          }
        },
      )
      self.visit_stmt(rest, ~cont, ~visiting_loop)
    }
    MakeClosure((name, typ), closure, rest) => {
      // Connect actual free vars and formal free vars
      let actual_free_vars = closure.actual_free_vars.filter(
        fn {
          name =>
            not(self.ssa_builder.world_builder.global_vars.contains(name)) &&
            not(self.ssa_builder.world_builder.direct_closure.contains(name))
        },
      )
      let closure_builder = self.ssa_builder.world_builder.get_method_builder(
        closure.name._,
      )
      let formal_free_vars = closure_builder.ssa_builder.formal_free_vars
      assert_eq?(actual_free_vars.length(), formal_free_vars.size()).or_else(
        fn() { @util.die("unreachable") },
      )
      let free_vars = actual_free_vars.map(
        fn {
          fv =>
            (
              formal_free_vars
              .get(fv)
              .or_else(fn() { @util.die("should have free var \{fv}") }),
              self.ssa_builder.get_var(fv),
            )
        },
      )
      // Make a new closure
      let local_var = self.ssa_builder.add_local_var(name, typ)
      let _ = self.ssa_builder.emit(
        Definition(Some(local_var), Closure(closure.name._, free_vars)),
      )
      self.visit_stmt(rest, ~cont, ~visiting_loop)
    }
    _ =>
      match cont {
        Some(cont) => self.visit_expr(expr, cont, ~visiting_loop)
        _ =>
          self.visit_expr(
            expr,
            fn(rvalue) {
              let _ = match rvalue {
                Var(var) =>
                  if var.ty != Unit {
                    self.ssa_builder.emit(Return(Some(var)))
                  } else {
                    // Should not return Unit
                    self.ssa_builder.emit(Return(None))
                  }
                _ => {
                  let ret_type = @closure.extract_return_type(self.ty)
                  if ret_type != Unit {
                    let local_var = self.ssa_builder.add_local_temp_var(
                      ret_type,
                    )
                    let _ = self.ssa_builder.emit(
                      Definition(Some(local_var), rvalue),
                    )
                    self.ssa_builder.emit(Return(Some(local_var)))
                  } else {
                    // Should not return Unit
                    let _ = self.ssa_builder.emit(Definition(None, rvalue))
                    self.ssa_builder.emit(Return(None))
                  }
                }
              }
              ()
            },
            ~visiting_loop,
          )
      }
  }
}

/// Build the expr
/// Return the final stmt
fn MethodBuilder::visit_expr(
  self : MethodBuilder,
  expr : @closure.Expr,
  cont : (RValue) -> Unit,
  ~visiting_loop : Bool = false
) -> Unit {
  match expr {
    Unit => cont(Unit)
    Int(v) => cont(Int(v))
    Double(v) => cont(Double(v))
    Neg(v) => cont(Neg(self.ssa_builder.get_var(v), Int))
    FNeg(v) => cont(Neg(self.ssa_builder.get_var(v), Double))
    Add(lhs, rhs) =>
      cont(
        Prim(
          self.ssa_builder.get_var(lhs),
          self.ssa_builder.get_var(rhs),
          Add,
          Int,
        ),
      )
    Sub(lhs, rhs) =>
      cont(
        Prim(
          self.ssa_builder.get_var(lhs),
          self.ssa_builder.get_var(rhs),
          Sub,
          Int,
        ),
      )
    Mul(lhs, rhs) =>
      cont(
        Prim(
          self.ssa_builder.get_var(lhs),
          self.ssa_builder.get_var(rhs),
          Mul,
          Int,
        ),
      )
    Div(lhs, rhs) =>
      cont(
        Prim(
          self.ssa_builder.get_var(lhs),
          self.ssa_builder.get_var(rhs),
          Div,
          Int,
        ),
      )
    FAdd(lhs, rhs) =>
      cont(
        Prim(
          self.ssa_builder.get_var(lhs),
          self.ssa_builder.get_var(rhs),
          Add,
          Double,
        ),
      )
    FSub(lhs, rhs) =>
      cont(
        Prim(
          self.ssa_builder.get_var(lhs),
          self.ssa_builder.get_var(rhs),
          Sub,
          Double,
        ),
      )
    FMul(lhs, rhs) =>
      cont(
        Prim(
          self.ssa_builder.get_var(lhs),
          self.ssa_builder.get_var(rhs),
          Mul,
          Double,
        ),
      )
    FDiv(lhs, rhs) =>
      cont(
        Prim(
          self.ssa_builder.get_var(lhs),
          self.ssa_builder.get_var(rhs),
          Div,
          Double,
        ),
      )

    // Array
    ArrayGet(recv, idx) =>
      cont(
        GetArray(self.ssa_builder.get_var(recv), self.ssa_builder.get_var(idx)),
      )
    ArrayPut(recv, idx, expr) => {
      let _ = self.ssa_builder.emit(
        PutArray(
          self.ssa_builder.get_var(recv),
          self.ssa_builder.get_var(idx),
          self.ssa_builder.get_var(expr),
        ),
      )
      cont(Unit)
    }

    // Var
    Var(name) => {
      let var = self.ssa_builder.get_var(name)
      match var.const_value {
        Some(Int(x)) => cont(Int(x))
        Some(Double(x)) => cont(Double(x))
        _ => cont(Var(var))
      }
    }
    MakeTuple(els) =>
      cont(Tuple(els.map(fn { el => self.ssa_builder.get_var(el) })))

    // If
    IfEq(lhs, rhs, true_branch, false_branch, if_type)
    | IfLe(lhs, rhs, true_branch, false_branch, if_type) => {
      let lhs = self.ssa_builder.get_var(lhs)
      let rhs = self.ssa_builder.get_var(rhs)
      let condition = match expr {
        IfEq(_) => Condition::Eq(lhs, rhs)
        IfLe(_) => Condition::Le(lhs, rhs)
        _ => @util.die("unreachable")
      }

      // 0. Store current block
      let if_block = self.ssa_builder.current_block
      let _ = self.ssa_builder.emit(Nop)
      let if_stmt = self.ssa_builder.emit(IfGoto(condition, None, None, None))

      // 1.1. Create true branch block
      let true_block = self.ssa_builder.create_new_block()
      self.ssa_builder.current_block = true_block

      // 1.2. Visit true branch
      let mut true_var : Var? = None
      let mut true_stmt : Stmt? = None
      let mut true_end_block : Block? = None
      self.visit_expr(
        true_branch,
        fn {
          rvalue =>
            if visiting_loop {
              cont(rvalue)
            } else {
              if if_type != Unit {
                let local_var = self.ssa_builder.add_local_temp_var(if_type)
                true_var = Some(local_var)
                let _ = self.ssa_builder.emit(
                  Definition(Some(local_var), rvalue),
                )
                ()
              } else {
                let _ = self.ssa_builder.emit(Definition(None, rvalue))
                ()
              }
              true_stmt = Some(self.ssa_builder.emit(Goto(-1)))
              true_end_block = Some(self.ssa_builder.current_block)
            }
        },
        ~visiting_loop,
      )

      // 2.1. Create true branch block
      let _ = self.ssa_builder.emit(Nop)
      let false_block = self.ssa_builder.create_new_block()
      self.ssa_builder.current_block = false_block

      // 2.2. Visit false branch
      let mut false_var : Var? = None
      let mut false_stmt : Stmt? = None
      let mut false_end_block : Block? = None
      self.visit_expr(
        false_branch,
        fn {
          rvalue =>
            if visiting_loop {
              cont(rvalue)
            } else {
              if if_type != Unit {
                let local_var = self.ssa_builder.add_local_temp_var(if_type)
                false_var = Some(local_var)
                let _ = self.ssa_builder.emit(
                  Definition(Some(local_var), rvalue),
                )
                ()
              } else {
                let _ = self.ssa_builder.emit(Definition(None, rvalue))
                ()
              }
              false_stmt = Some(self.ssa_builder.emit(Goto(-1)))
              false_end_block = Some(self.ssa_builder.current_block)
            }
        },
        ~visiting_loop,
      )
      if visiting_loop {
        // 3. Back write if goto true and false label
        if_block.succ = Some(IfStart(true_block, false_block, None))
        match if_stmt.stmt {
          IfGoto(_) =>
            if_stmt.update(
              IfGoto(
                condition,
                Some(true_block.label),
                Some(false_block.label),
                None,
              ),
            )
          _ => @util.die("should be if goto stmt")
        }
      } else {
        // 4. Merge block and add phi var
        let _ = self.ssa_builder.emit(Nop)
        let merge_block = self.ssa_builder.create_new_block()
        if_block.succ = Some(
          IfStart(true_block, false_block, Some(merge_block)),
        )
        true_end_block.unwrap().succ = Some(IfEnd(merge_block))
        false_end_block.unwrap().succ = Some(IfEnd(merge_block))
        self.ssa_builder.current_block = merge_block
        let final_value = match (true_var, false_var) {
          (Some(true_var), Some(false_var)) => {
            let phi_var = self.ssa_builder.add_local_temp_var(
              if_type,
              is_phi=true,
            )
            let _phi_stmt = self.ssa_builder.emit(
              Definition(Some(phi_var), Phi([true_var, false_var])),
            )
            Var(phi_var)
          }
          _ => {
            let _ = self.ssa_builder.emit(Nop)
            Unit
          }
        }

        // 3. Back write if goto true and false label
        match if_stmt.stmt {
          IfGoto(_) =>
            if_stmt.update(
              IfGoto(
                condition,
                Some(true_block.label),
                Some(false_block.label),
                Some(merge_block.label),
              ),
            )
          _ => @util.die("should be if goto stmt")
        }

        // 5. Back write jump out labal
        match true_stmt {
          Some({ stmt: Goto(_), .. } as true_stmt) =>
            true_stmt.update(Goto(merge_block.label))
          _ => @util.die("should be goto stmt")
        }
        match false_stmt {
          Some({ stmt: Goto(_), .. } as false_stmt) =>
            false_stmt.update(Goto(merge_block.label))
          _ => @util.die("should be goto stmt")
        }
        cont(final_value)
      }
    }

    // Loop
    Loop((label, loop_type), raw_args, body) => {
      // 1. Create a loop block
      if self.ssa_builder.current_block.stmts.length() == 0 {
        let _ = self.ssa_builder.emit(Nop)
        ()
      }
      let prev_block = self.ssa_builder.current_block
      let loop_block = {
        let _ = self.ssa_builder.emit(Nop)
        let block = self.ssa_builder.create_new_block()
        self.ssa_builder.current_block = block
        block
      }

      // 2. Append placeholder stmts for args phi stmt
      let args = raw_args.map(
        fn {
          (a, _) => (self.ssa_builder.get_var(a), self.ssa_builder.emit(Nop))
        },
      )

      // 3. Build loop body
      let builder = LoopBuilder::{
        label: loop_block.label,
        args: args.map(fn { a => (a.0, []) }),
      }
      match self.ssa_builder.loops.get(label) {
        Some(_) => @util.die("duplicated loop")
        None => self.ssa_builder.loops.set(label, builder)
      }
      let break_names = [] // Break return variables
      let break_goto = [] // Goto out of loop
      let break_blocks = [] // Expr block at the end of the loop
      let _loop_body = self.visit_expr(
        body,
        fn {
          rvalue => {
            if loop_type != Unit {
              let local_var = self.ssa_builder.add_local_temp_var(loop_type)
              break_names.push(local_var)
              let _ = self.ssa_builder.emit(Definition(Some(local_var), rvalue))
              ()
            } else {
              let _ = self.ssa_builder.emit(Definition(None, rvalue))
              ()
            }
            break_goto.push(self.ssa_builder.emit(Break(-1, -1)))
            break_blocks.push(self.ssa_builder.current_block)
          }
        },
        visiting_loop=true,
      )

      // 4. Back write the phi var
      args.eachi(
        fn {
          i, (arg, stmt) => {
            let next_args = builder.args[i].1
            match next_args {
              [] => ()
              _ => {
                arg.is_mut = true
                let next_vars = [arg]
                next_vars.push_iter(next_args.iter())
                stmt.update(Definition(Some(arg), Phi(next_vars)))
              }
            }
          }
        },
      )

      // 5. Build the final result
      let _ = self.ssa_builder.emit(Nop)
      let return_block = self.ssa_builder.create_new_block()
      prev_block.succ = Some(While(loop_block, return_block))
      break_goto.each(
        fn { stmt => stmt.update(Break(loop_block.label, return_block.label)) },
      )
      break_blocks.each(fn { blk => blk.succ = Some(Break(return_block)) })
      self.ssa_builder.current_block = return_block
      match break_names {
        [] => {
          let _ = self.ssa_builder.emit(Nop)
          cont(Unit)
        }
        [return_name] => cont(Var(return_name))
        _ => {
          let phi_var = self.ssa_builder.add_local_temp_var(
            loop_type,
            is_phi=true,
          )
          let _phi_stmt = self.ssa_builder.emit(
            Definition(Some(phi_var), Phi(break_names)),
          )
          cont(Var(phi_var))
        }
      }
    }
    Continue(label, args) =>
      match self.ssa_builder.loops.get(label) {
        Some(builder) => {
          args.eachi(
            fn {
              i, arg => {
                let arg_builder = builder.args[i]
                let src_arg = arg_builder.0
                let cur_arg = self.ssa_builder.get_var(arg)
                if src_arg != cur_arg {
                  let new_temp = self.ssa_builder.add_local_temp_var(src_arg.ty)
                  let _ = self.ssa_builder.emit(
                    Definition(Some(new_temp), Var(cur_arg)),
                  )
                  arg_builder.1.push(new_temp)
                }
              }
            },
          )
          let _ = self.ssa_builder.emit(Continue(builder.label))
          ()
        }
        None => @util.die("should have loop \{label}")
      }

    // Call
    CallDirect(label, args) =>
      cont(
        InvokeDirect(
          label._,
          args.map(fn { el => self.ssa_builder.get_var(el) }),
        ),
      )
    CallClosure(callee, args) =>
      cont(
        InvokeClosure(
          self.ssa_builder.get_var(callee),
          args.map(fn { el => self.ssa_builder.get_var(el) }),
        ),
      )

    // Stmt
    Let(_) => self.visit_stmt(expr, cont=Some(cont), ~visiting_loop)
    LetTuple(_) => self.visit_stmt(expr, cont=Some(cont), ~visiting_loop)
    MakeClosure(_) => self.visit_stmt(expr, cont=Some(cont), ~visiting_loop)

    // Unused
    ExternalArray(_) => @util.die("unreachable")
  }
}
