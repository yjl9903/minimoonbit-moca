fn copy_func_body(def : @knf.FuncDef, args : Array[Name], size : Int) -> Knf {
  if size < disable_inline_size {
    let replace = Map::new()
    def.args.eachi(fn { i, p => replace.set(p.0, args[i]) })
    match replace_stmt?(replace, def.body) {
      Ok(res) => res
      Err(_) => {
        let body = def.body
        let params = def.args
        args.rev_foldi(
          fn {
            i, acc, arg => Let(params[args.length() - 1 - i], Var(arg), acc)
          },
          init=body,
        )
      }
    }
  } else {
    let body = def.body
    let params = def.args
    args.rev_foldi(
      fn { i, acc, arg => Let(params[args.length() - 1 - i], Var(arg), acc) },
      init=body,
    )
  }
}

type! InlineError Unit

fn replace_stmt(map : Map[Name, Name], knf : Knf) -> Knf!InlineError {
  match knf {
    Unit | Int(_) | Double(_) => knf
    Neg(v) => Neg(map.get_or_default(v, v))
    FNeg(v) => FNeg(map.get_or_default(v, v))
    Add(lhs, rhs) =>
      Add(map.get_or_default(lhs, lhs), map.get_or_default(rhs, rhs))
    Sub(lhs, rhs) =>
      Sub(map.get_or_default(lhs, lhs), map.get_or_default(rhs, rhs))
    Mul(lhs, rhs) =>
      Mul(map.get_or_default(lhs, lhs), map.get_or_default(rhs, rhs))
    Div(lhs, rhs) =>
      Div(map.get_or_default(lhs, lhs), map.get_or_default(rhs, rhs))
    FAdd(lhs, rhs) =>
      FAdd(map.get_or_default(lhs, lhs), map.get_or_default(rhs, rhs))
    FSub(lhs, rhs) =>
      FSub(map.get_or_default(lhs, lhs), map.get_or_default(rhs, rhs))
    FMul(lhs, rhs) =>
      FMul(map.get_or_default(lhs, lhs), map.get_or_default(rhs, rhs))
    FDiv(lhs, rhs) =>
      FDiv(map.get_or_default(lhs, lhs), map.get_or_default(rhs, rhs))

    // Loop
    Loop(_) => raise InlineError(())
    Continue(_) => raise InlineError(())

    // If
    IfEq(lhs, rhs, true_branch, false_branch, ty) =>
      IfEq(
        map.get_or_default(lhs, lhs),
        map.get_or_default(rhs, rhs),
        replace_stmt!(map, true_branch),
        replace_stmt!(map, false_branch),
        ty,
      )
    IfLe(lhs, rhs, true_branch, false_branch, ty) =>
      IfLe(
        map.get_or_default(lhs, lhs),
        map.get_or_default(rhs, rhs),
        replace_stmt!(map, true_branch),
        replace_stmt!(map, false_branch),
        ty,
      )
    // Match
    Match(expr, pats) => {
      let new_pats = []
      for pat in pats {
        new_pats.push((pat.0, replace_stmt!(map, pat.1)))
      }
      Match(map.get_or_default(expr, expr), new_pats)
    }

    // Array
    Get(recv, idx) =>
      Get(map.get_or_default(recv, recv), map.get_or_default(idx, idx))
    Put(recv, idx, expr) =>
      Put(
        map.get_or_default(recv, recv),
        map.get_or_default(idx, idx),
        map.get_or_default(expr, expr),
      )

    // Var
    Var(v) => Var(map.get_or_default(v, v))
    Tuple(els) => Tuple(els.map(fn { el => map.get_or_default(el, el) }))

    // Apply
    Apply(callee, args) =>
      Apply(
        map.get_or_default(callee, callee),
        args.map(fn { a => map.get_or_default(a, a) }),
      )
    ExternalFunctionApplication(label, args) =>
      ExternalFunctionApplication(
        label,
        args.map(fn { a => map.get_or_default(a, a) }),
      )

    // Let
    Let((name, ty), expr, rest) => {
      let expr = replace_stmt!(map, expr)
      let new_name = @knf.new_temp()
      map.set(name, new_name)
      Let((new_name, ty), expr, replace_stmt!(map, rest))
    }
    LetTuple(els, expr, rest) => {
      let new_els = els.map(
        fn {
          el => {
            let new_el = @knf.new_temp()
            map.set(el.0, new_el)
            (new_el, el.1)
          }
        },
      )
      LetTuple(
        new_els,
        map.get_or_default(expr, expr),
        replace_stmt!(map, rest),
      )
    }
    // Enum
    Enum(lhs, rhs, array) =>
      Enum(lhs, rhs, array.map(fn { it => map.get_or_default(it, it) }))
    LetRec(_) => raise InlineError(())

    // Unused
    ExternalArray(_) => raise InlineError(())
  }
}

fn FuncDefInfo::calc_size(self : FuncDefInfo, knf : Knf) -> Int {
  match knf {
    Unit | Int(_) | Double(_) => 1
    Neg(_) | FNeg(_) => 1
    Add(_) | Sub(_) | Mul(_) | Div(_) | FAdd(_) | FSub(_) | FMul(_) | FDiv(_) =>
      1

    // Loop
    Loop(_) => disable_inline_size
    Continue(_) => disable_inline_size

    // If
    IfEq(_, _, true_branch, false_branch, _)
    | IfLe(_, _, true_branch, false_branch, _) =>
      1 + self.calc_size(true_branch) + self.calc_size(false_branch)

    // Match
    Match(_, pats) =>
      pats.fold(init=1, fn { sum, pat => sum + self.calc_size(pat.1) })

    // Array
    Get(_) => 1
    Put(_) => 1

    // Var
    Var(_) => 1
    Tuple(els) => 1 + els.length()

    // Apply
    Apply(_, args) => 1 + 1 + args.length()
    ExternalFunctionApplication(_, args) => 1 + args.length()

    // Let
    Let(_, expr, rest) => 1 + self.calc_size(expr) + self.calc_size(rest)
    LetTuple(els, _, rest) => els.length() + self.calc_size(rest)
    LetRec(_) => disable_inline_size

    // Enum
    Enum(_) => disable_inline_size

    // Unused
    ExternalArray(_) => @util.die("unreachable")
  }
}
