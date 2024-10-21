pub fn const_fold_dfs(
  ast : Syntax,
  mp : @hashmap.T[(String, String), Int]
) -> Syntax {
  match ast {
    Prim(lhs, rhs, op, ~kind) => {
      // debug("Matched Prim")
      let new_lhs = const_fold_dfs(lhs, mp)
      let new_rhs = const_fold_dfs(rhs, mp)
      match new_lhs {
        Int(l_value) =>
          match new_rhs {
            Int(r_value) => Int(get_bin_op_value(l_value, r_value, op))
            _ => Prim(new_lhs, new_rhs, op, ~kind)
          }
        _ => Prim(new_lhs, new_rhs, op, ~kind)
      }
    }
    LetRec(fundef, syntax) =>
      LetRec(const_fold_dfs_fundef(fundef, mp), const_fold_dfs(syntax, mp))
    Let((id, value_type), expr, next_stmt) =>
      const_fold_dfs_let(id, value_type, expr, next_stmt, mp)
    Var(id) =>
      // @shared.debug("Matched Var \{id}")
      if mp.contains((id, "Int")) {
        Int(mp.get((id, "Int")).unwrap())
      } else {
        Var(id)
      }
    If(exp, block, else_stmt) => {
      // @shared.debug("exp : \{exp}\n block : \{block}\n else_stmt:\{else_stmt}")
      // @shared.debug("IF : \{mp}")
      let lhs = const_fold_dfs(exp, mp)
      let rhs = const_fold_dfs(block, mp)
      let next_stmt = const_fold_dfs(else_stmt, mp)
      If(lhs, rhs, next_stmt)
    }
    _ => ast
  }
}

fn const_fold_dfs_fundef(
  fundef : @types.Fundef,
  mp : @hashmap.T[(String, String), Int]
) -> @types.Fundef {
  // @shared.debug("mp: \{mp}");
  {
    name: fundef.name,
    args: fundef.args,
    body: const_fold_dfs(fundef.body, mp),
  }
}

fn const_fold_dfs_let(
  id : String,
  value_type : @types.Type,
  expr : Syntax,
  next_stmt : Syntax,
  mp : @hashmap.T[(String, String), Int]
) -> Syntax {
  // @shared.debug("Matched Let id: \{id}")
  let new_expr = const_fold_dfs(expr, mp)
  match new_expr {
    Int(const_value) => {
      mp.set((id, "Int"), const_value)
      Let((id, value_type), Int(const_value), const_fold_dfs(next_stmt, mp))
    }
    _ => {
      mp.remove((id, "Int"))
      mp.remove((id, "Double"))
      Let((id, value_type), new_expr, const_fold_dfs(next_stmt, mp))
    }
  }
}

// test {
//   let ast = parse_minimoonbit_file!("test/test_parser/constprop_test.mbt")

//   let mp = @hashmap.new()
//   let res = const_fold_dfs(ast, mp)
//   debug("Res: \{res}")
// }
