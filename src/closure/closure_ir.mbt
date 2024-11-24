pub type Label String derive(Show, Eq, Hash)

pub typealias LocalEnv = @immut/hashmap.T[Name, LowType]

pub typealias Name = @types.Name

pub typealias Type = @types.Type

pub typealias Knf = @knf.Knf

pub typealias Pattern = @knf.Pattern

pub enum Expr {
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
  Loop((Name, LowType), Array[(Name, LowType)], Expr)
  Continue(Name, Array[Name])
  IfEq(Name, Name, Expr, Expr, LowType)
  IfLe(Name, Name, Expr, Expr, LowType)
  Match(Name, Array[(Pattern, Expr)])
  Let((Name, LowType), Expr, Expr)
  Var(Name)
  MakeClosure((Name, LowType), Closure, Expr)
  CallClosure(Name, Array[Name])
  CallDirect(Label, Array[Name])
  MakeTuple(Array[Name])
  MakeEnum(@types.EnumDef, @types.EnumKind, Array[Name])
  LetTuple(Array[(Name, LowType)], Name, Expr)
  ArrayGet(Name, Name)
  ArrayPut(Name, Name, Name)
  ExternalArray(Label)
} derive(Show)

pub struct Closure {
  name : Label
  actual_free_vars : Array[Name]
} derive(Show)

pub struct FuncDef {
  id : Int
  name : Label
  old_name : Name
  ty : LowType
  args : Array[(Name, LowType)]
  mut body : Expr

  /// true if the function is a closure function, and the closure will be available at `s11` on 
  /// function entry.
  mut is_closure : Bool
  mut formal_free_vars : Array[(Name, LowType)]
} derive(Show)

pub struct Program {
  fundefs : Array[FuncDef]
  body : Expr
} derive(Show)
