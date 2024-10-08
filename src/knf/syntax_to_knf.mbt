pub typealias LocalEnv = @immut/hashmap.T[String, Type]

struct KnfEnv {
  mut counter : Int
  externals : @immut/hashmap.T[String, Type]
}

pub fn KnfEnv::new(externals : @immut/hashmap.T[String, Type]) -> KnfEnv {
  { counter: 1, externals }
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
  { ..name, slot: counter }
}

pub fn KnfEnv::to_knf(_self : KnfEnv, s : @types.Syntax) -> Knf { // !Failure
  match s {
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
