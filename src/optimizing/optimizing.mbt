typealias Syntax = @types.Syntax

pub enum Pass {
  ConstFold
  ConstProp
  Liveness
}

pub fn parser_opt(ast : Syntax) -> Syntax {
  @shared.debug("Original ast : \{ast} \n")
  let pass_arr = [ConstFold, Liveness]
  let result = pass_arr.fold(
    init=ast,
    fn {
      ast, pass_name =>
        match pass_name {
          ConstFold => @const.const_fold_dfs(ast, @hashmap.new())
          Liveness => @liveness.liveness_dfs(ast).0
          _ => @util.die("todo")
        }
    },
  )
  @shared.debug("Pass ast : \{result}")
  result
}
