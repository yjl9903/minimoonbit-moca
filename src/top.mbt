pub enum Syntax {
  Unit
  Bool(Bool) // true false
  Int(Int) // int
  Double(Double) // double
  Var(String) // _
  Not(Syntax) // not(_)
  Tuple(Array[Syntax]) // (_, _, _)
  Enum(String, String, Array[Syntax]) // _Enum::_Kind(...)
  Array(Syntax, Syntax) // Array::make(_, _)
  Neg(Syntax, mut ~kind : Kind?) // -_
  App(Syntax, Array[Syntax]) // _(_, _, _) or _()
  Get(Syntax, Syntax) // _[_]
  If(Syntax, Syntax, Syntax) // if _ { _ } else { _ }
  Match(Syntax, Array[(Pattern, Syntax)]) // match _ { _ => ... }
  Prim(Syntax, Syntax, Op, mut ~kind : Kind?) // _+ - * / _
  Eq(Syntax, Syntax) // _==_
  LE(Syntax, Syntax) // _<=_
  Let((String, Type), Syntax, Syntax) // let _: _ = _; _
  LetRec(Fundef, Syntax) // fn f() {} ; _
  LetTuple(Array[(String, Type)], Syntax, Syntax) // let (_ , _) : (_, _)= _; _
  LetEnum(EnumDef, Syntax) // enum _ { ... }; _
  Put(Syntax, Syntax, Syntax) // _[_] = _
} derive(Show)

pub enum Kind {
  Int
  Double
} derive(Show, Eq, Hash)

pub enum Op {
  Add
  Sub
  Mul
  Div
} derive(Show, Eq, Hash)

pub struct Fundef {
  name : (String, Type)
  args : Array[(String, Type)]
  body : Syntax
} derive(Show)

pub struct EnumDef {
  name : String
  kinds : Array[EnumKind]
} derive(Show, Eq)

pub struct EnumKind {
  name : String
  fields : Array[Type]
} derive(Show, Eq)

pub fn EnumDef::get_kind(self : EnumDef, kind_name : String) -> EnumKind? {
  match self.kinds.search_by(fn { kind => kind.name == kind_name }) {
    Some(idx) => Some(self.kinds[idx])
    None => None
  }
}

pub enum Pattern {
  Var(String?)
  Unit
  Bool(Bool)
  Int(Int)
  Double(Double)
  Tuple(Array[Pattern])
  Enum(String, String, Array[Pattern])
} derive(Show, Eq)

pub enum Type {
  Unit
  Bool
  Int
  Double
  Fun(Array[Type], Type) // (_, _, _) -> _
  Tuple(Array[Type]) // (_, _, _)
  Array(Type) // Array[_]
  Enum(String) // _enum
  Identifier(String) // type var or enum
  Pi(Array[String], Type) // \forall T. _
  Var(Ref[Type?])
  Ptr
} derive(Show)

pub fn Type::is_ptr_like(self : Type) -> Bool {
  match self {
    Fun(_) | Tuple(_) | Array(_) | Ptr => true
    Var(t) =>
      match t.val {
        Some(t) => t.is_ptr_like()
        None => false
      }
    _ => false
  }
}

pub fn Type::is_float_like(self : Type) -> Bool {
  match self {
    Double => true
    Var(t) =>
      match t.val {
        Some(t) => t.is_float_like()
        None => false
      }
    _ => false
  }
}

pub fn Type::size_of(self : Type, size_of_ptr : Int) -> Int {
  match self {
    Unit => 0
    Bool => 4
    Int => 4
    Double => 8
    Tuple(_) | Fun(_, _) | Array(_) | Enum(_) | Ptr => size_of_ptr
    Var(t) =>
      match t.val {
        Some(t) => t.size_of(size_of_ptr)
        None => @util.die("Uninstantiated type variable")
      }
    Pi(_) => @util.die("Uninstantiated type variable")
    Identifier(_) => @util.die("Uninstantiated type variable")
  }
}

pub fn Type::op_equal(self : Type, other : Type) -> Bool {
  match (self, other) {
    (Unit, Unit) => true
    (Bool, Bool) => true
    (Int, Int) => true
    (Double, Double) => true
    (Fun(xs, x), Fun(ys, y)) => xs == ys && x == y
    (Tuple(xs), Tuple(ys)) => xs == ys
    (Array(x), Array(y)) => x == y
    (Ptr, Ptr) => true
    (Enum(xs), Enum(ys)) => xs == ys
    (Identifier(xs), Identifier(ys)) => xs == ys
    // --- Add this dfs check
    (x, Var({ val: Some(y) })) => x == y
    (Var({ val: Some(x) }), y) => x == y
    // ----------------------
    (Var(x), Var(y)) => x.val == y.val
    _ => false
  }
}

pub fn Pattern::to_json(self : Pattern) -> Json {
  match self {
    Var(None) => "_"
    Var(Some(id)) => id.to_json()
    Unit => "()"
    Bool(value) => value.to_json()
    Int(value) => value.to_json()
    Double(value) => value.to_json()
    Tuple(pats) => pats.to_json()
    Enum(name, kind, pats) => [name.to_json(), kind.to_json(), pats.to_json()]
  }
}
