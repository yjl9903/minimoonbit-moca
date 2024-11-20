pub fn transform_knf_const_prop(knf : Knf) -> Knf {
  @knf.clear_const_value()
  let ctx = { map: Map::new() }
  ctx.visit_knf(knf).0
}

enum KnfConstValue {
  Unit
  Int(Int)
  Double(Double)
  // Tuple(Array[KnfConstValue])
}

struct KnfContext {
  map : Map[Name, KnfConstValue]
}

fn KnfContext::get(self : KnfContext, name : Name) -> KnfConstValue? {
  self.map.get(name)
}

fn KnfContext::set(
  self : KnfContext,
  name : Name,
  value : KnfConstValue
) -> Unit {
  match value {
    Int(x) => {
      self.map.set(name, value)
      @knf.set_const_value(name, Int(x))
    }
    _ => ()
  }
}

fn KnfContext::remove(self : KnfContext, name : Name) -> Unit {
  self.map.remove(name)
  @knf.remove_const_value(name)
}

fn KnfContext::visit_knf(self : KnfContext, knf : Knf) -> (Knf, KnfConstValue?) {
  match knf {
    // Literal
    Unit => (knf, Some(Unit))
    Int(x) => (knf, Some(Int(x)))
    Double(x) => (knf, Some(Double(x)))

    // Prim
    Neg(name) =>
      match self.get(name) {
        Some(Int(x)) => (Int(-x), Some(Int(-x)))
        _ => (knf, None)
      }
    Add(lhs, rhs) =>
      match (self.get(lhs), self.get(rhs)) {
        (Some(Int(lhs)), Some(Int(rhs))) =>
          (Int(lhs + rhs), Some(Int(lhs + rhs)))
        _ => (knf, None)
      }
    Sub(lhs, rhs) =>
      match (self.get(lhs), self.get(rhs)) {
        (Some(Int(lhs)), Some(Int(rhs))) =>
          (Int(lhs - rhs), Some(Int(lhs - rhs)))
        _ => (knf, None)
      }
    Mul(lhs, rhs) =>
      match (self.get(lhs), self.get(rhs)) {
        (Some(Int(lhs)), Some(Int(rhs))) =>
          (Int(lhs * rhs), Some(Int(lhs * rhs)))
        _ => (knf, None)
      }
    Div(lhs, rhs) =>
      match (self.get(lhs), self.get(rhs)) {
        (Some(Int(lhs)), Some(Int(rhs))) =>
          if rhs != 0 {
            (Int(lhs / rhs), Some(Int(lhs / rhs)))
          } else {
            (knf, None)
          }
        _ => (knf, None)
      }
    FNeg(name) =>
      match self.get(name) {
        Some(Double(x)) => (Double(-x), Some(Double(-x)))
        _ => (knf, None)
      }
    FAdd(lhs, rhs) =>
      match (self.get(lhs), self.get(rhs)) {
        (Some(Double(lhs)), Some(Double(rhs))) =>
          (Double(lhs + rhs), Some(Double(lhs + rhs)))
        _ => (knf, None)
      }
    FSub(lhs, rhs) =>
      match (self.get(lhs), self.get(rhs)) {
        (Some(Double(lhs)), Some(Double(rhs))) =>
          (Double(lhs - rhs), Some(Double(lhs - rhs)))
        _ => (knf, None)
      }
    FMul(lhs, rhs) =>
      match (self.get(lhs), self.get(rhs)) {
        (Some(Double(lhs)), Some(Double(rhs))) =>
          (Double(lhs * rhs), Some(Double(lhs * rhs)))
        _ => (knf, None)
      }
    FDiv(lhs, rhs) =>
      match (self.get(lhs), self.get(rhs)) {
        (Some(Double(lhs)), Some(Double(rhs))) =>
          if rhs != 0 {
            (Double(lhs / rhs), Some(Double(lhs / rhs)))
          } else {
            (knf, None)
          }
        _ => (knf, None)
      }

    // Loop
    Loop(label, args, body) => {
      args.each(fn { name => self.remove(name.0) })
      let (body, _) = self.visit_knf(body)
      (Loop(label, args, body), None)
    }
    Continue(_) => (knf, None)

    // If
    IfEq(lhs, rhs, true_branch, false_branch, ty) =>
      match (self.get(lhs), self.get(rhs)) {
        (Some(Int(lhs)), Some(Int(rhs))) =>
          if lhs == rhs {
            self.visit_knf(true_branch)
          } else {
            self.visit_knf(false_branch)
          }
        _ => {
          let true_branch = self.visit_knf(true_branch)
          let false_branch = self.visit_knf(false_branch)
          (IfEq(lhs, rhs, true_branch.0, false_branch.0, ty), None)
        }
      }
    IfLe(lhs, rhs, true_branch, false_branch, ty) =>
      match (self.get(lhs), self.get(rhs)) {
        (Some(Int(lhs)), Some(Int(rhs))) =>
          if lhs <= rhs {
            self.visit_knf(true_branch)
          } else {
            self.visit_knf(false_branch)
          }
        _ => {
          let true_branch = self.visit_knf(true_branch)
          let false_branch = self.visit_knf(false_branch)
          (IfLe(lhs, rhs, true_branch.0, false_branch.0, ty), None)
        }
      }
    
    // Match
    Match(expr, pats) =>
      match self.get(expr) {
        Some(knf_val) => {
          let mut res = None
          for pat in pats {
            let flag : Bool = match pat.0 {
              Var(_, _) => {
                res = Some(self.visit_knf(pat.2))
                true
              }
              Int(expr) =>
                match knf_val {
                  Int(val) =>
                    if expr == val {
                      res = Some(self.visit_knf(pat.2))
                      true
                    } else {
                      false
                    }
                  _ => false
                }
              Double(expr) =>
                match knf_val {
                  Double(val) =>
                    if expr == val {
                      res = Some(self.visit_knf(pat.2))
                      true
                    } else {
                      false
                    }
                  _ => false
                }
              _ => false
            }
            if flag {
              break
            }
          }
          match res {
            Some(val) => val
            None => (knf, None)
          }
        }
        _ => (knf, None)
      }

    // Var
    Var(var) =>
      match self.get(var) {
        Some(value) => (knf, Some(value))
        None => (knf, None)
      }
    Tuple(_) => (knf, None)

    // Array
    Get(_) | Put(_) => (knf, None)

    // Apply
    Apply(_) | ExternalFunctionApplication(_) => (knf, None)

    // Let
    Let((name, typ), expr, rest) => {
      let (expr, value) = self.visit_knf(expr)
      match value {
        Some(Int(x)) => self.set(name, Int(x))
        _ => ()
      }
      let rest = self.visit_knf(rest)
      (Let((name, typ), expr, rest.0), rest.1)
    }
    LetRec(def, rest) => {
      let rest = self.visit_knf(rest)
      (LetRec(def, rest.0), rest.1)
    }
    LetTuple(els, expr, rest) => {
      let rest = self.visit_knf(rest)
      (LetTuple(els, expr, rest.0), rest.1)
    }
    // Enum
    Enum(_) => (knf, None)
    // unused
    ExternalArray(_) => (knf, None)
  }
}
