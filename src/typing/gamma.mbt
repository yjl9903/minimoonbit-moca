struct Gamma {
  mut env : @immut/hashmap.T[String, Type]
  mut type_env : @immut/hashset.T[String]
  mut enums : @immut/hashmap.T[String, @types.EnumDef]
}

fn Gamma::new(
  ~externals : @immut/hashmap.T[String, @types.Type] = @immut/hashmap.new()
) -> Gamma {
  {
    env: externals,
    type_env: @immut/hashset.new(),
    enums: @immut/hashmap.new(),
  }
}

fn Gamma::fork(self : Gamma) -> Gamma {
  { env: self.env, type_env: self.type_env, enums: self.enums }
}

fn Gamma::add(self : Gamma, name : String, typ : Type) -> Unit {
  self.env = @immut/hashmap.add(self.env, name, typ)
}

fn Gamma::find(self : Gamma, name : String) -> Type? {
  self.env.find(name)
}

fn Gamma::find_external(self : Gamma, name : String) -> Type? {
  self.env.find(name)
}

fn is_having_type(typ : Type) -> Bool {
  match typ {
    Var(t) =>
      match t.val {
        Some(_) => true
        None => false
      }
    _ => true
  }
}

fn is_known_type(typ : Type) -> Bool {
  match typ {
    Var(t) =>
      match t.val {
        Some(t) => is_known_type(t)
        None => false
      }
    Fun(args, ret) =>
      args.fold(fn { b, a => b && is_known_type(a) }, init=true) &&
      is_known_type(ret)
    Array(el) => is_known_type(el)
    Tuple(els) => els.fold(fn { b, a => b && is_known_type(a) }, init=true)
    _ => true
  }
}
