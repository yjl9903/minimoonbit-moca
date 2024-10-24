pub fn emit_wasm(world : @ssa.World) -> WasmResult {
  let result = WasmResult::new()
  add_imports(world, result)
  add_globals(world, result)
  // Add method placeholder
  world.methods.values().each(fn { m => add_func(m, result) })
  add_func(world.main_method, result, is_main=true)
  // Build all the methods
  world.methods.values().each(fn { m => build_func(m, result) })
  build_func(world.main_method, result)
  result
}

fn add_imports(world : @ssa.World, result : WasmResult) -> Unit {
  world.externals
  .iter()
  .each(
    fn {
      (name, ty) =>
        result.imports.set(
          name,
          (
            {
              identifier: "$__" + name + "_d_",
              import_module: minimoonbit_import_module,
              import_name: name,
              ty,
            },
            None,
          ),
        )
    },
  )
}

fn add_globals(world : @ssa.World, result : WasmResult) -> Unit {
  world.global
  .filter(fn { g => g.const_value.is_empty() })
  .each(
    fn {
      g =>
        result.globals.set(
          g.id,
          { identifier: "$__global_\{g.id}", ty: g.ty, value: None },
        )
    },
  )
}

fn add_func(
  method : @ssa.Method,
  result : WasmResult,
  ~to_closure : Bool = false,
  ~is_main : Bool = false
) -> Unit {
  if not(to_closure) {
    // Identifier
    let identifier = if is_main {
      minimoonbit_start_identifier
    } else {
      "$\{get_method_name(method.name)}_"
    }
    // Index
    let table_index = if method.is_closure {
      let sz = result.table.size
      result.table.size = result.table.size + 1
      Some(sz)
    } else {
      None
    }
    // Args
    let args = []
    if method.is_closure {
      args.push((Var::from_ssa(method.this.unwrap()), Type::Ptr))
    }
    args.push_iter(
      method.params.iter().map(fn { p => (Var::from_ssa(p), p.ty) }),
    )
    // Func
    let func = {
      identifier,
      params: args,
      ty: if method.is_closure {
        add_method_this_type(method)
      } else {
        method.ty
      },
      is_closure: method.is_closure,
      table_index,
      locals: Map::new(),
      stmts: [],
      merged: Map::new(),
    }
    result.funcs.set(
      method.name,
      (func, if method.is_closure { Some(func) } else { None }),
    )
  } else {
    match result.funcs.get(method.name) {
      Some((func, None)) => {
        let identifier = "$\{get_method_name(method.name)}_c_"
        let table_index = Some(result.table.size)
        result.table.size = result.table.size + 1
        let args = []
        args.push((Var::temp_this(), Type::Ptr))
        args.push_iter(
          method.params.iter().map(fn { p => (Var::from_ssa(p), p.ty) }),
        )
        // Push all the args
        let stmts = method.params.map(
          fn { p => Instruction::LocalGet(Var::from_ssa(p)) },
        )
        // Call wrapped function
        stmts.push(Call(func))
        // Func
        let c_func = {
          identifier,
          params: args,
          ty: add_method_this_type(method),
          is_closure: true,
          table_index,
          locals: Map::new(),
          stmts,
          merged: Map::new(),
        }
        result.funcs.set(method.name, (func, Some(c_func)))
      }
      _ => ()
    }
  }
}

fn build_func(method : @ssa.Method, result : WasmResult) -> Unit {
  let emitter = match result.funcs.get(method.name) {
    Some(m) => m.0
    None => @util.die("unreachable")
  }
  // 1. Build merged vars
  for i = 0; i < method.body.stmts.length(); i = i + 1 {
    let stmt = method.body.stmts[i]
    match stmt.stmt {
      Definition(Some(var), Phi(merged)) => {
        let var = match emitter.merged.get(var.id) {
          Some(v) => v
          _ => var
        }
        merged.each(fn { m => emitter.merged.set(m.id, var) })
      }
      _ => ()
    }
  }
  // 2. Build local vars
  let local_vars = method.local_vars
    .filter(
      fn {
        v =>
          if not(v.is_param) && v.const_value.is_empty() {
            match emitter.merged.get(v.id) {
              Some(m) => m.id == v.id
              None => true
            }
          } else {
            false
          }
      },
    )
    .iter()
  local_vars.each(fn { lv => emitter.locals.set(lv.id, Var::from_ssa(lv)) })
  // 3. Build stmts
  emit_func_block(method, emitter, method.body.blocks[0])
}

fn emit_func_block(
  method : @ssa.Method,
  func : WasmFunc,
  block : @ssa.Block
) -> Unit {
  for i = 0; i < block.stmts.length(); i = i + 1 {
    let stmt = block.stmts[i]
    match stmt.stmt {
      IfGoto(cond, true_target, false_target, merge_target) => {
        let ty = match cond {
          Eq(lhs, rhs) | Le(lhs, rhs) => {
            func.emit_var(lhs)
            func.emit_var(rhs)
            lhs.ty
          }
        }
        func.stmts.push(
          match (ty, cond) {
            (Int, Eq(_)) => ICmp(I32, Eq)
            (Int, Le(_)) => ICmp(I32, Le_s)
            (Double, Eq(_)) => FCmp(F64, Eq)
            (Double, Le(_)) => FCmp(F64, Le)
            _ => @util.die("unreachable")
          },
        )
        func.stmts.push(If)
        func.stmts.push(IfThen)
        match true_target {
          Some(t) => emit_func_block(method, func, method.body.blocks[t])
          _ => ()
        }
        func.stmts.push(IfEnd)
        match false_target {
          Some(t) => {
            func.stmts.push(IfElse)
            emit_func_block(method, func, method.body.blocks[t])
            func.stmts.push(IfEnd)
          }
          _ => ()
        }
        func.stmts.push(IfEnd)
        match merge_target {
          Some(t) => emit_func_block(method, func, method.body.blocks[t])
          _ => ()
        }
        break
      }
      Goto(_) => break // if () { ... } else { ... }
      Break(loop_label, _) => {
        // break B_;
        func.stmts.push(Break(loop_label))
        break
      }
      Continue(loop_label) => {
        // continue B_;
        func.stmts.push(Continue(loop_label))
        break
      }
      Return(var) => {
        // return _;
        func.emit_var(var)
        func.stmts.push(Return)
        break
      }
      _ => {
        // Not a control flow ir
        func.emit_stmt(stmt)
        if i + 1 == block.stmts.length() {
          match block.succ {
            Some(edge) =>
              match edge {
                Next(block) => emit_func_block(method, func, block)
                While(loop_block, return_block) => {
                  // Start a while loop
                  let label = loop_block.label
                  func.stmts.push(Loop(label))
                  emit_func_block(method, func, loop_block)
                  func.stmts.push(LoopEnd)
                  emit_func_block(method, func, return_block)
                }
                // The end of a if branch, stop building following
                IfEnd(_) => ()
                Break(_) => @util.die("unexpected break")
                Continue(_) => @util.die("unexpected continue")
                IfStart(_) => @util.die("unexpected if branch")
              }
            None => ()
          }
        }
      }
    }
  }
}

fn WasmFunc::emit_stmt(self : WasmFunc, stmt : @ssa.Stmt) -> Unit {
  match stmt.stmt {
    Definition(_, Phi(_)) => ()
    Definition(Some(var), rvalue) =>
      if var.const_value.is_empty() {
        self.emit_rvalue(rvalue)
        if var.is_global {
          self.stmts.push(GlobalSet(Var::from_ssa(var)))
        } else {
          self.stmts.push(LocalSet(Var::from_ssa(var)))
        }
      } else {
        ()
      }
    Definition(None, rvalue) => self.emit_rvalue(rvalue)
    PutArray(recv, idx, expr) =>
      // "\{self.emit_var(recv)}[\{self.emit_var(idx)}] = \{self.emit_var(expr)};"
      @util.die("todo")
    Nop => ()
    Goto(_) => @util.die("unexpected")
    Break(_) => @util.die("unexpected")
    Continue(_) => @util.die("unexpected")
    IfGoto(_) => @util.die("unexpected")
    Return(_) => @util.die("unexpected")
  }
}

fn WasmFunc::emit_rvalue(self : WasmFunc, rvalue : @ssa.RValue) -> Unit {
  match rvalue {
    Unit => self.stmts.push(IConst(I32, 0))
    Int(x) => self.stmts.push(IConst(I32, x))
    Double(x) => self.stmts.push(FConst(F64, x))
    Prim(lhs, rhs, op, kind) => {
      self.emit_var(lhs)
      self.emit_var(rhs)
      match (op, kind) {
        (_, Int) => self.stmts.push(IPrim(I32, op))
        (_, Double) => self.stmts.push(FPrim(F64, op))
      }
    }
    Neg(expr, kind) =>
      match kind {
        Int => {
          self.stmts.push(IConst(I32, 0))
          self.emit_var(expr)
          self.stmts.push(IPrim(I32, Sub))
        }
        Double => {
          self.emit_var(expr)
          self.stmts.push(FNeg(F64))
        }
      }
    Var(var) => self.emit_var(var)
    Tuple(els) =>
      // let els = els.map(fn { e => self.emit_var(e) }).join(", ")
      // "[\{els}]"
      @util.die("todo")
    Closure(label, bindings) =>
      // let name = get_method_name(label)
      // let bindings = bindings
      //   .map(fn { (fv, var) => "\"\{fv.to_string()}\": \{self.emit_var(var)}" })
      //   .join(", ")
      @util.die("todo")

    // Get from structure
    GetTuple(var, idx) => @util.die("todo")
    GetArray(recv, idx) => @util.die("todo")
    GetClosure(closure, fv) =>
      if closure.is_this {
        // "this[\"\{fv.to_string()}\"]"
        @util.die("todo")
      } else {
        @util.die("")
      }

    // Invoke
    InvokeClosure(callee, args) =>
      // let args = args.map(fn { a => self.emit_var(a) }).join(", ")
      // "\{self.emit_var(callee)}(\{args})"
      @util.die("todo")
    InvokeDirect(label, args) =>
      // let args = args.map(fn { a => self.emit_var(a) }).join(", ")
      // "\{get_method_name(label)}(\{args})"
      @util.die("todo")

    // Phi
    Phi(_) => ()
  }
}

fn WasmFunc::emit_var(self : WasmFunc, var : @ssa.Var) -> Unit {
  match var.const_value {
    Some(Int(x)) => self.stmts.push(IConst(I32, x))
    Some(Double(x)) => self.stmts.push(FConst(F64, x))
    _ => {
      let merged = self.merged.get(var.id)
      let var = merged.or(var)
      if var.is_this {
        @util.die("TODO")
      } else if var.is_global {
        self.stmts.push(GlobalGet(Var::from_ssa(var)))
      } else {
        self.stmts.push(LocalGet(Var::from_ssa(var)))
      }
    }
  }
}
