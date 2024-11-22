pub fn transform_knf_method_inline(knf : Knf) -> Knf {
  let context = InlineContext::{
    funcs: Map::new(),
    path: [],
    local: @immut/hashmap.new(),
  }
  context.collect_knf(knf)
  let knf = context.transform(knf)
  context.cleanup(knf)
}

struct InlineContext {
  funcs : Map[Name, FuncDefInfo]
  path : Array[@knf.FuncDef]
  mut local : @immut/hashmap.T[Name, FuncDefInfo]
}

fn InlineContext::fork(
  self : InlineContext,
  ~func : @knf.FuncDef? = None
) -> InlineContext {
  let path = [..self.path]
  match func {
    Some(func) => path.push(func)
    None => ()
  }
  { funcs: self.funcs, path, local: self.local }
}

fn InlineContext::add_local(self : InlineContext, name : Name) -> Unit {
  match self.funcs.get(name) {
    Some(info) => self.local = self.local.add(name, info)
    None => @util.die("unreachable")
  }
}

struct FuncDefInfo {
  mut def : @knf.FuncDef
  mut size : Int // Small function
  mut applied : Int // count this it is applied
  mut count : Int // count that it is referrenced
}

fn FuncDefInfo::should_be_all_inlined(self : FuncDefInfo) -> Bool {
  if self.count > 0 {
    false
  } else if self.applied <= max_inline_applied {
    true
  } else if self.count == 0 {
    for policy in max_inline_policy {
      if self.size <= policy.size && self.applied <= policy.applied {
        return true
      }
    }
    false
  } else {
    false
  }
}

fn InlineContext::collect_knf(self : InlineContext, knf : Knf) -> Unit {
  match knf {
    Unit
    | Int(_)
    | Double(_)
    | Neg(_)
    | Add(_)
    | Sub(_) | Mul(_) | Div(_) | FNeg(_) | FAdd(_) | FSub(_) | FMul(_) | FDiv(_) =>
      ()

    // Loop
    Loop(_, args, body) => {
      args.each(
        fn {
          var =>
            match self.funcs.get(var.0) {
              Some(def) => def.count += 1
              None => ()
            }
        },
      )
      self.collect_knf(body)
    }
    Continue(_, args) =>
      args.each(
        fn {
          var =>
            match self.funcs.get(var) {
              Some(def) => def.count += 1
              None => ()
            }
        },
      )

    // If
    IfEq(_, _, true_branch, false_branch, _)
    | IfLe(_, _, true_branch, false_branch, _) => {
      self.collect_knf(true_branch)
      self.collect_knf(false_branch)
    }

    // Match
    Match(_, pats) => pats.each(fn { pat => self.collect_knf(pat.1) })

    // Var
    Var(var) =>
      match self.funcs.get(var) {
        Some(def) => def.count += 1
        None => ()
      }
    Tuple(els) =>
      els.each(
        fn {
          var =>
            match self.funcs.get(var) {
              Some(def) => def.count += 1
              None => ()
            }
        },
      )

    // Array
    Get(_) => ()
    Put(_, _, expr) =>
      match self.funcs.get(expr) {
        Some(def) => def.count += 1
        None => ()
      }

    // Apply
    Apply(callee, args) => {
      match self.funcs.get(callee) {
        Some(def) => def.applied += 1
        None => ()
      }
      args.each(
        fn {
          var =>
            match self.funcs.get(var) {
              Some(def) => def.count += 1
              None => ()
            }
        },
      )
    }
    ExternalFunctionApplication(_, args) =>
      args.each(
        fn {
          var =>
            match self.funcs.get(var) {
              Some(def) => def.count += 1
              None => ()
            }
        },
      )

    // Let
    Let(_, expr, rest) => {
      self.collect_knf(expr)
      self.collect_knf(rest)
    }
    LetTuple(_, _, rest) => self.collect_knf(rest)
    LetRec(def, rest) => {
      let info = FuncDefInfo::{ def, applied: 0, size: 0, count: 0 }
      info.size = info.calc_size(def.body)
      self.funcs.set(def.name, info)
      self.collect_knf(def.body)
      self.collect_knf(rest)
    }

    // Enum
    Enum(_, _, array) =>
      array.each(
        fn {
          var =>
            match self.funcs.get(var) {
              Some(def) => def.count += 1
              None => ()
            }
        },
      )

    // Unused
    ExternalArray(_) => ()
  }
}

fn InlineContext::transform(self : InlineContext, knf : Knf) -> Knf {
  match knf {
    Unit
    | Int(_)
    | Double(_)
    | Neg(_)
    | Add(_)
    | Sub(_) | Mul(_) | Div(_) | FNeg(_) | FAdd(_) | FSub(_) | FMul(_) | FDiv(_) =>
      knf

    // Loop
    Loop(label, args, body) => Loop(label, args, self.fork().transform(body))
    Continue(_) => knf

    // If
    IfEq(lhs, rhs, true_branch, false_branch, ty) =>
      IfEq(
        lhs,
        rhs,
        self.fork().transform(true_branch),
        self.fork().transform(false_branch),
        ty,
      )
    IfLe(lhs, rhs, true_branch, false_branch, ty) =>
      IfLe(
        lhs,
        rhs,
        self.fork().transform(true_branch),
        self.fork().transform(false_branch),
        ty,
      )

    // Match
    Match(expr, pats) =>
      Match(expr, pats.map(fn { pat => (pat.0, self.fork().transform(pat.1)) }))

    // Var
    Var(_) | Tuple(_) => knf

    // Array
    Get(_) | Put(_) => knf

    // Apply
    Apply(callee, args) =>
      match self.local.find(callee) {
        Some(info) =>
          if info.should_be_all_inlined() {
            if args.length() != info.def.args.length() {
              @util.die("Inline mismatch")
            }
            if self.path.search_by(fn { f => f.id == info.def.id }).is_empty() {
              @shared.debug("Transform inline: \{knf}")
              info.applied -= 1
              copy_func_body(info.def, args, info.size)
            } else {
              knf
            }
          } else {
            knf
          }
        None => knf
      }
    ExternalFunctionApplication(_) => knf

    // Let
    Let(binding, expr, rest) =>
      Let(binding, self.fork().transform(expr), self.transform(rest))
    LetTuple(binding, expr, rest) =>
      LetTuple(binding, expr, self.transform(rest))
    LetRec(def, rest) =>
      match self.funcs.get(def.name) {
        Some(info) => {
          self.add_local(def.name)
          let body = self.fork(func=Some(def)).transform(def.body)
          let def = { ..def, body, }
          info.def = def
          LetRec(def, self.transform(rest))
        }
        None => @util.die("unreachable")
      }

    // Enum
    Enum(_) => knf

    // Unused
    ExternalArray(_) => knf
  }
}

fn InlineContext::cleanup(self : InlineContext, knf : Knf) -> Knf {
  match knf {
    Unit
    | Int(_)
    | Double(_)
    | Neg(_)
    | Add(_)
    | Sub(_) | Mul(_) | Div(_) | FNeg(_) | FAdd(_) | FSub(_) | FMul(_) | FDiv(_) =>
      knf

    // Loop
    Loop(label, args, body) => Loop(label, args, self.cleanup(body))
    Continue(_) => knf

    // If
    IfEq(lhs, rhs, true_branch, false_branch, ty) =>
      IfEq(lhs, rhs, self.cleanup(true_branch), self.cleanup(false_branch), ty)
    IfLe(lhs, rhs, true_branch, false_branch, ty) =>
      IfLe(lhs, rhs, self.cleanup(true_branch), self.cleanup(false_branch), ty)

    // Match
    Match(expr, pats) =>
      Match(expr, pats.map(fn { pat => (pat.0, self.cleanup(pat.1)) }))
    // Var
    Var(_) | Tuple(_) => knf

    // Array
    Get(_) | Put(_) => knf

    // Apply
    Apply(_) => knf
    ExternalFunctionApplication(_) => knf

    // Let
    Let(binding, expr, rest) =>
      Let(binding, self.cleanup(expr), self.cleanup(rest))
    LetTuple(binding, expr, rest) => LetTuple(binding, expr, self.cleanup(rest))
    LetRec(def, rest) =>
      match self.funcs.get(def.name) {
        Some(info) =>
          if info.applied == 0 && info.count == 0 {
            self.cleanup(rest)
          } else {
            let body = self.cleanup(def.body)
            let def = { ..def, body, }
            LetRec(def, self.cleanup(rest))
          }
        None => @util.die("unreachable")
      }

    // Enum 
    Enum(_) => knf
    // Unused
    ExternalArray(_) => knf
  }
}
