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
}
