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
    ssa_builder: SsaBuilder::new(world_builder, old_name, ty),
  }
}

fn MethodBuilder::new(
  world_builder : WorldBuilder,
  def : @closure.FuncDef
) -> MethodBuilder {
  let free_vars = def.formal_free_vars
  // Filter global var
  let free_vars = free_vars.filter(
    fn { (name, _) => not(world_builder.global_vars.contains(name)) },
  )
  let builder = {
    id: def.id,
    name: def.name._,
    old_name: def.old_name,
    ty: def.ty,
    args: def.args,
    is_closure: def.is_closure,
    formal_free_vars: free_vars,
    ssa_builder: SsaBuilder::new(world_builder, def.old_name, def.ty),
  }
  // Build this and free vars
  builder.ssa_builder.add_this()
  if builder.is_closure {
    builder.ssa_builder.add_free_vars(builder.formal_free_vars)
  }
  // Build parms
  builder.ssa_builder.add_param_vars(builder.args)
  builder
}

struct SsaBuilder {
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
  mut local_vars_counter : Int

  // Builder
  world_builder : WorldBuilder
}

fn SsaBuilder::new(
  world_builder : WorldBuilder,
  old_name : Name,
  ty : Type
) -> SsaBuilder {
  let current_block = Block::new(0)
  {
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
    local_vars_counter: 0,
    world_builder,
  }
}

fn SsaBuilder::add_this(self : SsaBuilder) -> Unit {
  self.this = Some(
    {
      id: self.local_vars_counter,
      name: Some("%this"),
      slot: self.local_vars_counter,
      ty: self.ty,
      is_this: true,
      is_param: true,
      is_global: false,
      const_value: None,
    },
  )
  self.local_vars_counter = self.local_vars_counter + 1
}

fn SsaBuilder::add_free_vars(
  self : SsaBuilder,
  free_vars : Array[(Name, @closure.LowType)]
) -> Unit {
  let this = self.this.unwrap()
  free_vars.each(
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
        // let _i = this->_fv
        let _ = self.emit(
          Definition(Some(local_var), GetClosure(this, free_var)),
        )
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
            id: self.local_vars_counter,
            name: name.name,
            slot: self.local_vars_counter,
            ty: typ,
            is_this: false,
            is_param,
            is_global: false,
            const_value: get_const_value(name),
          }
          self.local_vars_counter = self.local_vars_counter + 1
          self.local_vars.set(name, var)
          var
        }
      }
  }
}

fn SsaBuilder::add_local_temp_var(self : SsaBuilder, typ : Type) -> Var {
  let var = {
    id: self.local_vars_counter,
    name: None,
    slot: self.local_vars_counter,
    ty: typ,
    is_this: false,
    is_param: false,
    is_global: false,
    const_value: None,
  }
  self.local_temp_vars.push(var)
  self.local_vars_counter = self.local_vars_counter + 1
  var
}

fn SsaBuilder::get_var(self : SsaBuilder, name : Name) -> Var {
  // 1. Find in the local env
  match self.local_vars.get(name) {
    Some(var) => var
    None =>
      // 2. Recursion
      if name == self.old_name {
        self.this.unwrap()
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

fn SsaBuilder::append_new_block(self : SsaBuilder) -> Block {
  let block = Block::new(self.blocks.length())
  self.blocks.push(block)
  self.current_block.succ.push(block)
  self.current_block = block
  block
}

fn SsaBuilder::create_new_block(self : SsaBuilder) -> Block {
  let block = Block::new(self.blocks.length())
  self.blocks.push(block)
  block
}

// --- Build ---

fn MethodBuilder::build(self : MethodBuilder, expr : @closure.Expr) -> Method {
  let _ = self.visit_stmt(expr)
  let local_vars = self.ssa_builder.local_vars.values().collect()
  local_vars.push_iter(self.ssa_builder.local_temp_vars.iter())
  {
    name: self.name,
    slot: self.id,
    ty: self.ty,
    this: self.ssa_builder.this,
    params: self.ssa_builder.params,
    local_vars,
    body: { stmts: self.ssa_builder.stmts, blocks: [] },
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
  ~cont : ((RValue) -> Stmt)? = None
) -> Stmt {
  match expr {
    Let((name, typ), expr, rest) => {
      let _ = self.visit_expr(
        expr,
        fn {
          rvalue =>
            self.ssa_builder.emit(
              Definition(
                Some(self.ssa_builder.add_local_var(name, typ)),
                rvalue,
              ),
            )
        },
      )
      self.visit_stmt(rest, ~cont)
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
      self.visit_stmt(rest, ~cont)
    }
    MakeClosure((name, typ), closure, rest) => {
      // Connect actual free vars and formal free vars
      let actual_free_vars = closure.actual_free_vars.filter(
        fn {
          name => not(self.ssa_builder.world_builder.global_vars.contains(name))
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
            (formal_free_vars.get(fv).unwrap(), self.ssa_builder.get_var(fv))
        },
      )
      // Make a new closure
      let local_var = self.ssa_builder.add_local_var(name, typ)
      let _ = self.ssa_builder.emit(
        Definition(Some(local_var), Closure(closure.name._, free_vars)),
      )
      self.visit_stmt(rest, ~cont)
    }
    _ =>
      match cont {
        Some(cont) => self.visit_expr(expr, cont)
        _ =>
          self.visit_expr(
            expr,
            fn(rvalue) {
              match rvalue {
                Var(var) => self.ssa_builder.emit(Return(var))
                _ => {
                  let ret_type = @closure.extract_return_type(self.ty)
                  let local_var = self.ssa_builder.add_local_temp_var(ret_type)
                  let _ = self.ssa_builder.emit(
                    Definition(Some(local_var), rvalue),
                  )
                  self.ssa_builder.emit(Return(local_var))
                }
              }
            },
          )
      }
  }
}

/// Build the expr
/// Return the final stmt
fn MethodBuilder::visit_expr(
  self : MethodBuilder,
  expr : @closure.Expr,
  cont : (RValue) -> Stmt
) -> Stmt {
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
    Var(name) => cont(Var(self.ssa_builder.get_var(name)))
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
      let if_stmt = self.ssa_builder.emit(IfGoto(condition, None, None))

      // 1.1. Create true branch block
      let true_block = self.ssa_builder.create_new_block()
      if_block.succ.push(true_block)
      self.ssa_builder.current_block = true_block

      // 1.2. Visit true branch
      let mut true_var : Var? = None
      let true_stmt = self.visit_expr(
        true_branch,
        fn {
          rvalue => {
            let local_var = self.ssa_builder.add_local_temp_var(if_type)
            true_var = Some(local_var)
            let _ = self.ssa_builder.emit(Definition(Some(local_var), rvalue))
            self.ssa_builder.emit(Goto(-1))
          }
        },
      )
      if true_block.stmts.length() == 0 {
        return @util.die("if true block should not be empty")
      }

      // 2.1. Create true branch block
      let false_block = self.ssa_builder.create_new_block()
      if_block.succ.push(false_block)
      self.ssa_builder.current_block = false_block

      // 2.2. Visit false branch
      let mut false_var : Var? = None
      let false_stmt = self.visit_expr(
        false_branch,
        fn {
          rvalue => {
            let local_var = self.ssa_builder.add_local_temp_var(if_type)
            false_var = Some(local_var)
            let _ = self.ssa_builder.emit(Definition(Some(local_var), rvalue))
            self.ssa_builder.emit(Goto(-1))
          }
        },
      )
      if false_block.stmts.length() == 0 {
        return @util.die("if false block should not be empty")
      }

      // 3. Merge block and add phi var
      let merge_block = self.ssa_builder.create_new_block()
      true_block.succ.push(merge_block)
      false_block.succ.push(merge_block)
      self.ssa_builder.current_block = merge_block
      let phi_var = self.ssa_builder.add_local_temp_var(if_type)
      let _phi_stmt = self.ssa_builder.emit(
        Definition(Some(phi_var), Phi([true_var.unwrap(), false_var.unwrap()])),
      )

      // 4. Back write label
      match if_stmt.stmt {
        IfGoto(_) =>
          if_stmt.update(
            IfGoto(condition, Some(true_block.label), Some(false_block.label)),
          )
        _ => @util.die("should be if goto stmt")
      }
      match true_stmt.stmt {
        Goto(_) => true_stmt.update(Goto(merge_block.label))
        _ => @util.die("should be goto stmt")
      }
      match false_stmt.stmt {
        Goto(_) => false_stmt.update(Goto(merge_block.label))
        _ => @util.die("should be goto stmt")
      }
      cont(Var(phi_var))
    }

    // Loop
    Loop(_) => @util.die("todo")
    Continue(_) => @util.die("todo")

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
    Let(_) => self.visit_stmt(expr, cont=Some(cont))
    LetTuple(_) => self.visit_stmt(expr, cont=Some(cont))
    MakeClosure(_) => self.visit_stmt(expr, cont=Some(cont))

    // Unused
    ExternalArray(_) => @util.die("unreachable")
  }
}
