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
          {
            identifier: "$__global_\{g.id}",
            mutable: true,
            ty: g.ty,
            value: None,
          },
        )
    },
  )
}

fn add_func(
  method : @ssa.Method,
  result : WasmResult,
  ~is_main : Bool = false
) -> Unit {
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
  args.push_iter(method.params.iter().map(fn { p => (Var::from_ssa(p), p.ty) }))
  // type
  let ty = if method.is_closure {
    add_method_this_type(method)
  } else {
    method.ty
  }
  let wasm_type = add_table_func_type(result, ty)
  // Func
  let func = {
    ssa_name: method.name,
    identifier,
    params: args,
    ty,
    wasm_type: Some(wasm_type),
    is_closure: method.is_closure,
    table_index,
    locals: Map::new(),
    free_vars: method.formal_free_vars,
    stmts: [],
    this_var: if method.is_closure {
      Some(args[0].0)
    } else {
      None
    },
    merged: Map::new(),
  }
  result.funcs.set(
    method.name,
    (func, if method.is_closure { Some(func) } else { None }),
  )
}

fn add_closure_func(result : WasmResult, label : String) -> WasmFunc {
  match result.funcs.get(label) {
    Some((_, Some(c_func))) => c_func
    Some((func, None)) => {
      let identifier = "$\{get_method_name(label)}_c_"
      let table_index = Some(result.table.size)
      result.table.size = result.table.size + 1
      let args = []
      args.push((Var::temp_this(), Type::Ptr))
      args.push_iter(func.params.iter().map(fn { (p, ty) => (p, ty) }))
      // Push all the args
      let stmts = func.params.map(fn { p => Instruction::LocalGet(p.0) })
      // Call wrapped function
      stmts.push(Call(func))
      // type
      let ty = add_func_type_this_type(func.ty)
      let wasm_type = add_table_func_type(result, ty)
      // Func
      let c_func = {
        ssa_name: label,
        identifier,
        params: args,
        ty,
        wasm_type: Some(wasm_type),
        is_closure: true,
        table_index,
        locals: Map::new(),
        free_vars: [],
        stmts,
        this_var: Some(args[0].0),
        merged: Map::new(),
      }
      result.funcs.set(label, (func, Some(c_func)))
      c_func
    }
    None =>
      // Create wrapper for import method
      match result.imports.get(label) {
        Some((func, None)) => {
          let identifier = "$__" + label + "_c_"
          let table_index = Some(result.table.size)
          result.table.size = result.table.size + 1
          // Args
          let args_type = match func.ty {
            ClosureFn(args, _) | DirectFn(args, _) => args
            _ => @util.die("unreachable")
          }
          let args = []
          args.push((Var::temp_this(), Type::Ptr))
          args.push_iter(
            args_type.mapi(fn { i, ty => (temp_with_type(i, ty), ty) }).iter(),
          )
          // Push all the args
          let stmts = args_type.mapi(
            fn { i, ty => Instruction::LocalGet(temp_with_type(i, ty)) },
          )
          // Call wrapped function
          stmts.push(CallImport(func))
          // type
          let ty = add_func_type_this_type(func.ty)
          let wasm_type = add_table_func_type(result, ty)
          // Func
          let c_func = {
            ssa_name: label,
            identifier,
            params: args,
            ty,
            wasm_type: Some(wasm_type),
            is_closure: true,
            table_index,
            locals: Map::new(),
            free_vars: [],
            stmts,
            this_var: Some(args[0].0),
            merged: Map::new(),
          }
          result.imports.set(label, (func, Some(c_func)))
          let _ = add_table_func_type(result, c_func.ty)
          c_func
        }
        Some((_, Some(c_func))) => c_func
        None => @util.die("unknown method \{label}")
      }
  }
}

fn add_local_var(func : WasmFunc) -> Var {
  let id = func.locals
    .keys()
    .fold(fn { acc, cur => @math.maximum(acc, cur) }, init=0)
  let id = id + 1
  let var = temp_with_type(id, Ptr)
  func.locals.set(id, var)
  var
}

fn add_table_func_type(result : WasmResult, ty : Type) -> WasmType {
  let text = print_function_type(ty)
  match result.types.get(text) {
    Some(t) => t
    None => {
      let sz = result.types.size()
      let wasm_type = { identifier: "$__minimbt_types_\{sz}__", ty }
      result.types.set(text, wasm_type)
      wasm_type
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
  emit_func_block(result, method, emitter, method.body.blocks[0])
  // // 4. for main should return 0
  // if emitter.identifier == minimoonbit_start_identifier {
  //   let _ = emitter.stmts.pop()
  //   emitter.stmts.push(IConst(I32, 0))
  //   emitter.stmts.push(Return)
  // }
}

fn emit_func_block(
  result : WasmResult,
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
            func.emit_get_var(result, lhs)
            func.emit_get_var(result, rhs)
            lhs.ty
          }
        }
        func.stmts.push(
          match (ty, cond) {
            (Bool, Eq(_)) => ICmp(I32, Eq)
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
          Some(t) =>
            emit_func_block(result, method, func, method.body.blocks[t])
          _ => ()
        }
        func.stmts.push(IfEnd)
        match false_target {
          Some(t) => {
            func.stmts.push(IfElse)
            emit_func_block(result, method, func, method.body.blocks[t])
            func.stmts.push(IfEnd)
          }
          _ => ()
        }
        func.stmts.push(IfEnd)
        match merge_target {
          Some(t) =>
            emit_func_block(result, method, func, method.body.blocks[t])
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
      Return(None) => {
        // return;
        func.stmts.push(Return)
        break
      }
      Return(Some(var)) => {
        // return _;
        func.emit_get_var(result, var)
        func.stmts.push(Return)
        break
      }
      _ => {
        // Not a control flow ir
        func.emit_stmt(result, stmt)
        if i + 1 == block.stmts.length() {
          match block.succ {
            Some(edge) =>
              match edge {
                Next(block) => emit_func_block(result, method, func, block)
                While(loop_block, return_block) => {
                  // Start a while loop
                  let label = loop_block.label
                  func.stmts.push(Loop(label))
                  emit_func_block(result, method, func, loop_block)
                  func.stmts.push(LoopEnd)
                  emit_func_block(result, method, func, return_block)
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

fn WasmFunc::emit_stmt(
  self : WasmFunc,
  result : WasmResult,
  stmt : @ssa.Stmt
) -> Unit {
  match stmt.stmt {
    Definition(_, Phi(_)) => ()
    Definition(Some(var), rvalue) =>
      if var.const_value.is_empty() {
        self.emit_rvalue(result, rvalue)
        self.emit_set_var(var)
      } else {
        ()
      }
    Definition(None, rvalue) => self.emit_rvalue(result, rvalue)
    PutArray(recv, idx, expr) => {
      self.emit_get_var(result, recv)
      self.emit_get_var(result, idx)
      match extract_array_type(recv.ty) {
        Double(_) => {
          self.stmts.push(IConst(I32, f64_size))
          self.stmts.push(IPrim(I32, Mul))
          self.stmts.push(IPrim(I32, Add))
          self.emit_get_var(result, expr)
          self.stmts.push(FStore(F64, None))
        }
        _ => {
          self.stmts.push(IConst(I32, i32_size))
          self.stmts.push(IPrim(I32, Mul))
          self.stmts.push(IPrim(I32, Add))
          self.emit_get_var(result, expr)
          self.stmts.push(IStore(I32, None))
        }
      }
    }
    Nop => ()
    Goto(_) => @util.die("unexpected")
    Break(_) => @util.die("unexpected")
    Continue(_) => @util.die("unexpected")
    IfGoto(_) => @util.die("unexpected")
    Return(_) => @util.die("unexpected")
  }
}

fn WasmFunc::emit_rvalue(
  self : WasmFunc,
  result : WasmResult,
  rvalue : @ssa.RValue
) -> Unit {
  match rvalue {
    Unit => self.stmts.push(IConst(I32, 0))
    Int(x) => self.stmts.push(IConst(I32, x))
    Double(x) => self.stmts.push(FConst(F64, x))
    Prim(lhs, rhs, op, kind) => {
      self.emit_get_var(result, lhs)
      self.emit_get_var(result, rhs)
      match (op, kind) {
        (_, Int) => self.stmts.push(IPrim(I32, op))
        (_, Double) => self.stmts.push(FPrim(F64, op))
      }
    }
    Neg(expr, kind) =>
      match kind {
        Int => {
          self.stmts.push(IConst(I32, 0))
          self.emit_get_var(result, expr)
          self.stmts.push(IPrim(I32, Sub))
        }
        Double => {
          self.emit_get_var(result, expr)
          self.stmts.push(FNeg(F64))
        }
      }
    Var(var) => self.emit_get_var(result, var)
    Tuple(els) => {
      let local_var = add_local_var(self)
      self.stmts.push(IConst(I32, get_vars_type_size(els)))
      self.stmts.push(Malloc)
      self.stmts.push(LocalSet(local_var))
      let mut offset = 0
      for i = 0; i < els.length(); i = i + 1 {
        let el = els[i]
        self.stmts.push(LocalGet(local_var))
        self.emit_get_var(result, el)
        match el.ty {
          Double => {
            self.stmts.push(FStore(F64, Some(offset)))
            offset = offset + f64_size
          }
          _ => {
            self.stmts.push(IStore(I32, Some(offset)))
            offset = offset + i32_size
          }
        }
      }
      self.stmts.push(LocalGet(local_var))
    }
    Closure(label, bindings) => {
      let local_var = add_local_var(self)
      let closure_func = add_closure_func(result, label)
      let closure_size = get_closure_size(closure_func.free_vars)
      self.stmts.push(IConst(I32, closure_size))
      self.stmts.push(Malloc)
      self.stmts.push(LocalTee(local_var))
      self.stmts.push(IConst(I32, closure_func.table_index.unwrap()))
      // Store table index
      self.stmts.push(IStore(I32, None))
      // Store free vars
      bindings.sort_by_key(fn { b => b.0.slot })
      let mut offset = i32_size
      for i = 0; i < bindings.length(); i = i + 1 {
        let el = bindings[i]
        self.stmts.push(LocalGet(local_var))
        self.emit_get_var(result, el.1)
        match el.0.ty {
          Double => {
            self.stmts.push(FStore(F64, Some(offset)))
            offset = offset + f64_size
          }
          _ => {
            self.stmts.push(IStore(I32, Some(offset)))
            offset = offset + i32_size
          }
        }
      }
      self.stmts.push(LocalGet(local_var))
    }

    // Get from structure
    GetTuple(var, idx) => {
      self.emit_get_var(result, var)
      let types = extract_tuple_type(var.ty)
      let offset = get_types_type_size(types, slice=Some(idx))
      match types[idx] {
        Double => self.stmts.push(FLoad(F64, Some(offset)))
        _ => self.stmts.push(ILoad(I32, Some(offset)))
      }
    }
    GetArray(recv, idx) => {
      self.emit_get_var(result, recv)
      self.emit_get_var(result, idx)
      match extract_array_type(recv.ty) {
        Double => {
          self.stmts.push(IConst(I32, f64_size))
          self.stmts.push(IPrim(I32, Mul))
          self.stmts.push(IPrim(I32, Add))
          self.stmts.push(FLoad(F64, None))
        }
        _ => {
          self.stmts.push(IConst(I32, i32_size))
          self.stmts.push(IPrim(I32, Mul))
          self.stmts.push(IPrim(I32, Add))
          self.stmts.push(ILoad(I32, None))
        }
      }
    }
    GetClosure(closure, fv, all_fv) =>
      if closure.is_this {
        let this_var = self.this_var.unwrap()
        let offset = get_closure_size(all_fv, target=Some(fv))
        self.stmts.push(LocalGet(this_var))
        match fv.ty {
          Double => self.stmts.push(FLoad(F64, Some(offset)))
          _ => self.stmts.push(ILoad(I32, Some(offset)))
        }
      } else {
        @util.die("unreachable")
      }

    // Invoke
    InvokeClosure(callee, args) => {
      self.emit_get_var(result, callee) // this_var
      args.each(fn { arg => self.emit_get_var(result, arg) }) // args
      self.emit_get_var(result, callee)
      self.stmts.push(ILoad(I32, None)) // table index
      let wasm_type = add_table_func_type(
        result,
        add_func_type_this_type(callee.ty),
      )
      self.stmts.push(CallIndirect(wasm_type))
    }
    InvokeDirect(label, args) => {
      args.each(fn { a => self.emit_get_var(result, a) })
      match result.funcs.get(label) {
        Some((callee, _)) => self.stmts.push(Call(callee))
        None =>
          match result.imports.get(label) {
            Some((callee, _)) => self.stmts.push(CallImport(callee))
            None => @util.die("should have func \{label}")
          }
      }
    }

    // Phi
    Phi(_) => ()
  }
}

fn WasmFunc::emit_get_var(
  self : WasmFunc,
  result : WasmResult,
  var : @ssa.Var
) -> Unit {
  match var.const_value {
    Some(Int(x)) => self.stmts.push(IConst(I32, x))
    Some(Double(x)) => self.stmts.push(FConst(F64, x))
    _ => {
      let merged = self.merged.get(var.id)
      let var = merged.or(var)
      if var.is_this {
        match self.this_var {
          Some(var) => self.stmts.push(LocalGet(var))
          None => {
            let this_var = add_local_var(self)
            self.this_var = Some(this_var)
            self.emit_rvalue(result, @ssa.RValue::Closure(self.ssa_name, []))
            self.stmts.push(LocalTee(this_var))
          }
        }
      } else if var.is_global {
        self.stmts.push(GlobalGet(Var::from_ssa(var)))
      } else {
        self.stmts.push(LocalGet(Var::from_ssa(var)))
      }
    }
  }
}

fn WasmFunc::emit_set_var(self : WasmFunc, var : @ssa.Var) -> Unit {
  match var.const_value {
    Some(Int(_)) => ()
    Some(Double(_)) => ()
    _ => {
      let merged = self.merged.get(var.id)
      let var = merged.or(var)
      if var.is_this {
        @util.die("this var should not be updated")
      } else if var.is_global {
        self.stmts.push(GlobalSet(Var::from_ssa(var)))
      } else {
        self.stmts.push(LocalSet(Var::from_ssa(var)))
      }
    }
  }
}
