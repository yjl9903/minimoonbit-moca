pub fn liveness_dfs(ast : Syntax) -> (Syntax, @hashset.T[String]) {
  return match ast {
    Prim(lhs, rhs, op, ..) =>
      (
        ast,
        @hashset.new().union(liveness_dfs(lhs).1).union(liveness_dfs(rhs).1),
      )
    LetRec(fundef, syntax) => {
      let (new_syntax, live_set) = liveness_dfs(syntax)
      (LetRec(liveness_dfs_fundef(fundef), new_syntax), live_set)
    }
    Let((id, value_type), expr, next_stmt) => {
      let live_set = @hashset.new()
      // dfs next_stmt
      let (next_stmt, next_live_set) = liveness_dfs(next_stmt)
      let live_set = live_set.union(next_live_set)
      live_set.remove(id) // remove def
      // dfs expr_stmt
      let (_, expr_live_set) = liveness_dfs(expr)
      let live_set = live_set.union(expr_live_set) // union use
      debug("id: \{id}; live_set: \{live_set};")
      if next_live_set.contains(id) {
        (Let((id, value_type), expr, next_stmt), live_set)
      } else {
        (next_stmt, live_set)
      }
    }
    App(_, arr) => {
      let live_set = arr.fold(
        init=@hashset.new(),
        fn { lhs, rhs => lhs.union(liveness_dfs(rhs).1) },
      )
      (ast, live_set)
    }
    Var(id) => {
      let live_set = @hashset.new()
      live_set.insert(id)
      (ast, live_set)
    }
    ast => (ast, @hashset.new())
  }
}

fn liveness_dfs_fundef(fundef : @types.Fundef) -> @types.Fundef {
  { name: fundef.name, args: fundef.args, body: liveness_dfs(fundef.body).0 }
}

test {
  let ast = parse_minimoonbit_file!("test/test_parser/liveness.mbt")
  debug("ast: \{ast}")
  let (res, _) = liveness_dfs(ast)
  debug("ast: \{res}")
}
