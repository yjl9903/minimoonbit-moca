pub fn emit_wasm(world : @ssa.World) -> WasmResult {
  let result = WasmResult::new()
  add_imports(world, result)
  world.methods.values().each(fn { m => add_func(world, m, result) })
  add_func(world, world.main_method, result, is_main=true)
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

fn add_func(
  world : @ssa.World,
  method : @ssa.Method,
  result : WasmResult,
  ~is_main : Bool = false
) -> Unit {

}
