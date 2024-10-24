enum Instruction {
  // Numeric
  IConst(IWidth, Int)
  FConst(FWidth, Double)
  INeg
  FNeg
  IPrim(IWidth, @ssa.PrimOp)
  FPrim(FWidth, @ssa.PrimOp)

  // Variables
  LocalGet(Var)
  LocalSet(Var)
  GlobalGet(Var)
  GlobalSet(Var)

  // Call
  Call(WasmFunc)
  CallIndirect(Int, WasmType)

  // Control flow
  If
  Then
  Else
  IfEnd
  Loop(Int)
  Break(Int)
  Nop
  Return
}

enum IWidth {
  I32
}

enum FWidth {
  F64
}

struct Var {
  identifier : String
  var : @ssa.Var?
  ty : Type
}

fn Var::from_ssa(var : @ssa.Var) -> Var {
  { identifier: "$_\{var.id}", var: Some(var), ty: var.ty }
}

fn Var::temp_this() -> Var {
  { identifier: "$_this", var: None, ty: Type::Ptr }
}
