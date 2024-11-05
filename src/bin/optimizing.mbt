typealias Pass = @optimizing.Pass

// typealias AstOptPass = @optimizing.AstOptPass

// typealias KnfOptPass = @optimizing.KnfOptPass

// typealias ClosureOptPass = @optimizing.ClosureOptPass

let optimizing_manager : @optimizing.Manager = @optimizing.new().add_opt_passes(
  [
    // Pass::Ast(ConstFold),
    // Pass::Ast(Liveness),
    Pass::Knf(CopyPropagation),
    Pass::Knf(TailRecursion),
    Pass::Knf(MayTailRecursion),
    Pass::Knf(MethodInline),
    Pass::Ssa(ConstProp),
    Pass::Ssa(DeadCodeElimination),
    Pass::Assembly(InstFold),
  ],
)
