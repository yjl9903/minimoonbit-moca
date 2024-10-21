pub fn transform_tail_recursion(knf : Knf) -> Knf {
  visit_knf(knf)
}

fn visit_knf(knf : Knf) -> Knf {
  match knf {
    Unit
    | Int(_)
    | Double(_)
    | Var(_)
    | Tuple(_)
    | Get(_)
    | Put(_)
    | Neg(_)
    | FNeg(_)
    | Apply(_)
    | ExternalFunctionApplication(_)
    | Add(_) | Sub(_) | Mul(_) | Div(_) | FAdd(_) | FSub(_) | FMul(_) | FDiv(_) =>
      knf

    // Loop
    Loop(label, args, body) => Loop(label, args, visit_knf(body))
    Continue(_) => knf

    // If
    IfEq(lhs, rhs, true_branch, false_branch, ty) =>
      IfEq(lhs, rhs, visit_knf(true_branch), visit_knf(false_branch), ty)
    IfLe(lhs, rhs, true_branch, false_branch, ty) =>
      IfLe(lhs, rhs, visit_knf(true_branch), visit_knf(false_branch), ty)

    // Let
    Let(binding, expr, rest) => Let(binding, expr, visit_knf(rest))
    LetTuple(binding, expr, rest) => LetTuple(binding, expr, visit_knf(rest))
    LetRec(def, rest) => {
      // Transform the recursion in the method body
      let def = { ..def, body: visit_knf(def.body) }
      // Transform this method
      let ctx = TailContext::new(def)
      let def = ctx.transform()
      LetRec(def, visit_knf(rest))
    }

    // unused
    ExternalArray(_) => @util.die("unreachable")
  }
}

struct TailContext {
  def : @knf.FuncDef
  /// Recursive function call has no further continutaion
  mut valid : Bool
}

fn TailContext::new(def : @knf.FuncDef) -> TailContext {
  { def, valid: true }
}

fn TailContext::transform(self : TailContext) -> @knf.FuncDef {
  let has_recursion = self.collect_recursion(self.def.body)
  if has_recursion && self.valid {
    // TODO: transform
    self.def
  } else {
    self.def
  }
}

fn TailContext::collect_recursion(self : TailContext, knf : Knf) -> Bool {
  if not(self.valid) {
    return false
  }
  match knf {
    Unit
    | Int(_)
    | Double(_)
    | Neg(_)
    | FNeg(_)
    | Add(_) | Sub(_) | Mul(_) | Div(_) | FAdd(_) | FSub(_) | FMul(_) | FDiv(_) =>
      false

    // May directly use self pointer, which has side effects
    Var(v) => {
      if v == self.def.name {
        self.valid = false
      }
      false
    }
    Tuple(els) => {
      let found = els.search_by(fn { e => e == self.def.name })
      match found {
        Some(_) => self.valid = false
        None => ()
      }
      false
    }
    Get(recv, idx) => {
      // After tyck, this is impossible
      if recv == self.def.name || idx == self.def.name {
        self.valid = false
      }
      false
    }
    Put(recv, idx, expr) => {
      if recv == self.def.name || idx == self.def.name || expr == self.def.name {
        self.valid = false
      }
      false
    }

    // Loop
    Loop(label, args, body) =>
      // can not optimize a method twice
      if label == self.def.name {
        self.valid = false
        false
      } else {
        let found = args.search_by(fn { e => e.0 == self.def.name })
        match found {
          Some(_) => {
            self.valid = false
            false
          }
          None => self.collect_recursion(body)
        }
      }
    Continue(_, args) => {
      let found = args.search_by(fn { e => e == self.def.name })
      match found {
        Some(_) => self.valid = false
        None => ()
      }
      false
    }

    // If
    IfEq(lhs, rhs, true_branch, false_branch, _)
    | IfLe(lhs, rhs, true_branch, false_branch, _) =>
      if lhs == self.def.name || rhs == self.def.name {
        self.valid = false
        false
      } else {
        let true_branch = self.collect_recursion(true_branch)
        let false_branch = self.collect_recursion(false_branch)
        true_branch || false_branch
      }

    // Apply
    Apply(callee, args) => {
      let found = args.search_by(fn { e => e == self.def.name })
      match found {
        Some(_) => {
          self.valid = false
          false
        }
        None => if callee == self.def.name { true } else { false }
      }
    }
    ExternalFunctionApplication(_, args) => {
      let found = args.search_by(fn { e => e == self.def.name })
      match found {
        Some(_) => self.valid = false
        None => ()
      }
      false
    }

    // Let
    Let((name, _), expr, rest) => {
      let has_recursion = self.collect_recursion(expr)
      if has_recursion {
        let has_cont = match rest {
          Var(var) => if name == var { false } else { true }
          _ => true
        }
        if has_cont {
          self.valid = false
        }
        true
      } else {
        self.collect_recursion(rest)
      }
    }
    LetTuple(_, _, rest) => self.collect_recursion(rest)
    LetRec(_, rest) => self.collect_recursion(rest)

    // unused
    ExternalArray(_) => @util.die("unreachable")
  }
}
