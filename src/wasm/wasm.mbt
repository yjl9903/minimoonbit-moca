pub let minimoonbit_start_identifier = "$minimbt_main"

pub let minimoonbit_table_identifier = "$minimbt_func_table_"

pub let minimoonbit_import_module = "moonbit"

pub struct WasmResult {
  memory : WasmMemory
  imports : Array[WasmImport]
  funcs : Array[WasmFunc]
  table : WasmTable
  start : String
}

pub struct WasmMemory {
  import_module : String
  import_name : String
  limit : Int
}

pub struct WasmImport {
  identifier : String
  import_module : String
  import_name : String
  ty : Type
}

pub struct WasmTable {
  identifier : String
}

pub struct WasmFunc {
  identifier : String
}

fn WasmResult::new() -> WasmResult {
  {
    memory: WasmMemory::{
      import_module: minimoonbit_import_module,
      import_name: "memory",
      limit: 10,
    },
    imports: [],
    funcs: [],
    table: { identifier: minimoonbit_table_identifier },
    start: minimoonbit_start_identifier,
  }
}
