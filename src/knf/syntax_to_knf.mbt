pub typealias LocalEnv = @immut/hashmap.T[String, Type]

struct KnfEnv {
  mut counter : Int
  env : @hashmap.T[String, (Name, Type)]
  externals : @immut/hashmap.T[String, Type]
}

pub fn KnfEnv::new(externals : @immut/hashmap.T[String, Type]) -> KnfEnv {
  { counter: 1, env: @hashmap.new(), externals }
}

pub fn KnfEnv::fork(self : KnfEnv) -> KnfEnv {
  // TODO
  { counter: 1, env: @hashmap.new(), externals: self.externals }
}

pub fn KnfEnv::init_counter_from_existing(
  self : KnfEnv,
  existing : Knf
) -> Unit {
  self.counter = knf_max_counter(existing) + 1
}

fn KnfEnv::new_temp(self : KnfEnv) -> Name {
  let temp = Name::slot_only(self.counter)
  self.counter += 1
  temp
}

fn KnfEnv::new_named_temp(self : KnfEnv, name : Name) -> Name {
  let counter = self.counter
  self.counter += 1
  let name = { ..name, slot: counter }
  name
}

fn KnfEnv::new_let_binding(self : KnfEnv, name : String, typ : Type) -> Name {
  // TODO
  let counter = self.counter
  self.counter += 1
  let name = Name::from_string?(name).unwrap()
  abort("todo")
}

fn KnfEnv::new_let_rec_binding(self : KnfEnv, def : @types.Fundef) -> FuncDef {
  // TODO
  let counter = self.counter
  self.counter += 1
  abort("todo")
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
            let funcdef = self.new_let_rec_binding(def)
            let new_env = self.fork()
            let body = new_env.visit_stmt(def.body)
            Knf::LetRec(funcdef, body)
          }
        }
      _ => @util.die("Unexpected node under global context")
    }
  }

  visitor(syntax)
}

fn KnfEnv::visit_stmt(self : KnfEnv, syntax : @types.Syntax) -> Knf {
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
    Var(_name) =>
      // TODO: find in symbol map
      abort("todo")
    Tuple(_els) =>
      // TODO
      abort("todo")
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

fn KnfEnv::visit_expr(self : KnfEnv, syntax : @types.Syntax) -> Knf {
  abort("todo")
}
