pub fn transform_may_tail_recursion(knf : Knf) -> Knf {
  visit_knf_may_tail(knf)
}

fn visit_knf_may_tail(knf : Knf) -> Knf {
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
    Loop(label, args, body) => Loop(label, args, visit_knf_may_tail(body))
    Continue(_) => knf

    // If
    IfEq(lhs, rhs, true_branch, false_branch, ty) =>
      IfEq(
        lhs,
        rhs,
        visit_knf_may_tail(true_branch),
        visit_knf_may_tail(false_branch),
        ty,
      )
    IfLe(lhs, rhs, true_branch, false_branch, ty) =>
      IfLe(
        lhs,
        rhs,
        visit_knf_may_tail(true_branch),
        visit_knf_may_tail(false_branch),
        ty,
      )

    // Match
    Match(expr, pats) =>
      Match(
        expr,
        pats.map(fn { pat => (pat.0, pat.1, visit_knf_may_tail(pat.2)) }),
      )

    // Let
    Let(binding, expr, rest) => Let(binding, expr, visit_knf_may_tail(rest))
    LetTuple(binding, expr, rest) =>
      LetTuple(binding, expr, visit_knf_may_tail(rest))
    LetRec(def, rest) => {
      // Transform the recursion in the method body
      let def = { ..def, body: visit_knf_may_tail(def.body) }
      // Transform this method
      let ctx = MayTailContext::new(def)
      let def = ctx.transform()
      LetRec(def, visit_knf_may_tail(rest))
    }

    // Enum
    Enum(_) => knf
    // unused
    ExternalArray(_) => @util.die("unreachable")
  }
}

struct MayTailContext {
  def : @knf.FuncDef
  kind : @hashset.T[@types.Kind]
  op : @hashset.T[@types.Op]
  /// Recursive function call has no further continutaion
  mut valid : Bool
}

fn MayTailContext::new(def : @knf.FuncDef) -> MayTailContext {
  { def, kind: @hashset.new(), op: @hashset.new(), valid: true }
}

fn MayTailContext::transform(self : MayTailContext) -> @knf.FuncDef {
  match @knf.extract_return_type(self.def.ty) {
    Some(Int | Double as ty) => {
      let (has_recursion, const_value) = self.collect_recursion(self.def.body)
      if has_recursion == 2 &&
        self.valid &&
        self.kind.size() == 1 &&
        self.op.size() == 1 &&
        const_value.is_const(ty) {
        // Add acc arg
        let args = []
        args.push_iter(self.def.args.iter())
        let acc = @knf.new_temp()
        args.push((acc, ty))
        // Build loop body
        let loop_body = Knf::Loop(
          (self.def.name, ty),
          args,
          self.transform_stmt(self.def.body, (acc, ty), true),
        )
        if validate(self.def, loop_body) {
          @shared.debug("Transform may tail recursion: \{self.def.name}")
          let func_body = Knf::Let(
            (acc, ty),
            match const_value {
              Int(x) => Int(x)
              Double(x) => Double(x)
              _ => @util.die("unreachable")
            },
            loop_body,
          )
          let (new_args, func_body) = transform_args(self.def.args, func_body)
          { ..self.def, args: new_args, body: func_body }
        } else {
          @shared.debug("Transform may tail recursion failed: \{self.def.name}")
          self.def
        }
      } else {
        self.def
      }
    }
    _ => self.def
  }
}

/// Check whether self is used in other places, like array store
fn MayTailContext::collect_recursion(
  self : MayTailContext,
  knf : Knf
) -> (Int, ConstValue) {
  if not(self.valid) {
    return (0, NAC)
  }
  match knf {
    Unit
    | Neg(_)
    | FNeg(_)
    | Add(_) | Sub(_) | Mul(_) | Div(_) | FAdd(_) | FSub(_) | FMul(_) | FDiv(_) =>
      (0, NAC)

    // Const value
    Int(x) => (0, Int(x))
    Double(x) => (0, Double(x))

    // May directly use self pointer, which has side effects
    Var(v) => {
      if v == self.def.name {
        self.valid = false
      }
      (0, NAC)
    }
    Tuple(els) => {
      let found = els.search_by(fn { e => e == self.def.name })
      match found {
        Some(_) => self.valid = false
        None => ()
      }
      (0, NAC)
    }
    Get(recv, idx) => {
      // After tyck, this is impossible
      if recv == self.def.name || idx == self.def.name {
        self.valid = false
      }
      (0, NAC)
    }
    Put(recv, idx, expr) => {
      if recv == self.def.name || idx == self.def.name || expr == self.def.name {
        self.valid = false
      }
      (0, NAC)
    }

    // Loop
    Loop((label, _), args, body) =>
      // can not optimize a method twice
      if label == self.def.name {
        self.valid = false
        (0, NAC)
      } else {
        let found = args.search_by(fn { e => e.0 == self.def.name })
        match found {
          Some(_) => {
            self.valid = false
            (0, NAC)
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
      (0, NAC)
    }

    // If
    IfEq(lhs, rhs, true_branch, false_branch, _)
    | IfLe(lhs, rhs, true_branch, false_branch, _) =>
      if lhs == self.def.name || rhs == self.def.name {
        self.valid = false
        (0, NAC)
      } else {
        let true_branch = self.collect_recursion(true_branch)
        let false_branch = self.collect_recursion(false_branch)
        (
          @math.maximum(true_branch.0, false_branch.0),
          union(true_branch.1, false_branch.1),
        )
      }

    // Match
    Match(_, _) => {
      self.valid = false
      (0, NAC)
    }

    // Apply
    Apply(callee, args) => {
      let found = args.search_by(fn { e => e == self.def.name })
      match found {
        Some(_) => {
          self.valid = false
          (0, NAC)
        }
        None => if callee == self.def.name { (1, UNDEF) } else { (0, NAC) }
      }
    }
    ExternalFunctionApplication(_, args) => {
      let found = args.search_by(fn { e => e == self.def.name })
      match found {
        Some(_) => self.valid = false
        None => ()
      }
      (0, NAC)
    }

    // Let
    Let((name, _), expr, rest) => {
      let (has_recursion, const_value) = self.collect_recursion(expr)
      if has_recursion == 0 {
        self.collect_recursion(rest)
      } else if has_recursion == 1 {
        let has_cont = match rest {
          Add(lhs, rhs) | FAdd(lhs, rhs) | Mul(lhs, rhs) | FMul(lhs, rhs) =>
            if name == lhs || name == rhs {
              false
            } else {
              true
            }
          _ => true
        }
        if has_cont {
          self.valid = false
          (0, NAC)
        } else {
          match rest {
            Add(_) | FAdd(_) => self.op.insert(Add)
            Mul(_) | FMul(_) => self.op.insert(Mul)
            _ => ()
          }
          match rest {
            Add(_) | Mul(_) => self.kind.insert(Int)
            FAdd(_) | FMul(_) => self.kind.insert(Double)
            _ => ()
          }
          (2, const_value)
        }
      } else {
        self.valid = false
        (0, NAC)
      }
    }
    LetTuple(_, _, rest) => self.collect_recursion(rest)
    LetRec(_, rest) => self.collect_recursion(rest)

    //Enum
    Enum(_) => {
      self.valid = false
      (0, NAC)
    }

    // unused
    ExternalArray(_) => @util.die("unreachable")
  }
}

enum ConstValue {
  UNDEF
  Int(Int)
  Double(Double)
  NAC
}

fn ConstValue::union(lhs : ConstValue, rhs : ConstValue) -> ConstValue {
  match (lhs, rhs) {
    (NAC, _) | (_, NAC) => NAC
    (UNDEF, Int(x)) | (Int(x), UNDEF) => Int(x)
    (UNDEF, Double(x)) | (Double(x), UNDEF) => Double(x)
    (Int(x), Int(y)) => if x == y { Int(x) } else { NAC }
    (Double(x), Double(y)) => if x == y { Double(x) } else { NAC }
    (UNDEF, UNDEF) => UNDEF
    (Int(_), Double(_)) | (Double(_), Int(_)) => NAC
  }
}

fn ConstValue::is_const(self : ConstValue, ty : @types.Type) -> Bool {
  match (self, ty) {
    (Int(_), Int) => true
    (Double(_), Double) => true
    _ => false
  }
}

fn MayTailContext::transform_stmt(
  self : MayTailContext,
  knf : Knf,
  acc : (Name, @types.Type),
  return_value : Bool
) -> Knf {
  match knf {
    // Literal
    Unit
    | Neg(_)
    | FNeg(_)
    | Add(_) | Sub(_) | Mul(_) | Div(_) | FAdd(_) | FSub(_) | FMul(_) | FDiv(_) =>
      knf

    // Const value to acc
    Int(_) | Double(_) => if return_value { Var(acc.0) } else { knf }

    // Vars
    Var(_) | Tuple(_) | Get(_) | Put(_) => knf

    // If
    IfEq(lhs, rhs, true_branch, false_branch, ty) =>
      IfEq(
        lhs,
        rhs,
        self.transform_stmt(true_branch, acc, return_value),
        self.transform_stmt(false_branch, acc, return_value),
        ty,
      )
    IfLe(lhs, rhs, true_branch, false_branch, ty) =>
      IfLe(
        lhs,
        rhs,
        self.transform_stmt(true_branch, acc, return_value),
        self.transform_stmt(false_branch, acc, return_value),
        ty,
      )

    // Match
    Match(expr, pats) =>
      Match(
        expr,
        pats.map(
          fn {
            pat => (pat.0, pat.1, self.transform_stmt(pat.2, acc, return_value))
          },
        ),
      )

    // Loop
    Loop(label, args, body) =>
      Loop(label, args, self.transform_stmt(body, acc, false))
    Continue(_) => knf

    // Apply
    Apply(callee, args) =>
      if callee == self.def.name {
        let new_args = []
        new_args.push_iter(args.iter())
        new_args.push(acc.0)
        Continue(self.def.name, new_args)
      } else {
        knf
      }
    ExternalFunctionApplication(_) => knf

    // Let
    Let((name, typ), expr, rest) =>
      if return_value && typ == acc.1 {
        match rest {
          Add(lhs, rhs) | FAdd(lhs, rhs) | Mul(lhs, rhs) | FMul(lhs, rhs) =>
            if name == lhs || name == rhs {
              let other = if name == lhs { rhs } else { lhs }
              let temp_acc = @knf.new_temp()
              let temp_expr : Knf = match rest {
                Add(_) => Add(acc.0, other)
                FAdd(_) => FAdd(acc.0, other)
                Mul(_) => Mul(acc.0, other)
                FMul(_) => FMul(acc.0, other)
                _ => @util.die("unreachable")
              }
              Let(
                (temp_acc, typ),
                temp_expr,
                self.transform_stmt(expr, (temp_acc, typ), false),
              )
            } else {
              Let(
                (name, typ),
                self.transform_stmt(expr, acc, false),
                self.transform_stmt(rest, acc, return_value),
              )
            }
          _ =>
            Let(
              (name, typ),
              self.transform_stmt(expr, acc, false),
              self.transform_stmt(rest, acc, return_value),
            )
        }
      } else {
        Let(
          (name, typ),
          self.transform_stmt(expr, acc, false),
          self.transform_stmt(rest, acc, return_value),
        )
      }
    LetTuple(binding, expr, rest) =>
      LetTuple(binding, expr, self.transform_stmt(rest, acc, return_value))
    LetRec(def, rest) =>
      LetRec(def, self.transform_stmt(rest, acc, return_value))

    // Enum 
    Enum(_) => knf

    // unused
    ExternalArray(_) => @util.die("unreachable")
  }
}
