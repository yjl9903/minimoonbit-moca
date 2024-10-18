typealias PrimOp = @types.Op

typealias PrimeKind = @types.Kind

typealias Type = @closure.LowType

pub struct Var {
  id : Int
  name : String?
  slot : Int
  ty : Type
  is_this : Bool // this
  is_param : Bool // param
  is_global : Bool // from global
}

pub struct FreeVar {
  id : Int
  name : String?
  slot : Int
  ty : Type
}

pub enum RValue {
  Unit
  Int(Int)
  Double(Double)
  Neg(Var, PrimeKind) // - _
  Prim(Var, Var, PrimOp, PrimeKind) // _ + - * / _
  Var(Var) // _
  Tuple(Array[Var]) // (_0, _1, _2, ...)
  Closure(Int, Array[(FreeVar, Var)]) // signature, free vars
  GetTuple(Var, Int) // _.0 / _.1 / _.2 / ...
  GetArray(Var, Var) // _ [ _ ]
  GetClosure(Var, FreeVar) // this->_
  Apply(Var, Array[Var]) // _ (_0, _1, ...)
  ExternalApply(Name, Array[Var])
  Phi(Array[Var]) // phi (_0, _1, ...)
}

pub enum Condition {
  Eq(Var, Var)
  Le(Var, Var)
}

pub enum StmtKind {
  Definition(Var?, RValue) // _ = _
  ArrayPut(Var, Var, Var) // _[_] = _
  IfGoto(Condition, Int?, Int?) // if _ { _ } else { _ }
  Goto(Int) // goto _
  Nop // nop
  Return(RValue) // return _
}

pub struct Stmt {
  slot : Int
  stmt : StmtKind
}

pub struct Method {
  name : String
  slot : Int
  ty : Type
  this : Var?
  params : Array[Var]
  local_vars : Array[Var]
  body : Array[Stmt]

  // closure
  is_closure : Bool
  formal_free_vars : Array[FreeVar]
  actual_free_vars : Array[Var]
}
