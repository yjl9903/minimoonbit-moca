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
}

enum IWidth {
  I32
}

enum FWidth {
  F64
}

struct Var {}
