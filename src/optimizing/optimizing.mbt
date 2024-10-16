typealias Syntax = @types.Syntax

enum Pass {
  Constprop
  Liveness
}

pub fn parser_opt(ast : Syntax) -> Syntax {
  @shared.debug("Original ast : \{ast} \n")
  let pass_arr = [Constprop, Liveness]
  let result = pass_arr.fold(
    init=ast,
    fn {
      ast, pass_name =>
        match pass_name {
          Constprop => @const.constprop_dfs(ast, @hashmap.new())
          Liveness => @liveness.liveness_dfs(ast).0
        }
    },
  )
  @shared.debug("Pass ast : \{result}")
  result
}
