pub enum AstOptPass {
  ConstFold
  ConstProp
  Liveness
}

pub enum KnfOptPass {
  ConstProp
  CopyPropagation
  TailRecursion
  MayTailRecursion
  MethodInline
}

pub enum ClosureOptPass {}

pub enum SsaOptPass {
  DeadCodeElimination
  ConstProp
}

pub enum MachineOptPass {}

pub enum AssemblyOptPass {
  InstFold
}

pub enum Pass {
  Ast(AstOptPass)
  Knf(KnfOptPass)
  Closure(ClosureOptPass)
  Ssa(SsaOptPass)
  Machine(MachineOptPass)
  Assembly(AssemblyOptPass)
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
    ConstProp => @const.transform_knf_const_prop(knf)
    TailRecursion => @tail.transform_tail_recursion(knf)
    MayTailRecursion => @tail.transform_may_tail_recursion(knf)
    CopyPropagation => @copy.transform_copy_propagation(knf)
    MethodInline => @inline.transform_method_inline(knf)
  }
}

pub fn ClosureOptPass::optimize(
  _self : ClosureOptPass,
  closure : @closure.Program
) -> @closure.Program {
  closure
}

pub fn SsaOptPass::optimize(self : SsaOptPass, method : @ssa.Method) -> Unit {
  match self {
    DeadCodeElimination => ()
    ConstProp => @const.mark_ssa_const_variable(method)
  }
}

pub fn SsaOptPass::optimize_world(
  self : SsaOptPass,
  world : @ssa.World
) -> Unit {
  match self {
    DeadCodeElimination => @dead.remove_ssa_dead_code(world)
    ConstProp => ()
  }
}

pub fn MachineOptPass::optimize(
  _self : MachineOptPass,
  _method : @riscv.MachineMethod
) -> Unit {
  ()
}

pub fn AssemblyOptPass::optimize(
  self : AssemblyOptPass,
  method : @riscv.AssemblyFunction
) -> Unit {
  match self {
    InstFold => @inst.transform_inst_fold(method)
  }
}
