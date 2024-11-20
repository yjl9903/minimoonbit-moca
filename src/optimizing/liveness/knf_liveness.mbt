pub fn transform_knf_liveness(knf : Knf) -> Knf {
  visit_knf(knf).0
}

fn visit_knf(knf : Knf) -> (Knf, @immut/hashset.T[Name], Bool) {
  match knf {
    // Literal
    Unit | Int(_) | Double(_) => (knf, @immut/hashset.new(), false)

    // Prim
    Neg(name) | FNeg(name) => {
      let used = @immut/hashset.new().add(name)
      (knf, used, false)
    }
    Add(lhs, rhs)
    | Sub(lhs, rhs)
    | Mul(lhs, rhs)
    | Div(lhs, rhs)
    | FAdd(lhs, rhs) | FSub(lhs, rhs) | FMul(lhs, rhs) | FDiv(lhs, rhs) => {
      let used = @immut/hashset.new().add(lhs).add(rhs)
      (knf, used, false)
    }

    // Loop
    Loop(_) | Continue(_) => @util.die("unreachable")

    // If
    IfEq(lhs, rhs, true_branch, false_branch, ty) => {
      let (true_branch, used1, effect1) = visit_knf(true_branch)
      let (false_branch, used2, effect2) = visit_knf(false_branch)
      let used = if used1.size() <= used2.size() {
        let mut used = used2.add(lhs).add(rhs)
        used1.each(fn { v => used = used.add(v) })
        used
      } else {
        let mut used = used1.add(lhs).add(rhs)
        used2.each(fn { v => used = used.add(v) })
        used
      }
      (IfEq(lhs, rhs, true_branch, false_branch, ty), used, effect1 || effect2)
    }
    IfLe(lhs, rhs, true_branch, false_branch, ty) => {
      let (true_branch, used1, effect1) = visit_knf(true_branch)
      let (false_branch, used2, effect2) = visit_knf(false_branch)
      let used = if used1.size() <= used2.size() {
        let mut used = used2.add(lhs).add(rhs)
        used1.each(fn { v => used = used.add(v) })
        used
      } else {
        let mut used = used1.add(lhs).add(rhs)
        used2.each(fn { v => used = used.add(v) })
        used
      }
      (IfLe(lhs, rhs, true_branch, false_branch, ty), used, effect1 || effect2)
    }

    // Match
    Match(expr, pats) => {
      let array = pats.map(fn { pat => visit_knf(pat.2) })
      let (used, effect) = array.fold(
        init=(@immut/hashset.new().add(expr), false),
        fn {
          res, item => {
            let mut temp = res.0
            item.1.each(fn { v => temp = temp.add(v) })
            (temp, res.1 || item.2)
          }
        },
      )
      (Match(expr, pats), used, effect)
    }

    // Var
    Var(var) => {
      let used = @immut/hashset.new().add(var)
      (knf, used, false)
    }
    Tuple(els) => {
      let mut used = @immut/hashset.new()
      els.each(fn { v => used = used.add(v) })
      (knf, used, false)
    }

    // Array
    Get(recv, idx) => {
      let used = @immut/hashset.new().add(recv).add(idx)
      (knf, used, false)
    }
    Put(recv, idx, expr) => {
      let used = @immut/hashset.new().add(recv).add(idx).add(expr)
      (knf, used, true)
    }

    // Apply
    Apply(callee, args) => {
      let mut used = @immut/hashset.new().add(callee)
      args.each(fn { v => used = used.add(v) })
      (knf, used, true)
    }
    ExternalFunctionApplication(_, args) => {
      let mut used = @immut/hashset.new()
      args.each(fn { v => used = used.add(v) })
      (knf, used, true)
    }

    // Let
    Let((name, typ), expr, rest) => {
      let (expr, expr_used, expr_effect) = visit_knf(expr)
      let (rest, rest_used, rest_effect) = visit_knf(rest)
      if expr_effect || rest_used.contains(name) {
        let mut used = @immut/hashset.new()
        expr_used.each(fn { v => used = used.add(v) })
        rest_used.each(fn { v => used = used.add(v) })
        (Let((name, typ), expr, rest), used, expr_effect || rest_effect)
      } else {
        (rest, rest_used, rest_effect)
      }
    }
    LetTuple(bindings, expr, rest) => {
      let (rest, rest_used, rest_effect) = visit_knf(rest)
      let used = rest_used.add(expr)
      (LetTuple(bindings, expr, rest), used, rest_effect)
    }
    LetRec(def, rest) => {
      let (body, body_used, _) = visit_knf(def.body)
      let (rest, rest_used, rest_effect) = visit_knf(rest)
      let mut used = @immut/hashset.new()
      body_used.each(fn { v => used = used.add(v) })
      rest_used.each(fn { v => used = used.add(v) })
      let def = { ..def, body, }
      (LetRec(def, rest), used, rest_effect)
    }

    // Enum
    Enum(lhs,rhs,array) =>{
      let used = array.fold(init= @immut/hashset.new(),fn {
        res,elem => {
          let uesd = res.add(elem);
          uesd
        }
      })
      (Enum(lhs,rhs,array),used,false)
    }
    //
    ExternalArray(_) => @util.die("unreachable")
  }
}
