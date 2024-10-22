pub fn liveness_dfs(ast : Syntax) -> (Syntax, @hashset.T[String]) {
  let result = match ast {
    Prim(lhs, rhs, _, ..) =>
      (
        ast,
        @hashset.new().union(liveness_dfs(lhs).1).union(liveness_dfs(rhs).1),
      )
    LetRec(fundef, syntax) => {
      let (new_syntax, live_set) = liveness_dfs(syntax)
      let (fundef, fun_set) = liveness_dfs_fundef(fundef)
      let live_set = live_set.union(fun_set)
      (LetRec(fundef, new_syntax), live_set)
    }
    Let((id, value_type), expr, next_stmt) => {
      let live_set = @hashset.new()
      // dfs next_stmt
      let (next_stmt, next_live_set) = liveness_dfs(next_stmt)
      let live_set = live_set.union(next_live_set)
      live_set.remove(id) // remove def
      // dfs expr_stmt
      let (expr, expr_live_set) = liveness_dfs(expr)
      let live_set = live_set.union(expr_live_set) // union use
      // @shared.debug(
      //   "id: \{id}; expr: \{expr} live_set: \{live_set}; next_set :\{next_live_set}",
      // )
      if next_live_set.contains(id) || live_set.contains("FUNC!") || id == "_" {
        if live_set.contains("FUNC!") {
          live_set.remove("FUNC!")
        }
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
      live_set.insert("FUNC!")
      (ast, live_set)
    }
    Var(id) => {
      let live_set = @hashset.new()
      live_set.insert(id)
      (ast, live_set)
    }
    Get(lhs, rhs) => {
      let live_set = @hashset.new()
      let (lhs, lhs_set) = liveness_dfs(lhs)
      let live_set = live_set.union(lhs_set)
      let (rhs, rhs_set) = liveness_dfs(rhs)
      let live_set = live_set.union(rhs_set)
      (Get(lhs, rhs), live_set)
    }
    Array(lhs, rhs) => {
      let live_set = @hashset.new()
      let (lhs, lhs_set) = liveness_dfs(lhs)
      let live_set = live_set.union(lhs_set)
      let (rhs, rhs_set) = liveness_dfs(rhs)
      let live_set = live_set.union(rhs_set)
      // @shared.debug(
      //   " Array -> lhs : \{lhs} ; rhs : \{rhs}; live_set : \{live_set}",
      // )
      (Array(lhs, rhs), live_set)
    }
    If(condition, block, else_stmt) => {
      let live_set = @hashset.new()
      let (condition, tmp_set) = liveness_dfs(condition)
      let live_set = live_set.union(tmp_set)
      let (block, tmp_set) = liveness_dfs(block)
      let live_set = live_set.union(tmp_set)
      let (else_stmt, tmp_set) = liveness_dfs(else_stmt)
      let live_set = live_set.union(tmp_set)
      (If(condition, block, else_stmt), live_set)
    }
    Neg(val, ~kind) => {
      let (val, live_set) = liveness_dfs(val)
      (Neg(val, ~kind), live_set)
    }
    Put(lhs, rhs, next_stmt) => {
      let live_set = @hashset.new()
      let (lhs, tmp_set) = liveness_dfs(lhs)
      let live_set = live_set.union(tmp_set)
      let (rhs, tmp_set) = liveness_dfs(rhs)
      let live_set = live_set.union(tmp_set)
      let (next_stmt, tmp_set) = liveness_dfs(next_stmt)
      let live_set = live_set.union(tmp_set)
      (Put(lhs, rhs, next_stmt), live_set)
    }
    Not(val) => {
      let (val, live_set) = liveness_dfs(val)
      (Not(val), live_set)
    }
    Tuple(arr) => {
      let live_set = arr.fold(
        init=@hashset.new(),
        fn { lhs, rhs => lhs.union(liveness_dfs(rhs).1) },
      )
      (ast, live_set)
    }
    LetTuple(arr, expr, next_stmt) => {
      let live_set = @hashset.new()
      // dfs next_stmt
      let (next_stmt, next_live_set) = liveness_dfs(next_stmt)
      let live_set = live_set.union(next_live_set)
      let (expr, expr_live_set) = liveness_dfs(expr)
      let live_set = live_set.union(expr_live_set) // union use
      let mut used = false
      for item in arr {
        live_set.remove(item.0)
        if next_live_set.contains(item.0) {
          used = true
        }
      }
      if used || live_set.contains("FUNC!") {
        if live_set.contains("FUNC!") {
          live_set.remove("FUNC!")
        }
        (LetTuple(arr, expr, next_stmt), live_set)
      } else {
        (next_stmt, live_set)
      }
    }
    Eq(lhs, rhs) => {
      let live_set = @hashset.new()
      let (lhs, lhs_set) = liveness_dfs(lhs)
      let live_set = live_set.union(lhs_set)
      let (rhs, rhs_set) = liveness_dfs(rhs)
      let live_set = live_set.union(rhs_set)
      (Eq(lhs, rhs), live_set)
    }
    LE(lhs, rhs) => {
      let live_set = @hashset.new()
      let (lhs, lhs_set) = liveness_dfs(lhs)
      let live_set = live_set.union(lhs_set)
      let (rhs, rhs_set) = liveness_dfs(rhs)
      let live_set = live_set.union(rhs_set)
      (LE(lhs, rhs), live_set)
    }
    ast => (ast, @hashset.new())
  }
  return result
}

fn liveness_dfs_fundef(
  fundef : @types.Fundef
) -> (@types.Fundef, @hashset.T[String]) {
  let (lhs, rhs) = liveness_dfs(fundef.body)
  for item in fundef.args {
    if rhs.contains(item.0) {
      rhs.remove(item.0)
    }
  }
  ({ name: fundef.name, args: fundef.args, body: lhs }, rhs)
}

// test {
//   let ast = parse_minimoonbit_file!("test/test_parser/liveness.mbt")
//   debug("ast: \{ast}")
//   let (res, _) = liveness_dfs(ast)
//   debug("ast: \{res}")
// }
