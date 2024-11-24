/// Low-level types. Main difference between this and Type is that it distinguishes between direct function pointers and closure function pointers.
pub enum LowType {
  Unit
  Bool
  Int
  Double
  ClosureFn(Array[LowType], LowType) // (fn_ptr, closure_args...)
  DirectFn(Array[LowType], LowType) // fn_ptr itself
  Tuple(Array[LowType])
  Enum(@types.EnumDef)
  Array(LowType)
  Ptr
} derive(Eq)

pub fn LowType::output(self : LowType, logger : Logger) -> Unit {
  logger.write_string(self.to_string())
}

pub fn LowType::to_string(self : LowType) -> String {
  match self {
    Unit => "Unit"
    Bool => "Bool"
    Int => "Int"
    Double => "Double"
    ClosureFn(params, ret) => {
      let params = params.map(fn { p => p.to_string() }).join(", ")
      "(\{params}) -> \{ret.to_string()}"
    }
    DirectFn(params, ret) => {
      let params = params.map(fn { p => p.to_string() }).join(", ")
      "(\{params}) -> \{ret.to_string()}"
    }
    Tuple(els) => {
      let els = els.map(fn { p => p.to_string() }).join(", ")
      "(\{els})"
    }
    Enum(def) => "\{def.name}"
    Array(arr) => "Array[\{arr}]"
    Ptr => "Pointer"
  }
}

pub fn LowType::is_ptr_like(self : LowType) -> Bool {
  match self {
    ClosureFn(_) | DirectFn(_) | Tuple(_) | Array(_) | Ptr => true
    _ => false
  }
}

pub fn LowType::is_float_like(self : LowType) -> Bool {
  match self {
    Double => true
    _ => false
  }
}

pub fn LowType::size_of(self : LowType, size_of_ptr : Int) -> Int {
  match self {
    Unit => 0
    Bool => 4
    Int => 4
    Double => 8
    _ => if self.is_ptr_like() { size_of_ptr } else { 4 }
  }
}

// ---
pub fn extract_return_type(typ : LowType) -> LowType {
  match typ {
    DirectFn(_, ret) | ClosureFn(_, ret) => ret
    _ => @util.die("Type mismatch: should be Function type \{typ}")
  }
}

pub fn extract_tuple_type(ty : LowType) -> Array[LowType] {
  match ty {
    Tuple(els) => els
    _ => @util.die("unreachable")
  }
}

pub fn extract_array_type(ty : LowType) -> LowType {
  match ty {
    Array(el) => el
    _ => @util.die("unreachable")
  }
}

pub fn to_closure_fn_low_type(typ : Type) -> LowType {
  match typ {
    Unit => Unit
    Bool => Bool
    Int => Int
    Double => Double
    Ptr => Ptr
    Fun(args, ret) =>
      ClosureFn(
        args.map(fn { a => to_closure_fn_low_type(a) }),
        to_closure_fn_low_type(ret),
      )
    Tuple(els) => Tuple(els.map(fn { el => to_closure_fn_low_type(el) }))
    Enum(def) => Enum(@knf.enum_defs.get_def(def).unwrap())
    Array(arr) => Array(to_closure_fn_low_type(arr))
    Var({ val: Some(t) }) => to_closure_fn_low_type(t)
    Var({ val: None }) => @util.die("Unknown type \{typ}")
    Pi(_) | Param(_) | Identifier(_) => @util.die("Unknown type \{typ}")
  }
}

pub fn to_direct_fn_low_type(typ : Type) -> LowType {
  match typ {
    Unit => Unit
    Bool => Bool
    Int => Int
    Double => Double
    Ptr => Ptr
    Fun(args, ret) =>
      DirectFn(
        args.map(fn { a => to_closure_fn_low_type(a) }),
        to_closure_fn_low_type(ret),
      )
    Tuple(els) => Tuple(els.map(fn { el => to_closure_fn_low_type(el) }))
    Enum(def) => Enum(@knf.enum_defs.get_def(def).unwrap())
    Array(arr) => Array(to_closure_fn_low_type(arr))
    Var({ val: Some(t) }) => to_closure_fn_low_type(t)
    Var({ val: None }) => @util.die("Unknown type \{typ}")
    Pi(_) | Param(_) | Identifier(_) => @util.die("Unknown type \{typ}")
  }
}
