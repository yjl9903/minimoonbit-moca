pub fn transform_copy_propagation(knf : Knf) -> Knf {
  let ctx = Context::new()
  ctx.transform(knf)
}

struct Context {
  replaced : Map[Name, Name]
}

fn Context::new() -> Context {
  { replaced: Map::new() }
}

fn Context::add_replacement(self : Context, from : Name, to : Name) -> Unit {
  let to = self.replaced.get(to).or(to)
  self.replaced.set(from, to)
}

fn Context::replace(self : Context, name : Name) -> Name {
  match self.replaced.get(name) {
    Some(name) => name
    None => name
  }
}

fn Context::replace_many(self : Context, names : Array[Name]) -> Array[Name] {
  names.map(fn { n => self.replace(n) })
}

fn Context::replace_many_with_type(
  self : Context,
  names : Array[(Name, @types.Type)]
) -> Array[(Name, @types.Type)] {
  names.map(fn { (n, t) => (self.replace(n), t) })
}

fn Context::transform(self : Context, knf : Knf) -> Knf {
  match knf {
    Unit | Int(_) | Double(_) => knf
    Var(name) => Var(self.replace(name))
    Tuple(els) => Tuple(self.replace_many(els))

    // Prim
    Neg(e) => Neg(self.replace(e))
    FNeg(e) => FNeg(self.replace(e))
    Add(lhs, rhs) => Add(self.replace(lhs), self.replace(rhs))
    Sub(lhs, rhs) => Sub(self.replace(lhs), self.replace(rhs))
    Mul(lhs, rhs) => Mul(self.replace(lhs), self.replace(rhs))
    Div(lhs, rhs) => Div(self.replace(lhs), self.replace(rhs))
    FAdd(lhs, rhs) => FAdd(self.replace(lhs), self.replace(rhs))
    FSub(lhs, rhs) => FSub(self.replace(lhs), self.replace(rhs))
    FMul(lhs, rhs) => FMul(self.replace(lhs), self.replace(rhs))
    FDiv(lhs, rhs) => FDiv(self.replace(lhs), self.replace(rhs))

    // Array
    Get(recv, idx) => Get(self.replace(recv), self.replace(idx))
    Put(recv, idx, expr) =>
      Put(self.replace(recv), self.replace(idx), self.replace(expr))

    // Apply
    ExternalFunctionApplication(label, args) =>
      ExternalFunctionApplication(label, self.replace_many(args))
    Apply(callee, args) => {
      let callee = self.replace(callee)
      let args = self.replace_many(args)
      Apply(callee, args)
    }

    // Loop
    Loop(label, args, body) =>
      Loop(label, self.replace_many_with_type(args), self.transform(body))
    Continue(label, args) => Continue(label, self.replace_many(args))

    // If
    IfEq(lhs, rhs, true_branch, false_branch, ty) => {
      let lhs = self.replace(lhs)
      let rhs = self.replace(rhs)
      IfEq(
        lhs,
        rhs,
        self.transform(true_branch),
        self.transform(false_branch),
        ty,
      )
    }
    IfLe(lhs, rhs, true_branch, false_branch, ty) => {
      let lhs = self.replace(lhs)
      let rhs = self.replace(rhs)
      IfLe(
        lhs,
        rhs,
        self.transform(true_branch),
        self.transform(false_branch),
        ty,
      )
    }

    // Let
    Let(binding, expr, rest) =>
      match expr {
        Var(var) => {
          self.add_replacement(binding.0, var)
          let rest = self.transform(rest)
          rest
        }
        _ => {
          let expr = self.transform(expr)
          let rest = self.transform(rest)
          match rest {
            Var(rv) =>
              if binding.0 == rv {
                expr
              } else {
                Let(binding, expr, rest)
              }
            _ => Let(binding, expr, rest)
          }
        }
      }
    LetTuple(binding, expr, rest) => {
      let expr = self.replace(expr)
      LetTuple(binding, expr, self.transform(rest))
    }
    LetRec(def, rest) => {
      let new_ctx = Context::new()
      let def = { ..def, body: new_ctx.transform(def.body) }
      LetRec(def, self.transform(rest))
    }

    // unused
    ExternalArray(_) => @util.die("unreachable")
  }
}
