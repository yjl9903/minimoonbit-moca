priv struct Context {
  global : @immut/hashmap.T[Name, Type]
  func_defs : @hashmap.T[Name, FuncDef]
  free_vars : @hashset.T[Name]
  local_vars : @hashmap.T[Name, Type]
}

fn Context::new(externals : Map[String, Type]) -> Context {
  let mut global = @immut/hashmap.new()
  externals.each(
    fn {
      name, typ => {
        let binding = Name::name_only("minimbt_" + name)
        global = global.add(binding, typ)
      }
    },
  )
  {
    global,
    func_defs: @hashmap.new(),
    free_vars: @hashset.new(),
    local_vars: @hashmap.new(),
  }
}

fn Context::fork(self : Context) -> Context {
  let mut global = self.global
  self.local_vars.each(fn { name, typ => global = global.add(name, typ) })
  {
    global: self.global,
    func_defs: self.func_defs,
    free_vars: @hashset.new(),
    local_vars: @hashmap.new(),
  }
}

fn Context::collect_free_var(self : Context, name : Name) -> Unit {
  match self.local_vars.get(name) {
    Some(_) => ()
    None =>
      match self.func_defs.get(name) {
        Some(_) => ()
        None =>
          match self.global.find(name) {
            Some(_) => self.free_vars.insert(name)
            None => @util.die("Unknown identifier name \{name}")
          }
      }
  }
}

/// -------
pub fn knf_program_to_closure(
  knf : Knf,
  externals : Map[String, Type]
) -> Program {
  let (knf, _) = knf_preprocess(knf, externals)
  let context = Context::new(externals)
  context.visit_global_defs(knf)
}

fn Context::visit_global_defs(self : Context, knf : Knf) -> Program {
  let body = self.visit_stmt(knf)
  Program::{ fundefs: [], body }
}

fn Context::visit_stmt(self : Context, knf : Knf) -> Expr {
  match knf {
    // Literal
    Unit => Unit
    Int(v) => Int(v)
    Double(v) => Double(v)

    // Operator
    Neg(expr) => Neg(expr)
    Add(lhs, rhs) => Add(lhs, rhs)
    Sub(lhs, rhs) => Sub(lhs, rhs)
    Mul(lhs, rhs) => Mul(lhs, rhs)
    Div(lhs, rhs) => Div(lhs, rhs)
    FNeg(expr) => FNeg(expr)
    FAdd(lhs, rhs) => FAdd(lhs, rhs)
    FSub(lhs, rhs) => FSub(lhs, rhs)
    FMul(lhs, rhs) => FMul(lhs, rhs)
    FDiv(lhs, rhs) => FDiv(lhs, rhs)
    Apply(_) => abort("todo")

    // If
    IfEq(lhs, rhs, true_branch, false_branch) =>
      IfEq(
        lhs,
        rhs,
        self.visit_stmt(true_branch),
        self.visit_stmt(false_branch),
      )
    IfLe(lhs, rhs, true_branch, false_branch) =>
      IfLe(
        lhs,
        rhs,
        self.visit_stmt(true_branch),
        self.visit_stmt(false_branch),
      )

    // Array
    Get(recv, idx) => ArrayGet(recv, idx)
    Put(recv, idx, expr) => ArrayPut(recv, idx, expr)

    // Binding
    Var(name) => {
      let _ = self.collect_free_var(name)
      Var(name)
    }
    Tuple(els) => MakeTuple(els)

    // Let
    Let(_) => abort("todo")
    LetTuple(_) => abort("todo")
    LetRec(_) => abort("todo")

    // Unused
    ExternalArray(_) | ExternalFunctionApplication(_) =>
      @util.die("unreachable")
  }
}
