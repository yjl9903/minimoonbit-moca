pub let minimoonbit_start_identifier = "$minimbt_main"

pub let minimoonbit_table_identifier = "$__minimbt_func_table_"

pub let minimoonbit_import_module = "moonbit"

pub struct WasmResult {
  memory : WasmMemory
  imports : Map[String, (WasmImportFunc, WasmFunc?)]
  types : Map[String, WasmType]
  funcs : Map[String, WasmFunc]
  table : WasmTable
  start : String
}

pub struct WasmMemory {
  import_module : String
  import_name : String
  limit : Int
}

pub struct WasmImportFunc {
  identifier : String
  import_module : String
  import_name : String
  ty : Type
}

pub struct WasmTable {
  identifier : String
}

pub struct WasmType {
  identifier : String
  ty : @closure.LowType
}

pub struct WasmFunc {
  identifier : String
  table_index : Int
  method : @ssa.Method
}

fn WasmResult::new(world : @ssa.World) -> WasmResult {
  let imports = Map::from_iter(
    world.externals
    .iter()
    .map(
      fn {
        (name, ty) =>
          (
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
    ),
  )
  {
    memory: WasmMemory::{
      import_module: minimoonbit_import_module,
      import_name: "memory",
      limit: 10,
    },
    imports,
    types: Map::new(),
    funcs: Map::new(),
    table: { identifier: minimoonbit_table_identifier },
    start: minimoonbit_start_identifier,
  }
}
