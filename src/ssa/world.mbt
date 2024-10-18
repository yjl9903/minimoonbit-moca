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
        method.print()
        println("")
      }
    },
  )
  let main_method = self.main_method
  main_method.print()
}

pub fn Method::print(self : Method) -> Unit {
  let params = self.params
    .map(fn { p => "\{p.to_string()} : \{p.ty}" })
    .join(", ")
  // TODO: typing error
  // let ret = self.ty
  println("fn \{self.name}(\{params}) -> ? {")
  self.body.each(fn { stmt => println("  [\{stmt.slot}] \{stmt.stmt}") })
  println("}")
}
