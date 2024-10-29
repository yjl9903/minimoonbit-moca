let global_world : Ref[World?] = { val: None }

fn World::set_world(world : World) -> Unit {
  global_world.val = Some(world)
}

pub fn World::get_world() -> World {
  global_world.val.unwrap()
}

pub struct World {
  externals : Map[String, Type]
  global : Array[Var]
  methods : Map[String, Method]
  main_method : Method
}

pub fn get_method_type(self : World, label : String) -> Type? {
  match self.methods.get(label) {
    Some(m) => Some(m.ty)
    None =>
      match self.externals.get(label) {
        Some(mty) => Some(mty)
        None => None
      }
  }
}
