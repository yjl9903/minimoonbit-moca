pub typealias LocalEnv = @immut/hashmap.T[String, Type]

struct KnfEnv {
  mut counter : Int
  env : @hashmap.T[String, Name]
  types : Array[Type]
  externals : @immut/hashmap.T[String, Type]
}

pub fn KnfEnv::new(externals : @immut/hashmap.T[String, Type]) -> KnfEnv {
  { counter: 1, env: @hashmap.new(), types: Array::new(), externals }
}

pub fn KnfEnv::fork(self : KnfEnv) -> KnfEnv {
  {
    counter: 1,
    env: @hashmap.new(),
    types: Array::new(),
    externals: self.externals,
  }
}

pub fn KnfEnv::init_counter_from_existing(
  self : KnfEnv,
  existing : Knf
) -> Unit {
  self.counter = knf_max_counter(existing) + 1
}

fn KnfEnv::new_temp(self : KnfEnv, typ : Type) -> Name {
  let counter = self.counter
  let temp = Name::slot_only(counter)
  self.types.push(typ)
  self.counter += 1
  temp
}

fn KnfEnv::new_named_temp(self : KnfEnv, name : Name, typ : Type) -> Name {
  let counter = self.counter
  let binding = { ..name, slot: counter }
  match binding.name {
    Some(name) => self.env.set(name, binding)
    _ => ()
  }
  self.types.push(typ)
  self.counter += 1
  name
}

fn KnfEnv::new_let_binding(self : KnfEnv, name : String, typ : Type) -> Name {
  let counter = self.counter
  let binding : Name = { name: Some(name), slot: counter }
  self.env.set(name, binding)
  self.types.push(typ)
  self.counter += 1
  binding
}

fn KnfEnv::new_let_rec_binding(self : KnfEnv, def : @types.Fundef) -> Name {
  let counter = self.counter
  let name = def.name.0
  let binding : Name = { name: Some(name), slot: counter }
  self.env.set(name, binding)
  self.types.push(def.name.1)
  self.counter += 1
  binding
}

fn KnfEnv::find_binding_by_string(self : KnfEnv, name : String) -> Name? {
  self.env.get(name)
}

fn KnfEnv::find_type_by_name(self : KnfEnv, name : Name) -> Type? {
  self.types.get(name.slot - 1)
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

  self.bind_global_const(visitor(syntax))
}

/// Bind const: %const_1
fn KnfEnv::bind_global_const(self : KnfEnv, rest : Knf) -> Knf {
  let expr = Knf::Int(1)
  let ty = Type::Int
  let name = self.new_let_binding(@types.one_binding_name, ty)
  Knf::Let((name, ty), expr, rest)
}

fn KnfEnv::visit_let_rec(self : KnfEnv, def : @types.Fundef) -> FuncDef {
  let name = self.new_let_rec_binding(def)
  let new_env = self.fork()
  let args = def.args.map(
    fn { (name, typ) => (new_env.new_let_binding(name, typ), typ) },
  )
  let body = new_env.visit_stmt(def.body)
  { name, ty: def.name.1, args, body }
}

fn KnfEnv::visit_stmt(self : KnfEnv, syntax : @types.Syntax) -> Knf {
  match syntax {
    Let((name, typ), expr, rest) => {
      let expr = self.visit_expr(expr)
      let name = self.new_let_binding(name, typ)
      let rest = self.visit_stmt(rest)
      Knf::Let((name, typ), expr, rest)
    }
    LetRec(def, rest) => {
      let funcdef = self.visit_let_rec(def)
      let rest = self.visit_stmt(rest)
      Knf::LetRec(funcdef, rest)
    }
    _ => self.visit_expr(syntax)
  }
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
    Tuple(els) => {
      /// Generate:
      ///   let _0 = 0 in
      ///     let _1 = 1 in
      ///       let _2 = 2 in
      ///         ...
      ///           (_0, _1, _2, ...)

      // TODO: infer the correct type
      let bindings = els.map(fn { _ => self.new_temp(Type::Unit) })
      let tuple = Knf::Tuple(bindings)
      els
      .mapi(fn { idx, el => (bindings[idx], self.visit_expr(el)) })
      .rev_fold(
        fn {
          suffix, (name, expr) =>
            Knf::Let(
              (name, self.find_type_by_name(name).unwrap()),
              expr,
              suffix,
            )
        },
        init=tuple,
      )
    }
    Not(_expr) =>
      // TODO
      abort("todo")
    Array(_n, _el) =>
      // TODO: create n and el
      Knf::ExternalFunctionApplication("minimbt_create_array", [])
    Neg(_expr, ~kind) =>
      match kind {
        Some(Int) =>
          // TODO
          abort("todo")
        Some(Double) =>
          // TODO
          abort("todo")
        None =>
          // TODO
          abort("todo")
      }
    App(_sig, _args) =>
      // TODO
      abort("todo")
    Get(_recv, _idx) =>
      // TODO
      abort("todo")
    If(_cond, _true_branch, _false_branch) =>
      // TODO
      abort("todo")
    Prim(_lhs, _rhs, _op, ~kind) =>
      match kind {
        Some(Int) =>
          // TODO
          abort("todo")
        Some(Double) =>
          // TODO
          abort("todo")
        None =>
          // TODO
          abort("todo")
      }
    Eq(_lhs, _rhs) =>
      // TODO
      abort("todo")
    LE(_lhs, _rhs) =>
      // TODO
      abort("todo")

    // Binding
    Let((_name, _typ), _expr, _rest) =>
      // TODO
      abort("todo")
    LetRec(_def, _rest) =>
      // TODO
      abort("todo")
    LetTuple(_els, _expr, _rest) =>
      // TODO
      abort("todo")
    Put(_recv, _idx, _expr) =>
      // TODO
      abort("todo")
  }
}
