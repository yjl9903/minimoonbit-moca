enum Instruction {
  // Numeric
  IConst(IWidth, Int)
  FConst(FWidth, Double)
  FNeg(FWidth)
  IPrim(IWidth, @ssa.PrimOp)
  FPrim(FWidth, @ssa.PrimOp)
  ICmp(IWidth, ICmp)
  FCmp(FWidth, FCmp)

  // Variables
  LocalGet(Var)
  LocalSet(Var)
  LocalTee(Var)
  GlobalGet(Var)
  GlobalSet(Var)

  // Call
  Call(WasmFunc)
  CallImport(WasmImportFunc)
  CallIndirect(WasmType)

  // Stack
  Drop

  // Memory
  Malloc
  MemoryGrow
  ILoad(IWidth, Int?)
  IStore(IWidth, Int?)
  FLoad(FWidth, Int?)
  FStore(FWidth, Int?)

  // Control flow
  If // (if
  IfThen // (then
  IfElse // (else
  IfEnd // )
  Loop(Int)
  LoopEnd
  Continue(Int)
  Break(Int)
  Nop
  Return
}

enum IWidth {
  I32
}

enum ICmp {
  Eq
  Gt_s
  Lt_s
  Ge_s
  Le_s
} derive(Show, Eq)

enum FWidth {
  F64
} derive(Show, Eq)

enum FCmp {
  Eq
  Le
} derive(Show, Eq)

struct Var {
  identifier : String
  var : @ssa.Var?
  ty : Type
}

fn Var::from_ssa(var : @ssa.Var) -> Var {
  if var.is_global {
    { identifier: "$__global_\{var.id}", var: Some(var), ty: var.ty }
  } else {
    { identifier: "$_\{var.id}", var: Some(var), ty: var.ty }
  }
}

fn Var::temp_this() -> Var {
  { identifier: "$_this", var: None, ty: Type::Ptr }
}

fn Var::temp_with_type(i : Int, ty : Type) -> Var {
  { identifier: "$__param_\{i}__", var: None, ty }
}
