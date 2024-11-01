pub enum AstOptPass {
  ConstFold
  ConstProp
  Liveness
}

pub enum KnfOptPass {
  TailRecursion
  MayTailRecursion
  CopyPropagation
}

pub enum ClosureOptPass {}

pub enum SsaOptPass {
  DeadCodeElimination
  ConstProp
}

pub enum MachineOptPass {}

pub enum Pass {
  Ast(AstOptPass)
  Knf(KnfOptPass)
  Closure(ClosureOptPass)
  Ssa(SsaOptPass)
  Machine(MachineOptPass)
}

pub fn AstOptPass::optimize(
  self : AstOptPass,
  ast : @types.Syntax
) -> @types.Syntax {
  match self {
    ConstFold => @const.const_fold_dfs(ast, @hashmap.new())
    ConstProp => @util.die("unimplmented")
    Liveness => @liveness.liveness_dfs(ast).0
  }
}

pub fn KnfOptPass::optimize(self : KnfOptPass, knf : @knf.Knf) -> @knf.Knf {
  match self {
    TailRecursion => @tail.transform_tail_recursion(knf)
    MayTailRecursion => @tail.transform_may_tail_recursion(knf)
    CopyPropagation => @copy.transform_copy_propagation(knf)
  }
}

pub fn ClosureOptPass::optimize(
  self : ClosureOptPass,
  _closure : @closure.Program
) -> @closure.Program {
  match self {
    _ => @util.die("unimplmented")
  }
}

pub fn SsaOptPass::optimize(self : SsaOptPass, method : @ssa.Method) -> Unit {
  match self {
    DeadCodeElimination => @dead.remove_ssa_dead_code(method)
    ConstProp => @const.mark_ssa_const_variable(method)
  }
}

pub fn MachineOptPass::optimize(
  self : MachineOptPass,
  method : @riscv.MachineMethod
) -> Unit {
  match self {

  }
}
