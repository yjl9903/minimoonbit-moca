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
  Match(Name, Array[(Pattern, Knf)])
  Let((Name, Type), Knf, Knf)
  Var(Name)
  LetRec(FuncDef, Knf)
  Apply(Name, Array[Name])
  Tuple(Array[Name])
  LetTuple(Array[(Name, Type)], Name, Knf)
  Enum(@types.EnumDef, @types.EnumKind, Array[Name])
  LetEnum(@types.EnumDef, Knf)
  Get(Name, Name)
  Put(Name, Name, Name)
  ExternalArray(Name)
  ExternalFunctionApplication(String, Array[Name])
} derive(Show, Eq)

/// Generate unique function id, 0 is kept for the main function
let func_def_id : Ref[Int] = Ref::new(1)

pub struct FuncDef {
  id : Int
  name : Name
  ty : Type
  args : Array[(Name, Type)]
  body : Knf
} derive(Show, Eq)

fn generate_func_id() -> Int {
  let id = func_def_id.val
  func_def_id.val = func_def_id.val + 1
  id
}
