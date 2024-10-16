enum Pass {
  Constprop
  Liveness
}
typealias Syntax = @types.Syntax
pub fn parser_opt(ast : Syntax) -> Syntax {
  @shared.debug("Original ast : \{ast} \n")
  let pass_arr = [Constprop, Liveness]
  // let pass_arr = [Constprop]
  let result = pass_arr.fold(
    init=ast,
    fn {
      ast, pass_name =>
        match pass_name {
          Constprop => constprop_dfs(ast, @hashmap.new())
          Liveness => liveness_dfs(ast).0
        }
    },
  )
  @shared.debug("Pass ast : \{result}")
  result
}
