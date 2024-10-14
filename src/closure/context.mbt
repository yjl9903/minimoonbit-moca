struct Context {
  global : Map[Name, Type]
  free_vars : Map[Name, Type]
  local_vars : Map[Name, Type]
  program: Program
}

fn Context::new(externals: Map[String, Type]) -> Context {
  let global = Map::new()
  externals.each(
    fn {
      name, typ => {
        let binding = Name::name_only("minimbt_" + name)
        global.set(binding, typ)
      }
    },
  )
  let program = { fundefs: [], body: Unit }
  { global, free_vars: Map::new(), local_vars: Map::new(), program }
}
