pub fn transform_copy_propagation(knf : Knf) -> Knf {
  let ctx = Context::new()
  ctx.transform(knf)
}

struct Context {
  mut replaced : @immut/hashmap.T[Name, Name]
}

fn Context::new() -> Context {
  { replaced: @immut/hashmap.new() }
}

fn Context::fork(self : Context) -> Context {
  { replaced: self.replaced }
}

fn Context::add_replacement(self : Context, from : Name, to : Name) -> Unit {
  let to = self.replaced.find(to).or(to)
  self.replaced = self.replaced.add(from, to)
}

fn Context::replace(self : Context, name : Name) -> Name {
  match self.replaced.find(name) {
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
    Loop(_) => @util.die("unimplementd")
    // Loop(label, self.replace_many_with_type(args), self.transform(body))
    Continue(_) => @util.die("unimplementd")
    // Continue(label, self.replace_many(args))

    // If
    IfEq(lhs, rhs, true_branch, false_branch, ty) => {
      let lhs = self.replace(lhs)
      let rhs = self.replace(rhs)
      IfEq(
        lhs,
        rhs,
        self.fork().transform(true_branch),
        self.fork().transform(false_branch),
        ty,
      )
    }
    IfLe(lhs, rhs, true_branch, false_branch, ty) => {
      let lhs = self.replace(lhs)
      let rhs = self.replace(rhs)
      IfLe(
        lhs,
        rhs,
        self.fork().transform(true_branch),
        self.fork().transform(false_branch),
        ty,
      )
    }
    // Match
    Match(expr, pats) => {
      let expr = self.replace(expr)
      Match(expr, pats.map(fn { pat => (pat.0, self.fork().transform(pat.1)) }))
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
          let expr = self.fork().transform(expr)
          let rest = self.transform(rest)
          match rest {
            Unit =>
              match expr {
                Unit => Unit
                Apply(_) =>
                  if binding.1 == Unit {
                    expr
                  } else {
                    Let(binding, expr, rest)
                  }
                _ => Let(binding, expr, rest)
              }
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
      let new_ctx = self.fork()
      let def = { ..def, body: new_ctx.transform(def.body) }
      LetRec(def, self.transform(rest))
    }
    // Enum

    Enum(lhs, rhs, array) =>
      Enum(lhs, rhs, array.map(fn { it => self.replace(it) }))
    // unused
    ExternalArray(_) => @util.die("unreachable")
  }
}
