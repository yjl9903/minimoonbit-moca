pub fn transform_knf_to_anf(knf : Knf) -> Knf {
  visit_knf(knf, identity)
}

fn visit_knf(knf : Knf, cont : (Knf) -> Knf) -> Knf {
  match knf {
    Unit
    | Int(_)
    | Double(_)
    | Neg(_)
    | Add(_)
    | Sub(_) | Mul(_) | Div(_) | FNeg(_) | FAdd(_) | FSub(_) | FMul(_) | FDiv(_) =>
      cont(knf)

    // If
    IfEq(lhs, rhs, true_branch, false_branch, ty) =>
      cont(
        IfEq(
          lhs,
          rhs,
          visit_knf(true_branch, identity),
          visit_knf(false_branch, identity),
          ty,
        ),
      )
    IfLe(lhs, rhs, true_branch, false_branch, ty) =>
      cont(
        IfLe(
          lhs,
          rhs,
          visit_knf(true_branch, identity),
          visit_knf(false_branch, identity),
          ty,
        ),
      )

    // Var
    Var(_) | Tuple(_) => cont(knf)

    // Array
    Get(_) | Put(_) => cont(knf)

    // Apply
    Apply(_) | ExternalFunctionApplication(_) => cont(knf)

    // binding
    Let(binding, expr, rest) =>
      visit_knf(
        expr,
        fn {
          result => {
            let rest = visit_knf(rest, cont)
            match rest {
              Var(ret) =>
                if binding.0 == ret {
                  result
                } else {
                  Let(binding, result, rest)
                }
              _ => Let(binding, result, rest)
            }
          }
        },
      )
    LetTuple(binding, expr, rest) =>
      LetTuple(binding, expr, visit_knf(rest, cont))
    LetRec(def, rest) => {
      let body = visit_knf(def.body, identity)
      let def = { ..def, body, }
      LetRec(def, visit_knf(rest, cont))
    }

    // Unreachable
    Loop(_) | Continue(_) | ExternalArray(_) => @util.die("unreachable")
  }
}

fn identity(knf : Knf) -> Knf {
  knf
}
