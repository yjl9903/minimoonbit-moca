let global_world : Ref[World?] = { val: None }

pub fn World::get_world() -> World {
  global_world.val.unwrap()
}

pub struct World {
  methods : Map[String, Method]
  main_method : Method
}
