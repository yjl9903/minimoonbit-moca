pub enum AstOptPass {
  ConstFold
  ConstProp
  Liveness
}

pub enum KnfOptPass {
  ConstProp
  CopyPropagation
  Liveness
  TailRecursion
  MayTailRecursion
  MethodInline
}

pub enum ClosureOptPass {
  MethodInline
}

pub enum SsaOptPass {
  DeadCodeElimination
  ConstProp
}

pub enum MachineOptPass {
  CommonSubExpr
  CopyPropagation
}

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
    CopyPropagation => @copy.transform_copy_propagation(knf)
    Liveness => @liveness.transform_knf_liveness(knf)
    TailRecursion => @tail.transform_tail_recursion(knf)
    MayTailRecursion => @tail.transform_may_tail_recursion(knf)
    MethodInline => @inline.transform_knf_method_inline(knf)
  }
}

pub fn ClosureOptPass::optimize(
  self : ClosureOptPass,
  closure : @closure.Program
) -> @closure.Program {
  match self {
    MethodInline => @inline.transform_closure_method_inline(closure)
  }
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
  self : MachineOptPass,
  method : @riscv.MachineMethod
) -> Unit {
  match self {
    CommonSubExpr => @expr.transform_global_common_sub_expr(method)
    CopyPropagation => @definition.transform_copy_propagation(method)
  }
}

pub fn AssemblyOptPass::optimize(
  self : AssemblyOptPass,
  method : @riscv.AssemblyFunction
) -> Unit {
  match self {
    InstFold => @inst.transform_inst_fold(method)
  }
}
