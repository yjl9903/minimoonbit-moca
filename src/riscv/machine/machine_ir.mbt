pub struct MachineWorld {
  methods : Array[MachineMethod]
}

pub struct MachineMethod {
  id : Int
  name : String
  ty : Type

  // vars
  this : MachineVar?
  params : Array[MachineVar]
  local_vars : Array[MachineVar]

  // body
  body : IR

  // closure
  is_closure : Bool
  free_vars : Array[@ssa.FreeVar]
}

pub struct MachineVar {
  id : Int
  name : String?
  ty : Type
  size : Int
  offset : Int

  // Flags
  is_this : Bool // this
  is_param : Bool // param
  is_global : Bool // from global
  is_mut : Bool // is mutable, may be updated from loop

  // phi
  is_phi : Bool // phi node
  incoming_vars : Array[MachineVar]
  outcoming_var : MachineVar?
}

pub enum Condition {
  Eq(MachineVar, MachineVar, PrimKind)
  Ne(MachineVar, MachineVar, PrimKind)
  Lt(MachineVar, MachineVar, PrimKind)
  Le(MachineVar, MachineVar, PrimKind)
  Gt(MachineVar, MachineVar, PrimKind)
  Ge(MachineVar, MachineVar, PrimKind)
}

pub enum RValue {
  Int(Int)
  Double(Double)
  Neg(MachineVar, PrimKind)
  Prim(MachineVar, MachineVar, PrimOp, PrimKind)
  Var(MachineVar)
  Load((MachineVar, Int)) // load _, _(_)
  InvokeClosure(MachineVar, Array[MachineVar])
  InvokeDirect(Int, Array[MachineVar])
  Phi(Array[MachineVar])
}

pub enum StmtKind {
  Definition(MachineVar?, RValue)
  Store((MachineVar, Int), MachineVar) // store _(_), _
  IfGoto(Condition, Int, Int)
  Goto(Int)
  Nop
  Return(MachineVar?)
}

pub struct Stmt {
  slot : Int
  mut stmt : StmtKind
  mut def : MachineVar?
  mut uses : Array[MachineVar]
}

pub struct IR {
  stmts : Array[Stmt]
}
