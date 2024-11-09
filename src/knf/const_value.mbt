pub enum ConstValue {
  Int(Int)
  Double(Double)
} derive(Show, Eq, Hash)

let const_values : Map[Name, ConstValue] = Map::new()

pub fn set_const_value(name : Name, value : ConstValue) -> Unit {
  match const_values.get(name) {
    Some(exists) =>
      if exists != value {
        @util.die("\{name} is not a const (\{exists} -> \{value})")
      }
    None => const_values.set(name, value)
  }
}

pub fn remove_const_value(name : Name) -> Unit {
  const_values.remove(name)
}

pub fn clear_const_value() -> Unit {
  const_values.clear()
}

pub fn get_const_value(name : Name) -> ConstValue? {
  const_values.get(name)
}
