pub enum AstOptPass {
  ConstFold
  ConstProp
  Liveness
}

pub enum KnfOptPass {
  CopyPropagation
}

pub enum ClosureOptPass {}

pub enum SsaOptPass {}

pub enum Pass {
  Ast(AstOptPass)
  Knf(KnfOptPass)
  Closure(ClosureOptPass)
  Ssa(SsaOptPass)
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

pub fn KnfOptPass::optimize(self : KnfOptPass, _knf : @knf.Knf) -> @knf.Knf {
  match self {
    CopyPropagation => @util.die("unimplmented")
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
