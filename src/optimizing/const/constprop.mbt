typealias Syntax = @types.Syntax

fn get_bin_op_value(lhs : Int, rhs : Int, op : @types.Op) -> Int {
  match op {
    Add => lhs + rhs
    Sub => lhs - rhs
    Mul => lhs * rhs
    Div => lhs / rhs
  }
}

pub fn constprop_dfs(
  ast : Syntax,
  mp : @hashmap.T[(String, String), Int]
) -> Syntax {
  return match ast {
    Prim(lhs, rhs, op, ~kind) => {
      // debug("Matched Prim")
      let new_lhs = constprop_dfs(lhs, mp)
      let new_rhs = constprop_dfs(rhs, mp)
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
      LetRec(constprop_dfs_fundef(fundef, mp), constprop_dfs(syntax, mp))
    Let((id, value_type), expr, next_stmt) =>
      constprop_dfs_let(id, value_type, expr, next_stmt, mp)
    Var(id) =>
      // @shared.debug("Matched Var \{id}")
      if mp.contains((id, "Int")) {
        return Int(mp.get((id, "Int")).unwrap())
      } else {
        return Var(id)
      }
    If(exp, block, else_stmt) => {
      // @shared.debug("exp : \{exp}\n block : \{block}\n else_stmt:\{else_stmt}")
      // @shared.debug("IF : \{mp}")
      let lhs = constprop_dfs(exp, mp)
      let rhs = constprop_dfs(block, mp)
      let next_stmt = constprop_dfs(else_stmt, mp)
      @shared.debug("Ihs : \{lhs}\n rhs : \{rhs}\n next:\{next_stmt}")
      return If(lhs, rhs, next_stmt)
    }
    _ => ast
  }
}

fn constprop_dfs_fundef(
  fundef : @types.Fundef,
  mp : @hashmap.T[(String, String), Int]
) -> @types.Fundef {
  // @shared.debug("mp: \{mp}");
  return {
    name: fundef.name,
    args: fundef.args,
    body: constprop_dfs(fundef.body, mp),
  }
}

fn constprop_dfs_let(
  id : String,
  value_type : @types.Type,
  expr : Syntax,
  next_stmt : Syntax,
  mp : @hashmap.T[(String, String), Int]
) -> Syntax {
  // @shared.debug("Matched Let id: \{id}")
  let new_expr = constprop_dfs(expr, mp)
  return match new_expr {
    Int(const_value) => {
      mp.set((id, "Int"), const_value)
      Let((id, value_type), Int(const_value), constprop_dfs(next_stmt, mp))
    }
    _ => {
      mp.remove((id, "Int"))
      mp.remove((id, "Double"))
      Let((id, value_type), new_expr, constprop_dfs(next_stmt, mp))
    }
  }
}

// test {
//   let ast = parse_minimoonbit_file!("test/test_parser/constprop_test.mbt")

//   let mp = @hashmap.new()
//   let res = constprop_dfs(ast, mp)
//   debug("Res: \{res}")
// }
