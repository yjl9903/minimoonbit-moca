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

pub fn get_tuple_types_size(vars : Array[Var], ~slice : Int? = None) -> Int {
  (match slice {
    Some(slice) => vars.iter().take(slice)
    None => vars.iter()
  }).fold(fn { acc, var => acc + get_type_size(var.ty) }, init=0)
}

pub fn get_tuple_size(vars : Array[Type], ~slice : Int? = None) -> Int {
  (match slice {
    Some(slice) => vars.iter().take(slice)
    None => vars.iter()
  }).fold(fn { acc, var => acc + get_type_size(var) }, init=0)
}

pub fn get_free_vars_size(
  fvs : Array[FreeVar],
  ~target : FreeVar? = None
) -> Int {
  match target {
    Some(target) =>
      fvs.fold(
        fn {
          acc, fv =>
            acc + (if fv.slot < target.slot { get_type_size(fv.ty) } else { 0 })
        },
        init=i32_size,
      )
    None =>
      fvs.fold(fn { acc, fv => acc + get_type_size(fv.ty) }, init=i32_size)
  }
}
