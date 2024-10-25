pub let initial_page_count : Int = 10

pub let page_size : Int = 64 * 1024

pub let builtin_malloc_identifier = "$__minimbt_builtin_malloc__"

pub let external_malloc_identifier = "$__minimbt_malloc_d_"

let builtin_malloc_cursor : WasmGlobal = {
  identifier: "$__minimbt_builtin_malloc_cursor__",
  mutable: true,
  ty: Type::Int,
  value: Some(IConst(I32, 0)),
}

let builtin_malloc_size : WasmGlobal = {
  identifier: "$__minimbt_builtin_malloc_size__",
  mutable: true,
  ty: Type::Int,
  value: Some(IConst(I32, page_size)),
}

let builtin_malloc_cursor_var : Var = {
  identifier: "$__minimbt_builtin_malloc_cursor__",
  ty: Type::Int,
  var: None,
}

let builtin_malloc_size_var : Var = {
  identifier: "$__minimbt_builtin_malloc_size__",
  ty: Type::Int,
  var: None,
}

let builtin_malloc_param : Var = {
  identifier: "$__minimbt_builtin_malloc_param__",
  ty: Int,
  var: None,
}

let builtin_malloc : WasmFunc = {
  identifier: builtin_malloc_identifier,
  params: [(builtin_malloc_param, Int)],
  ty: Type::DirectFn([Int], Ptr),
  wasm_type: None,
  is_closure: false,
  table_index: None,
  locals: Map::new(),
  free_vars: [],
  stmts: [
    LocalGet(builtin_malloc_param),
    GlobalGet(builtin_malloc_cursor_var),
    IPrim(I32, Add),
    GlobalGet(builtin_malloc_size_var),
    ICmp(I32, Gt_s),
    If,
    IfThen,
    // Allocate one page
    IConst(I32, 1),
    MemoryGrow,
    Drop,
    GlobalGet(builtin_malloc_size_var),
    IConst(I32, page_size),
    IPrim(I32, Add),
    GlobalSet(builtin_malloc_size_var),
    IfEnd,
    IfEnd,
    // Move cursor
    GlobalGet(builtin_malloc_cursor_var), // for return
    GlobalGet(builtin_malloc_cursor_var),
    LocalGet(builtin_malloc_param),
    IPrim(I32, Add),
    GlobalSet(builtin_malloc_cursor_var),
    // Return
    Return,
  ],
  this_var: None,
  merged: Map::new(),
}
