pub typealias Name = @types.Name

pub typealias Type = @types.Type

pub typealias Pattern = @types.Pattern

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
  Match(Name, Array[(Pattern, Array[(Name, Type)], Knf)]) // match <expr> { pattern (bind args) => body }
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
