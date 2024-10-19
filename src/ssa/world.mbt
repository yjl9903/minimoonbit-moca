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

pub fn World::print(self : World) -> Unit {
  self.global.each(
    fn {
      v => {
        println("let \{v} : \{v.ty};")
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
  let ret_type = @closure.extract_return_type(self.ty)
  println("fn \{self.name} (\{params}) -> \{ret_type} {")
  if self.formal_free_vars.length() > 0 {
    println("  closure {")
    self.formal_free_vars.each(
      fn { fv => println("    \{fv.to_string()} : \{fv.ty}") },
    )
    println("  }")
  }
  let pad_len = self.body.fold(
    fn { len, stmt => @math.maximum(len, stmt.slot.to_string().length()) },
    init=1,
  )
  self.body.each(
    fn {
      stmt => {
        let slot = "[\{stmt.slot}]"
        println("  \{slot.pad_start(pad_len + 2, ' ')} \{stmt.stmt}")
      }
    },
  )
  println("}")
}
