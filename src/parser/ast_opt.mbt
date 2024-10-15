enum Pass {
  Constprop
  Liveness
}

pub fn parser_opt(ast : Syntax) -> Syntax {
  println("Original ast : \{ast} \n")
  let pass_arr = [Constprop, Liveness]
  pass_arr.fold(
    init=ast,
    fn {
      ast, pass_name =>
        match pass_name {
          Constprop => constprop_dfs(liveness_dfs(ast).0, @hashmap.new())
          Liveness => liveness_dfs(ast).0
        }
    },
  )
}
