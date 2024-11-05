fn copy_func_body(def : @knf.FuncDef, args : Array[Name]) -> Knf {
  let body = def.body
  let params = def.args

  // Inline method
  args.rev_foldi(
    fn { i, acc, arg => Let(params[args.length() - 1 - i], Var(arg), acc) },
    init=body,
  )
}

// fn replace_stmt(map : Map[Name, Name], knf : Knf) -> Knf {
//   knf
// }
