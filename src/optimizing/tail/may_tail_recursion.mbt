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

    // unused
    ExternalArray(_) => @util.die("unreachable")
  }
}

struct MayTailContext {
  def : @knf.FuncDef
  /// Recursive function call has no further continutaion
  mut valid : Bool
}

fn MayTailContext::new(def : @knf.FuncDef) -> MayTailContext {
  { def, valid: true }
}

fn MayTailContext::transform(self : MayTailContext) -> @knf.FuncDef {
  self.def
  // let has_recursion = self.collect_recursion(self.def.body)
  // if has_recursion && self.valid {
  //   @shared.debug("Transform tail recursion: \{self.def.name}")
  //   let loop_body = Knf::Loop(
  //     (self.def.name, @knf.extract_return_type(self.def.ty).unwrap()),
  //     self.def.args,
  //     self.transform_stmt(self.def.body),
  //   )
  //   { ..self.def, body: loop_body }
  // } else {
  //   self.def
  // }
}
