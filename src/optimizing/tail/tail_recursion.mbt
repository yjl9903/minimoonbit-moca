pub fn transform_tail_recursion(knf : Knf) -> Knf {
  visit_knf_tail(knf)
}

fn visit_knf_tail(knf : Knf) -> Knf {
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
    Loop(label, args, body) => Loop(label, args, visit_knf_tail(body))
    Continue(_) => knf

    // If
    IfEq(lhs, rhs, true_branch, false_branch, ty) =>
      IfEq(
        lhs,
        rhs,
        visit_knf_tail(true_branch),
        visit_knf_tail(false_branch),
        ty,
      )
    IfLe(lhs, rhs, true_branch, false_branch, ty) =>
      IfLe(
        lhs,
        rhs,
        visit_knf_tail(true_branch),
        visit_knf_tail(false_branch),
        ty,
      )

    // Match
    Match(expr,pats) =>
      Match(expr,pats.map(fn{pat => {(pat.0,pat.1,self.transform_stmt(pat.2,acc,return_value))}}))
    // Let
    Let(binding, expr, rest) => Let(binding, expr, visit_knf_tail(rest))
    LetTuple(binding, expr, rest) =>
      LetTuple(binding, expr, visit_knf_tail(rest))
    LetRec(def, rest) => {
      // Transform the recursion in the method body
      let def = { ..def, body: visit_knf_tail(def.body) }
      // Transform this method
      let ctx = TailContext::new(def)
      let def = ctx.transform()
      LetRec(def, visit_knf_tail(rest))
    }
    // Enum 
    Enum(_) => knf
    
    // unused
    ExternalArray(_) => @util.die("unreachable")
  }
}

struct TailContext {
  def : @knf.FuncDef
  /// Actual continue invoke args
  actual_args : Array[@hashset.T[Name]]
  /// Recursive function call has no further continutaion
  mut valid : Bool
}

fn TailContext::new(def : @knf.FuncDef) -> TailContext {
  { def, actual_args: def.args.map(fn { _ => @hashset.new() }), valid: true }
}

fn TailContext::transform(self : TailContext) -> @knf.FuncDef {
  let has_recursion = self.collect_recursion(self.def.body)
  if has_recursion && self.valid {
    @shared.debug("Transform tail recursion: \{self.def.name}")
    let params = self.def.args
      .iter2()
      .to_array()
      .filter(fn { (i, _) => not(self.is_same_arg(i)) })
      .map(fn { (_, a) => a })
    let loop_body = self.transform_stmt(self.def.body, true)
    let func_body = Knf::Loop(
      (self.def.name, @knf.extract_return_type(self.def.ty).unwrap()),
      params,
      loop_body,
    )
    let (new_args, func_body) = transform_args(self.def.args, func_body)
    { ..self.def, args: new_args, body: func_body }
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
    Var(_v) =>
      // if v == self.def.name {
      //   self.valid = false
      // }
      false
    Tuple(_els) =>
      // let found = els.search_by(fn { e => e == self.def.name })
      // match found {
      //   Some(_) => self.valid = false
      //   None => ()
      // }
      false
    Get(recv, idx) => {
      // After tyck, this is impossible
      if recv == self.def.name || idx == self.def.name {
        // self.valid = false
      }
      false
    }
    Put(recv, idx, expr) => {
      if recv == self.def.name || idx == self.def.name || expr == self.def.name {
        // self.valid = false
      }
      false
    }

    // Loop
    Loop((label, _), args, body) =>
      // can not optimize a method twice
      if label == self.def.name {
        self.valid = false
        false
      } else {
        let found = args.search_by(fn { e => e.0 == self.def.name })
        match found {
          Some(_) =>
            // self.valid = false
            false
          None => self.collect_recursion(body)
        }
      }
    Continue(_, _args) =>
      // let found = args.search_by(fn { e => e == self.def.name })
      // match found {
      //   Some(_) => self.valid = false
      //   None => ()
      // }
      false

    // If
    IfEq(lhs, rhs, true_branch, false_branch, _)
    | IfLe(lhs, rhs, true_branch, false_branch, _) =>
      if lhs == self.def.name || rhs == self.def.name {
        // self.valid = false
        false
      } else {
        let true_branch = self.collect_recursion(true_branch)
        let false_branch = self.collect_recursion(false_branch)
        true_branch || false_branch
      }
    
    // Match
    Match(_) => false

    // Apply
    Apply(callee, args) =>
      // let found = args.search_by(fn { e => e == self.def.name })
      // match found {
      //   Some(_) =>
      //     // self.valid = false
      //     false
      //   None => if callee == self.def.name { true } else { false }
      // }
      if callee == self.def.name {
        args.eachi(fn { i, a => self.actual_args[i].insert(a) })
        true
      } else {
        false
      }
    ExternalFunctionApplication(_, _args) =>
      // let found = args.search_by(fn { e => e == self.def.name })
      // match found {
      //   Some(_) => self.valid = false
      //   None => ()
      // }
      false

    // Let
    Let((_, _), expr, rest) => {
      let has_recursion = self.collect_recursion(expr)
      if has_recursion {
        // let has_cont = match rest {
        //   Unit =>
        //     if @knf.extract_return_type(self.def.ty) == Some(Unit) {
        //       false
        //     } else {
        //       true
        //     }
        // Var(var) => if name == var { false } else { true }
        // _ => true
        // }
        // if has_cont {
        //   self.valid = false
        // }
        // true
        self.collect_recursion(rest)
      } else {
        self.collect_recursion(rest)
      }
    }
    LetTuple(_, _, rest) => self.collect_recursion(rest)
    LetRec(_, rest) => self.collect_recursion(rest)
    
    // Enum
    Enum(_) => false

    // unused
    ExternalArray(_) => @util.die("unreachable")
  }
}

fn TailContext::is_same_arg(self : TailContext, i : Int) -> Bool {
  if self.actual_args[i].size() == 1 {
    match self.actual_args[i].iter().head() {
      Some(arg) => arg == self.def.args[i].0
      None => false
    }
  } else {
    false
  }
}

fn TailContext::transform_stmt(
  self : TailContext,
  knf : Knf,
  top_level : Bool
) -> Knf {
  match knf {
    // Literal
    Unit
    | Int(_)
    | Double(_)
    | Neg(_)
    | FNeg(_)
    | Add(_) | Sub(_) | Mul(_) | Div(_) | FAdd(_) | FSub(_) | FMul(_) | FDiv(_) =>
      knf

    // Vars
    Var(_) | Tuple(_) | Get(_) | Put(_) => knf

    // If
    IfEq(lhs, rhs, true_branch, false_branch, ty) =>
      IfEq(
        lhs,
        rhs,
        self.transform_stmt(true_branch, top_level),
        self.transform_stmt(false_branch, top_level),
        ty,
      )
    IfLe(lhs, rhs, true_branch, false_branch, ty) =>
      IfLe(
        lhs,
        rhs,
        self.transform_stmt(true_branch, top_level),
        self.transform_stmt(false_branch, top_level),
        ty,
      )
  
    // Match
    Match(expr,pats) =>
      Match(expr,pats.map(fn{pat => {(pat.0,pat.1,self.transform_stmt(pat.2,top_level))}}))

    // Loop
    Loop(label, args, body) =>
      Loop(label, args, self.transform_stmt(body, false))
    Continue(_) => knf

    // Apply
    Apply(callee, args) =>
      if top_level && callee == self.def.name {
        let args = args
          .iter2()
          .to_array()
          .filter(fn { (i, _) => not(self.is_same_arg(i)) })
          .map(fn { (_, a) => a })
        Continue(self.def.name, args)
      } else {
        knf
      }
    ExternalFunctionApplication(_) => knf

    // Let
    Let(binding, expr, rest) => {
      let expr = self.transform_stmt(expr, false)
      match expr {
        Continue(_) => expr
        _ => Let(binding, expr, self.transform_stmt(rest, top_level))
      }
    }
    LetTuple(binding, expr, rest) =>
      LetTuple(binding, expr, self.transform_stmt(rest, top_level))
    LetRec(def, rest) => LetRec(def, self.transform_stmt(rest, top_level))
    
    // Enum 
    Enum(_) => knf
    
    // unused
    ExternalArray(_) => @util.die("unreachable")
  }
}
