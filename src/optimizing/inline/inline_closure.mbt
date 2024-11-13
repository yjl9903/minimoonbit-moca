pub fn transform_closure_method_inline(
  prog : @closure.Program
) -> @closure.Program {
  let ctx = ClosureContext::{
    program: prog,
    path: [],
    closures: Map::new(),
    globals: @immut/hashmap.new(),
  }
  prog.fundefs.each(
    fn {
      def => {
        let info = ClosureInfo::new(ctx, def.name)
        ctx.globals = ctx.globals.add(def.name, info)
      }
    },
  )
  // ctx.collect_closure(prog.body)
  // prog.fundefs.each(fn { def => ctx.collect_closure(def.body) })
  prog
}

struct ClosureContext {
  program : @closure.Program
  path : Array[@closure.FuncDef]
  closures : Map[Name, ClosureInfo]
  mut globals : @immut/hashmap.T[@closure.Label, ClosureInfo]
}

struct ClosureInfo {
  mut def : @closure.FuncDef
  mut size : Int // Small function
  mut applied : Int // count this it is applied
  mut count : Int // count that it is referrenced
}

fn ClosureInfo::new(ctx : ClosureContext, name : @closure.Label) -> ClosureInfo {
  match ctx.globals.find(name) {
    Some(info) => info
    None =>
      match ctx.program.fundefs.search_by(fn { d => d.name == name }) {
        Some(def) => {
          let def = ctx.program.fundefs[def]
          { def, size: 0, applied: 0, count: 0 }
        }
        None => @util.die("unknown closure")
      }
  }
}

fn ClosureContext::collect_closure(
  self : ClosureContext,
  expr : @closure.Expr
) -> Unit {
  match expr {
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
            match self.closures.get(var.0) {
              Some(def) => def.count += 1
              None => ()
            }
        },
      )
      self.collect_closure(body)
    }
    Continue(_, args) =>
      args.each(
        fn {
          var =>
            match self.closures.get(var) {
              Some(def) => def.count += 1
              None => ()
            }
        },
      )

    // If
    IfEq(_, _, true_branch, false_branch, _)
    | IfLe(_, _, true_branch, false_branch, _) => {
      self.collect_closure(true_branch)
      self.collect_closure(false_branch)
    }

    // Var
    Var(var) =>
      match self.closures.get(var) {
        Some(def) => def.count += 1
        None => ()
      }
    MakeTuple(els) =>
      els.each(
        fn {
          var =>
            match self.closures.get(var) {
              Some(def) => def.count += 1
              None => ()
            }
        },
      )

    // Array
    ArrayGet(_) => ()
    ArrayPut(_, _, expr) =>
      match self.closures.get(expr) {
        Some(def) => def.count += 1
        None => ()
      }

    // Invoke
    CallClosure(callee, args) => {
      match self.closures.get(callee) {
        Some(def) => def.count += 1
        None => ()
      }
      args.each(
        fn {
          var =>
            match self.closures.get(var) {
              Some(def) => def.count += 1
              None => ()
            }
        },
      )
    }
    CallDirect(label, args) => {
      match self.globals.find(label) {
        Some(def) => def.applied += 1
        None => ()
      }
      args.each(
        fn {
          var =>
            match self.closures.get(var) {
              Some(def) => def.count += 1
              None => ()
            }
        },
      )
    }

    // Let
    Let(_, expr, rest) => {
      self.collect_closure(expr)
      self.collect_closure(rest)
    }
    LetTuple(_, _, rest) => self.collect_closure(rest)
    MakeClosure((name, _), closure, rest) => {
      let closure_info = ClosureInfo::new(self, closure.name)
      self.closures.set(name, closure_info)
      self.collect_closure(rest)
    }

    // Unused
    ExternalArray(_) => ()
  }
}
