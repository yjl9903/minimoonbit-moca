struct Gamma {
  env : @hashmap.T[String, Type]
}

fn Gamma::new() -> Gamma {
  { env: @hashmap.new() }
}

fn Gamma::fork(self : Gamma) -> Gamma {
  let new_env = @hashmap.new()
  self.env.each(fn { k, v => new_env.set(k, v) })
  { env: new_env }
}

fn Gamma::add(self : Gamma, name : String, typ : Type) -> Unit {
  self.env.set(name, typ)
}

fn Gamma::find(self : Gamma, name : String) -> Type? {
  self.env.get(name)
}

fn is_having_type(typ : Type) -> Bool {
  match typ {
    Var(t) =>
      match t.val {
        Some(t) => true
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

// fn unwrap_type(typ : Type) -> Type? {
//   match typ {
//     Var(t) =>
//       match t.val {
//         Some(t) => unwrap_type(t)
//         None => None
//       }
//     _ => Some(typ)
//   }
// }
