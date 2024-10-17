struct MethodBuilder {
  id : Int
  name : String
  ty : Type
  args : Array[(Name, Type)]
  /// main method has a special name
  old_name : Name

  /// Closure
  is_closure : Bool
  formal_free_vars : Array[(Name, Type)]

  /// World builder
  world_builder : WorldBuilder
}

fn MethodBuilder::new_main(world_builder : WorldBuilder) -> MethodBuilder {
  let name = "$main"
  {
    id: 0,
    name: "$main",
    old_name: Name::name_only(name),
    ty: DirectFn([], Unit),
    args: [],
    is_closure: false,
    formal_free_vars: [],
    world_builder,
  }
}

fn MethodBuilder::new(
  world_builder : WorldBuilder,
  def : @closure.FuncDef
) -> MethodBuilder {
  {
    id: def.id,
    name: def.name._,
    old_name: def.old_name,
    ty: def.ty,
    args: def.args,
    is_closure: def.is_closure,
    formal_free_vars: def.formal_free_vars,
    world_builder,
  }
}

fn MethodBuilder::build(self : MethodBuilder, expr : @closure.Expr) -> Method {
  abort("")
}
