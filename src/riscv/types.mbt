pub enum Width {
  Int
  Double
  Ptr
} derive(Show, Eq, Hash)

pub fn Width::from_prim_kind(kind : @ssa.PrimKind) -> Width {
  match kind {
    Int => Int
    Double => Double
  }
}

pub fn Width::from_low_type(ty : Type) -> Width {
  match ty {
    Unit | Bool | Int => Int
    Double => Double
    ClosureFn(_) | DirectFn(_) | Tuple(_) | Array(_) | Ptr => Ptr
  }
}

pub fn Width::is_float(self : Width) -> Bool {
  match self {
    Int => false
    Double => true
    Ptr => false
  }
}

pub fn Width::to_int(self : Width) -> Int {
  match self {
    Int => int_size
    Double => double_size
    Ptr => ptr_size
  }
}

pub let int_size : Int = 4

pub let label_size : Int = 8

pub let ptr_size : Int = 8

pub let double_size : Int = 8

pub fn get_type_size(ty : Type) -> Int {
  Width::from_low_type(ty).to_int()
}

pub fn get_tuple_types_size(
  vars : Array[@ssa.Var],
  ~slice : Int? = None
) -> Int {
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
  fvs : Array[@ssa.FreeVar],
  ~target : @ssa.FreeVar? = None
) -> Int {
  match target {
    Some(target) =>
      fvs.fold(
        fn {
          acc, fv =>
            acc + (if fv.slot < target.slot { get_type_size(fv.ty) } else { 0 })
        },
        init=label_size,
      )
    None =>
      fvs.fold(fn { acc, fv => acc + get_type_size(fv.ty) }, init=label_size)
  }
}
