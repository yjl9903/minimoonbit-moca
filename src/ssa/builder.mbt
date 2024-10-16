struct WorldBuilder {
  global : Set[Var]
}

pub fn WorldBuilder::new() -> WorldBuilder {
  WorldBuilder::{ global: Set::new() }
}

pub fn WorldBuilder::build(
  self : WorldBuilder,
  prog : @closure.Program
) -> World {
  let main_method = self.build_top_level(prog.body)
  let methods = prog.fundefs.map(fn { def => (def.id, self.build_method(def)) })
  let world : World = {
    global: self.global,
    methods: Map::from_array(methods),
    main_method,
  }
  set_world(world)
  world
}

fn WorldBuilder::build_top_level(
  self : WorldBuilder,
  prog : @closure.Expr
) -> Method {
  abort("todo")
}

fn WorldBuilder::build_method(
  self : WorldBuilder,
  def : @closure.FuncDef
) -> Method {
  abort("")
}
