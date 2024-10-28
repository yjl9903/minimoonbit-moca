pub fn const_fold_dfs(
  ast : Syntax,
  mp : @hashmap.T[(String, String), Syntax]
) -> Syntax {
  let __ = @shared.debug("AST: \{ast}");
  match ast {
    Prim(lhs, rhs, op, ~kind) => {
      // debug("Matched Prim")
      let new_lhs = const_fold_dfs(lhs, mp)
      let new_rhs = const_fold_dfs(rhs, mp)
      match new_lhs {
        Int(l_value) =>
          match new_rhs {
            Int(r_value) => Int(get_bin_op_value_Int(l_value, r_value, op))
            _ => Prim(new_lhs, new_rhs, op, ~kind)
          }
        Double(l_value) =>
          match new_rhs {
            Double(r_value) => Double(get_bin_op_value_Double(l_value, r_value, op))
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
      if mp.contains((id, "Int")) {
        @shared.debug("Matched Var \{id}");
        mp.get((id, "Int")).unwrap()
      } else if mp.contains((id, "Double")) {
        mp.get((id, "Double")).unwrap()
      } else {
        Var(id)
      }
    If(exp, block, else_stmt) => {
      // @shared.debug("exp : \{exp}\n block : \{block}\n else_stmt:\{else_stmt}")
      // @shared.debug("IF : \{mp}")
      let lhs = const_fold_dfs(exp, mp)
      let rhs = const_fold_dfs(block, mp)
      let next_stmt = const_fold_dfs(else_stmt, mp)
      // @shared.debug("Ihs : \{lhs}\n rhs : \{rhs}\n next:\{next_stmt}")
      If(lhs, rhs, next_stmt)
    }
    App(app, arr) => {
      let new_arr = []
      for ele in arr {
        let new_ele = const_fold_dfs(ele, mp)
        new_arr.push(new_ele)
      }
      App(app, new_arr)
    }
    _ => ast
  }
}

fn const_fold_dfs_fundef(
  fundef : @types.Fundef,
  mp : @hashmap.T[(String, String), Syntax]
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
  mp : @hashmap.T[(String, String), Syntax]
) -> Syntax {
  // @shared.debug("Matched Let id: \{id}")
  let new_expr = const_fold_dfs(expr, mp)
  match new_expr {
    Int(const_value) => {
      mp.remove((id, "Int"))
      mp.remove((id, "Double"))
      let value: Syntax = Int(const_value)
      mp.set((id, "Int"), value)
      Let((id, value_type), Int(const_value), const_fold_dfs(next_stmt, mp))
    }
    Double(const_value) => {
      mp.remove((id, "Int"))
      mp.remove((id, "Double"))
      let value: Syntax = Double(const_value)
      mp.set((id, "Double"), value)
      Let((id, value_type), Double(const_value), const_fold_dfs(next_stmt, mp))
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
