let global_world : Ref[World?] = { val: None }

fn World::set_world(world : World) -> Unit {
  global_world.val = Some(world)
}

pub fn World::get_world() -> World {
  global_world.val.unwrap()
}

pub struct World {
  // TODO: external
  global : Array[Var]
  methods : Map[Int, Method]
  main_method : Method
}
