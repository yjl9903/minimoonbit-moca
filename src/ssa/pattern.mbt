fn MethodBuilder::visit_pattern_matching(
  self : MethodBuilder,
  expr : Name,
  patterns : Array[
    (@types.Pattern, Array[(Name, @closure.LowType)], @closure.Expr),
  ],
  cont : (RValue) -> Unit,
  ~visiting_loop : Bool = false
) -> Unit {

}
