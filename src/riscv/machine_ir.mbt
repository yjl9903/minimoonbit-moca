pub struct MachineWorld {
  globals : Map[Int, MachineVar]
  methods : Array[MachineMethod]
  ssa : @ssa.World
}

pub struct MachineMethod {
  id : Int
  name : String
  ty : Type
  is_main : Bool

  // vars
  this : MachineVar?
  params : Array[MachineVar]
  local_vars : Array[MachineVar]

  // info
  stack_vars : Map[Int, MachineVar]
  mut stack_size : Int

  // body
  body : IR

  // closure
  is_closure : Bool
  free_vars : Array[@ssa.FreeVar]
}

pub enum ConstValue {
  Int(Int)
  Double(Double)
}

pub enum ParamOffset {
  Reg(Reg)
  FReg(FReg)
  Offset(Int)
}

pub struct MachineVar {
  id : Int
  name : String?
  ty : Type
  size : Int

  // Offset
  mut offset : Int
  mut param_offset : ParamOffset?

  // Flags
  is_this : Bool // this
  is_param : Bool // param
  is_global : Bool // from global
  is_mut : Bool // is mutable, may be updated from loop
  const_value : ConstValue? // const value

  // phi
  mut is_phi : Bool // phi node
  mut outcoming_var : MachineVar?
  incoming_vars : Array[MachineVar]
}

pub fn MachineVar::is_float(self : MachineVar) -> Bool {
  match self.ty {
    Double => true
    _ => false
  }
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
  Var(MachineVar, PrimKind)
  Load((MachineVar, Int), PrimKind) // load _, _(_)
  InvokeClosure(MachineVar, Array[MachineVar], PrimKind)
  InvokeDirect(String, Array[MachineVar], PrimKind)
  Malloc(Int)
  Phi(Array[MachineVar])
}

pub enum StmtKind {
  Definition(MachineVar?, RValue)
  Store((MachineVar, Int), MachineVar, PrimKind) // store _(_), _
  StoreAddress((MachineVar, Int), String)
  IfGoto(Condition, Int?, Int?)
  Goto(Int)
  Nop
  Return(MachineVar?)
}

pub struct Stmt {
  slot : Int
  mut stmt : StmtKind
  mut def : MachineVar?
  mut uses : Array[MachineVar]

  // ssa
  ssa : @ssa.Stmt
}

pub fn Stmt::new(slot : Int, stmt : StmtKind, ssa : @ssa.Stmt) -> Stmt {
  { slot, stmt, def: None, uses: [], ssa }
}

pub struct IR {
  stmts : Array[Stmt]
  blocks : Array[Block]
}

pub struct Block {
  label : Int
  stmts : Array[Stmt]
  // mut succ : BlockEdge?
}
