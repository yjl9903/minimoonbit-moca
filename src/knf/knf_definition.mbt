pub typealias Name = @types.Name

pub typealias Type = @types.Type

pub enum Knf {
  Unit
  Int(Int)
  Double(Double)
  Neg(Name)
  Add(Name, Name)
  Sub(Name, Name)
  Mul(Name, Name)
  Div(Name, Name)
  FNeg(Name)
  FAdd(Name, Name)
  FSub(Name, Name)
  FMul(Name, Name)
  FDiv(Name, Name)
  Loop((Name, Type), Array[(Name, Type)], Knf)
  Continue(Name, Array[Name])
  IfEq(Name, Name, Knf, Knf, Type)
  IfLe(Name, Name, Knf, Knf, Type)
  Match(Name, Array[(Pattern, Knf)]) // match <expr> { pattern => body }
  Let((Name, Type), Knf, Knf)
  Var(Name)
  LetRec(FuncDef, Knf)
  Apply(Name, Array[Name])
  Tuple(Array[Name])
  LetTuple(Array[(Name, Type)], Name, Knf)
  Enum(@types.EnumDef, @types.EnumKind, Array[Name])
  Get(Name, Name)
  Put(Name, Name, Name)
  ExternalArray(Name)
  ExternalFunctionApplication(String, Array[Name])
} derive(Show, Eq)

pub struct FuncDef {
  id : Int
  name : Name
  ty : Type
  args : Array[(Name, Type)]
  body : Knf
} derive(Show, Eq)

pub enum Pattern {
  Var(Name?, Type)
  Unit
  Bool(Bool)
  Int(Int)
  Double(Double)
  Tuple(Array[Pattern])
  Enum(@types.EnumDef, @types.EnumKind, Array[Pattern])
} derive(Show, Eq)

pub fn Pattern::extract_vars(self : Pattern) -> Array[(Name, Type)] {
  let res = []
  fn extract(pattern : Pattern) -> Unit {
    match pattern {
      Var(None, _) => ()
      Var(Some(def), typ) => res.push((def, typ))
      Unit | Bool(_) | Int(_) | Double(_) => ()
      Tuple(els) => els.each(fn { el => extract(el) })
      Enum(_, _, els) => els.each(fn { el => extract(el) })
    }
  }

  extract(self)
  res
}
