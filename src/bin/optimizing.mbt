typealias Pass = @optimizing.Pass

// typealias AstOptPass = @optimizing.AstOptPass

// typealias KnfOptPass = @optimizing.KnfOptPass

// typealias ClosureOptPass = @optimizing.ClosureOptPass

fn get_optimizing_manager(backend : Backends) -> @optimizing.Manager {
  let optimizing_manager : @optimizing.Manager = @optimizing.new().add_opt_passes(
    [
      // Pass::Ast(ConstFold),
      // Pass::Ast(Liveness),
      Pass::Knf(ConstProp),
      Pass::Knf(CopyPropagation),
      Pass::Knf(TailRecursion),
      Pass::Knf(MayTailRecursion),
      Pass::Knf(ConstProp),
      Pass::Ssa(ConstProp),
      Pass::Ssa(DeadCodeElimination),
      Pass::Assembly(InstFold),
    ],
  )
  if backend == RSICV {
    optimizing_manager.add_opt_pass(Pass::Knf(MethodInline))
  } else {
    optimizing_manager
  }
}
