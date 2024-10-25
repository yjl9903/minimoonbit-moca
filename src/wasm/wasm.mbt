pub let minimoonbit_start_identifier = "$minimbt_main"

pub let minimoonbit_table_identifier = "$__minimbt_func_table_"

pub let minimoonbit_import_module = "moonbit"

pub struct WasmResult {
  memory_import : Array[WasmMemory]
  memory : Array[WasmMemory]
  imports : Map[String, (WasmImportFunc, WasmFunc?)]
  types : Map[String, WasmType]
  globals : Map[Int, WasmGlobal]
  funcs : Map[String, (WasmFunc, WasmFunc?)]
  table : WasmTable
  start : String
}

pub struct WasmMemory {
  import_info : (String, String)?
  export_info : String?
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
  mutable : Bool
  ty : Type
  value : Instruction?
}

pub struct WasmFunc {
  identifier : String
  params : Array[(Var, Type)]
  ty : Type
  wasm_type : WasmType?
  is_closure : Bool
  table_index : Int?
  locals : Map[Int, Var]
  free_vars : Array[@ssa.FreeVar]
  stmts : Array[Instruction]

  // Used for building
  this_var : Var?
  merged : Map[Int, @ssa.Var]
}

fn WasmResult::new() -> WasmResult {
  {
    memory_import: [
      {
        import_info: Some((minimoonbit_import_module, "memory")),
        export_info: None,
        limit: 10,
      },
    ],
    memory: [
    // { import_info: None, export_info: None, limit: initial_page_count },
    ],
    imports: Map::new(),
    types: Map::new(),
    globals: Map::from_array(
      [],
      // [(-10, builtin_malloc_cursor), (-11, builtin_malloc_size)],
    ),
    funcs: Map::from_array(
      [],
      // [(builtin_malloc_identifier, (builtin_malloc, None))],
    ),
    table: { identifier: minimoonbit_table_identifier, size: 0 },
    start: minimoonbit_start_identifier,
  }
}
