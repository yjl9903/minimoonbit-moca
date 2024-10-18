let global_world : Ref[World?] = { val: None }

fn World::set_world(world : World) -> Unit {
  global_world.val = Some(world)
}

pub fn World::get_world() -> World {
  global_world.val.unwrap()
}

pub struct World {
  // TODO: external
  global : @hashset.T[Var]
  methods : Map[Int, Method]
  main_method : Method
}

pub fn World::print(self : World) -> Unit {
  self.global.each(
    fn {
      v => {
        println("let \{v} : \{v.ty} = ?;")
        println("")
      }
    },
  )
  self.methods
  .values()
  .each(
    fn {
      method => {
        println("fn \{method.name}() {")
        println("}")
        println("")
      }
    },
  )
  let main_method = self.main_method
  println("fn \{main_method.name}() {")
  println("}")
}
