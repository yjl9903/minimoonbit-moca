pub fn get_const_value(name : Name) -> RValue? {
  match name.name {
    Some(text) =>
      if text == @shared.one_binding_name {
        Some(Int(1))
      } else if text == @shared.zero_binding_name {
        Some(Int(0))
      } else {
        match @knf.get_const_value(name) {
          Some(Int(x)) => Some(Int(x))
          _ => None
        }
      }
    None => None
  }
}
