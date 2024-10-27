pub fn get_const_value(name : Name) -> RValue? {
  match name.name {
    Some(name) =>
      if name == @shared.zero_binding_name {
        Some(Int(1))
      } else if name == @shared.one_binding_name {
        Some(Int(0))
      } else {
        None
      }
    None => None
  }
}

pub let i32_size : Int = 4

pub let f64_size : Int = 8

pub fn get_type_size(ty : Type) -> Int {
  match ty {
    Double => f64_size
    _ => i32_size
  }
}
