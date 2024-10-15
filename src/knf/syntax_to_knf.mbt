pub typealias LocalEnv = @immut/hashmap.T[String, Type]

struct KnfEnv {
  mut counter : Int
  env : @hashmap.T[String, Name]
  externals : @immut/hashmap.T[String, Type]
}

pub fn KnfEnv::new(externals : @immut/hashmap.T[String, Type]) -> KnfEnv {
  let env = { counter: 1, env: @hashmap.new(), externals }
  externals.each(
    fn {
      name, _ => {
        let binding = Name::name_only(@shared.ffi_prefix + name)
        env.env.set(name, binding)
      }
    },
  )
  env
}

pub fn KnfEnv::fork(self : KnfEnv) -> KnfEnv {
  let fork_env = @hashmap.new()
  self.env.each(fn { k, v => fork_env.set(k, v) })
  { counter: self.counter, env: fork_env, externals: self.externals }
}

pub fn KnfEnv::init_counter_from_existing(
  self : KnfEnv,
  existing : Knf
) -> Unit {
  self.counter = knf_max_counter(existing) + 1
}

fn KnfEnv::new_temp(self : KnfEnv, _typ : Type) -> Name {
  let counter = self.counter
  let temp = Name::slot_only(counter)
  self.counter += 1
  temp
}

fn KnfEnv::new_named_temp(self : KnfEnv, name : String, _typ : Type) -> Name {
  let counter = self.counter
  let name = Name::{ name: Some(name), slot: counter }
  self.counter += 1
  name
}

fn KnfEnv::new_let_binding(self : KnfEnv, name : String, _typ : Type) -> Name {
  let counter = self.counter
  let binding : Name = { name: Some(name), slot: counter }
  self.env.set(name, binding)
  self.counter += 1
  binding
}

fn KnfEnv::new_let_rec_binding(self : KnfEnv, def : @types.Fundef) -> Name {
  let counter = self.counter
  let name = def.name.0
  let binding : Name = { name: Some(name), slot: counter }
  self.env.set(name, binding)
  self.counter += 1
  binding
}

fn KnfEnv::find_binding_by_string(self : KnfEnv, name : String) -> Name? {
  self.env.get(name)
}

pub fn KnfEnv::to_knf(self : KnfEnv, syntax : @types.Syntax) -> Knf {
  self.visit_global_defs(syntax)
}

fn KnfEnv::visit_global_defs(self : KnfEnv, syntax : @types.Syntax) -> Knf {
  fn visitor(syntax : @types.Syntax) {
    match syntax {
      Unit => Knf::Unit
      Let((name, typ), expr, rest) => {
        let expr = self.visit_expr(expr)
        let name = self.new_let_binding(name, typ)
        Knf::Let((name, typ), expr, visitor(rest))
      }
      LetRec(def, rest) =>
        match def.name.0 {
          "init" => {
            let body = self.visit_stmt(def.body)
            let rest = visitor(rest)
            concat_knf(body, rest)
          }
          "main" => self.visit_stmt(def.body)
          _ => {
            let funcdef = self.visit_let_rec(def)
            let rest = visitor(rest)
            Knf::LetRec(funcdef, rest)
          }
        }
      _ => @util.die("Unexpected node under global context")
    }
  }

  self.bind_global_const(fn() { visitor(syntax) })
}

/// Bind const: %const_1
fn KnfEnv::bind_global_const(self : KnfEnv, rest : () -> Knf) -> Knf {
  let ty = Type::Int
  let const0 = self.new_let_binding(@shared.zero_binding_name, ty)
  let expr0 = Knf::Int(0)
  let const1 = self.new_let_binding(@shared.one_binding_name, ty)
  let expr1 = Knf::Int(1)
  Knf::Let((const0, ty), expr0, Knf::Let((const1, ty), expr1, rest()))
}

fn KnfEnv::visit_let_rec(self : KnfEnv, def : @types.Fundef) -> FuncDef {
  let name = self.new_let_rec_binding(def)
  let new_env = self.fork()
  let args = def.args.map(
    fn { (name, typ) => (new_env.new_let_binding(name, typ), typ) },
  )
  let body = new_env.visit_stmt(def.body)
  { id: generate_func_id(), name, ty: def.name.1, args, body }
}

fn KnfEnv::visit_stmt(self : KnfEnv, syntax : @types.Syntax) -> Knf {
  match syntax {
    Let((name, typ), expr, rest) => {
      let expr = self.visit_expr(expr)
      let name = self.new_let_binding(name, typ)
      Knf::Let((name, typ), expr, self.visit_stmt(rest))
    }
    LetRec(def, rest) => {
      let funcdef = self.visit_let_rec(def)
      Knf::LetRec(funcdef, self.visit_stmt(rest))
    }
    LetTuple(names, expr, rest) => {
      let bindings = names.map(
        fn { (name, typ) => (self.new_let_binding(name, typ), typ) },
      )
      self.to_let_temp(
        expr,
        fn { expr => Knf::LetTuple(bindings, expr, self.visit_stmt(rest)) },
      )
    }
    _ => self.visit_expr(syntax)
  }
}

/// Bind a temp variable
/// let _x = (expr) in (rest(_x))
fn KnfEnv::to_let_temp(
  self : KnfEnv,
  expr : @types.Syntax,
  rest : (Name) -> Knf
) -> Knf {
  // TODO: infer the correct type
  let typ = Type::Unit
  let name = self.new_temp(typ)
  Knf::Let((name, typ), self.visit_expr(expr), rest(name))
}

/// Bind two temp variables
/// let _1 = (expr1) in let _2 = (expr2) in ... in (rest(_1, _2, ...))
fn KnfEnv::to_let_binary_temps(
  self : KnfEnv,
  lhs : @types.Syntax,
  rhs : @types.Syntax,
  rest : (@types.Name, @types.Name) -> Knf
) -> Knf {
  self.to_let_temp(
    lhs,
    fn { lhs => self.to_let_temp(rhs, fn { rhs => rest(lhs, rhs) }) },
  )
}

/// Bind three temp variables
/// let _1 = (expr1) in let _2 = (expr2) in ... in (rest(_1, _2, ...))
fn KnfEnv::to_let_triple_temps(
  self : KnfEnv,
  op1 : @types.Syntax,
  op2 : @types.Syntax,
  op3 : @types.Syntax,
  rest : (@types.Name, @types.Name, @types.Name) -> Knf
) -> Knf {
  self.to_let_temp(
    op1,
    fn {
      op1 =>
        self.to_let_temp(
          op2,
          fn { op2 => self.to_let_temp(op3, fn { op3 => rest(op1, op2, op3) }) },
        )
    },
  )
}

/// Bind a list of temp variables
/// let _1 = (expr1) in let _2 = (expr2) in ... in (rest(_1, _2, ...))
fn KnfEnv::to_let_temps(
  self : KnfEnv,
  exprs : Array[@types.Syntax],
  rest : (Array[@types.Name]) -> Knf
) -> Knf {
  // TODO: infer the correct type
  let exprs = exprs.map(
    fn {
      expr => {
        let typ = Type::Unit
        let name = self.new_temp(typ)
        (name, typ, self.visit_expr(expr))
      }
    },
  )
  let bindings = exprs.map(fn { t => t.0 })
  exprs.rev_fold(
    fn { suffix, (name, typ, expr) => Knf::Let((name, typ), expr, suffix) },
    init=rest(bindings),
  )
}

fn KnfEnv::visit_expr(self : KnfEnv, syntax : @types.Syntax) -> Knf {
  match syntax {
    // Literal
    Unit => Knf::Unit
    Int(v) => Knf::Int(v)
    Bool(v) =>
      match v {
        true => Knf::Int(1)
        false => Knf::Int(0)
      }
    Double(v) => Knf::Double(v)

    // Expr
    Var(name) =>
      match self.find_binding_by_string(name) {
        Some(name) => Knf::Var(name)
        None => @util.die("Can not resolve variable \{name}")
      }
    Tuple(els) =>
      ///   let _0 = (expr0) in
      ///     let _1 = (expr1) in
      ///       let _2 = (expr2) in
      ///         ...
      ///           (_0, _1, _2, ...)
      self.to_let_temps(els, fn { names => Knf::Tuple(names) })
    Not(expr) =>
      /// let _expr = (expr) in Sub(%const_1, _expr)
      self.to_let_temp(
        expr,
        fn {
          name =>
            Knf::Sub(
              self.find_binding_by_string(@shared.one_binding_name).unwrap(),
              name,
            )
        },
      )
    Array(n, expr) =>
      /// let _n = (n) in let _expr = (expr) in Array::make(_n, _expr)
      self.to_let_temp(
        n,
        fn {
          n =>
            self.to_let_temp(
              expr,
              fn {
                expr =>
                  Knf::ExternalFunctionApplication(
                    @shared.make_array_binding_name,
                    [n, expr],
                  )
              },
            )
        },
      )
    Neg(expr, ~kind) =>
      /// let _expr = (expr) in Neg(_expr)
      match kind {
        Some(Int) => self.to_let_temp(expr, fn { name => Knf::Neg(name) })
        Some(Double) => self.to_let_temp(expr, fn { name => Knf::FNeg(name) })
        None => @util.die("miss typing information : Neg(expr, None)")
      }
    App(sig, args) =>
      /// let _sig = (sig) in let _arg0 = (arg0) in ... in Apply(_sig, (_arg0, ...))
      self.to_let_temp(
        sig,
        fn {
          sig => self.to_let_temps(args, fn { args => Knf::Apply(sig, args) })
        },
      )
    Get(recv, idx) =>
      /// let _recv = (recv) in let _idx = (idx) in Get(_recv, _idx)
      self.to_let_temp(
        recv,
        fn { recv => self.to_let_temp(idx, fn { idx => Knf::Get(recv, idx) }) },
      )
    If(cond, true_branch, false_branch) =>
      /// let _lhs = (lhs) in let _rhs = (rhs) in IfEq / IfLe (lhs, rhs, true_branch, false_branch)
      match cond {
        Eq(lhs, rhs) =>
          self.to_let_binary_temps(
            lhs,
            rhs,
            fn {
              lhs, rhs =>
                Knf::IfEq(
                  lhs,
                  rhs,
                  self.visit_stmt(true_branch),
                  self.visit_stmt(false_branch),
                )
            },
          )
        LE(lhs, rhs) =>
          self.to_let_binary_temps(
            lhs,
            rhs,
            fn {
              lhs, rhs =>
                Knf::IfLe(
                  lhs,
                  rhs,
                  self.visit_stmt(true_branch),
                  self.visit_stmt(false_branch),
                )
            },
          )
        _ =>
          self.to_let_temp(
            cond,
            fn {
              cond =>
                Knf::IfEq(
                  cond,
                  self.find_binding_by_string(@shared.one_binding_name).unwrap(),
                  self.visit_stmt(true_branch),
                  self.visit_stmt(false_branch),
                )
            },
          )
      }
    Prim(lhs, rhs, op, ~kind) =>
      /// let _lhs = (lhs) in let _rhs = (rhs) in Add / Sub / Mul / Div (_lhs, _rhs)
      match kind {
        Some(Int) =>
          self.to_let_binary_temps(
            lhs,
            rhs,
            fn {
              lhs, rhs =>
                match op {
                  Add => Knf::Add(lhs, rhs)
                  Sub => Knf::Sub(lhs, rhs)
                  Mul => Knf::Mul(lhs, rhs)
                  Div => Knf::Div(lhs, rhs)
                }
            },
          )
        Some(Double) =>
          self.to_let_binary_temps(
            lhs,
            rhs,
            fn {
              lhs, rhs =>
                match op {
                  Add => Knf::FAdd(lhs, rhs)
                  Sub => Knf::FSub(lhs, rhs)
                  Mul => Knf::FMul(lhs, rhs)
                  Div => Knf::FDiv(lhs, rhs)
                }
            },
          )
        None => @util.die("miss typing information : Prim(lhs, rhs, op, None)")
      }
    Eq(lhs, rhs) =>
      /// let _lhs = (lhs) in let _rhs = (rhs) in IfEq(_lhs, _rhs, Int(1), Int(0))
      self.to_let_binary_temps(
        lhs,
        rhs,
        fn { lhs, rhs => Knf::IfEq(lhs, rhs, Knf::Int(1), Knf::Int(0)) },
      )
    LE(lhs, rhs) =>
      /// let _lhs = (lhs) in let _rhs = (rhs) in IfLe(_lhs, _rhs, Int(1), Int(0))
      self.to_let_binary_temps(
        lhs,
        rhs,
        fn { lhs, rhs => Knf::IfLe(lhs, rhs, Knf::Int(1), Knf::Int(0)) },
      )

    // Binding
    Put(recv, idx, expr) =>
      self.to_let_triple_temps(
        recv,
        idx,
        expr,
        fn { recv, idx, expr => Knf::Put(recv, idx, expr) },
      )
    Let(_) => self.visit_stmt(syntax)
    LetRec(_) => self.visit_stmt(syntax)
    LetTuple(_) => self.visit_stmt(syntax)
  }
}
