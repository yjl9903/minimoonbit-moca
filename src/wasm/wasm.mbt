pub let minimoonbit_start_identifier = "$minimbt_main"

pub let minimoonbit_table_identifier = "$__minimbt_func_table_"

pub let minimoonbit_import_module = "moonbit"

pub struct WasmResult {
  memory : WasmMemory
  imports : Map[String, (WasmImportFunc, WasmFunc?)]
  types : Map[String, WasmType]
  globals : Map[Int, WasmGlobal]
  funcs : Map[String, (WasmFunc, WasmFunc?)]
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
  mut size : Int
}

pub struct WasmType {
  identifier : String
  ty : Type
}

pub struct WasmGlobal {
  identifier : String
  ty : Type
  value : Instruction?
}

pub struct WasmFunc {
  identifier : String
  params : Array[(Var, Type)]
  ty : Type
  is_closure : Bool
  table_index : Int?
  locals : Map[Int, Var]
  stmts : Array[Instruction]

  // Used for building
  merged : Map[Int, @ssa.Var]
}

fn WasmResult::new() -> WasmResult {
  {
    memory: WasmMemory::{
      import_module: minimoonbit_import_module,
      import_name: "memory",
      limit: 10,
    },
    imports: Map::new(),
    types: Map::new(),
    globals: Map::new(),
    funcs: Map::new(),
    table: { identifier: minimoonbit_table_identifier, size: 0 },
    start: minimoonbit_start_identifier,
  }
}
