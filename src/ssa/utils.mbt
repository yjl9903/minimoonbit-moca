pub fn get_const_value(name : Name) -> RValue? {
  match name.name {
    Some(name) =>
      if name == @shared.one_binding_name {
        Some(Int(1))
      } else if name == @shared.zero_binding_name {
        Some(Int(0))
      } else {
        None
      }
    None => None
  }
}
