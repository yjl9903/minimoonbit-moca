fn validate(def : @knf.FuncDef, knf : Knf) -> Bool {
  let ctx = ValidateContext::{ def, valid: true }
  let _ = ctx.validate_knf(knf)
  ctx.valid
}

struct ValidateContext {
  def : @knf.FuncDef
  mut valid : Bool
}

fn ValidateContext::validate_knf(self : ValidateContext, knf : Knf) -> Int {
  if not(self.valid) {
    return 0
  }
  match knf {
    Unit
    | Int(_)
    | Double(_)
    | Neg(_)
    | FNeg(_)
    | Add(_) | Sub(_) | Mul(_) | Div(_) | FAdd(_) | FSub(_) | FMul(_) | FDiv(_) =>
      0

    // May directly use self pointer, which has side effects
    Var(v) => {
      if v == self.def.name {
        self.valid = false
      }
      0
    }
    Tuple(els) => {
      let found = els.search_by(fn { e => e == self.def.name })
      match found {
        Some(_) => self.valid = false
        None => ()
      }
      0
    }
    Get(recv, idx) => {
      // After tyck, this is impossible
      if recv == self.def.name || idx == self.def.name {
        self.valid = false
      }
      0
    }
    Put(recv, idx, expr) => {
      if recv == self.def.name || idx == self.def.name || expr == self.def.name {
        self.valid = false
      }
      0
    }

    // Loop
    Loop(_, args, body) => {
      let found = args.search_by(fn { e => e.0 == self.def.name })
      match found {
        Some(_) => {
          self.valid = false
          0
        }
        None => self.validate_knf(body)
      }
    }
    Continue(_, args) => {
      let found = args.search_by(fn { e => e == self.def.name })
      match found {
        Some(_) => self.valid = false
        None => ()
      }
      1
    }

    // If
    IfEq(lhs, rhs, true_branch, false_branch, _)
    | IfLe(lhs, rhs, true_branch, false_branch, _) =>
      if lhs == self.def.name || rhs == self.def.name {
        self.valid = false
        0
      } else {
        let true_branch = self.validate_knf(true_branch)
        let false_branch = self.validate_knf(false_branch)
        @math.maximum(true_branch, false_branch)
      }

    // Match
    Match(_) =>{
      self.valid = false
      0
    }

    // Apply
    Apply(callee, args) => {
      let found = args.search_by(fn { e => e == self.def.name })
      match found {
        Some(_) => self.valid = false
        None => if callee == self.def.name { self.valid = false }
      }
      0
    }
    ExternalFunctionApplication(_, args) => {
      let found = args.search_by(fn { e => e == self.def.name })
      match found {
        Some(_) => self.valid = false
        None => ()
      }
      0
    }

    // Let
    Let((name, _), expr, rest) => {
      let has_recursion = self.validate_knf(expr)
      if has_recursion == 0 {
        self.validate_knf(rest)
      } else if has_recursion == 1 {
        let has_cont = match rest {
          Var(var) => if name == var { false } else { true }
          _ => true
        }
        if has_cont {
          self.valid = false
        }
        2
      } else {
        self.valid = false
        has_recursion
      }
    }
    LetTuple(_, _, rest) => self.validate_knf(rest)
    LetRec(_, rest) => self.validate_knf(rest)
    
    // Enum
    Enum(_) => 0
    // unused
    ExternalArray(_) => @util.die("unreachable")
  }
}
