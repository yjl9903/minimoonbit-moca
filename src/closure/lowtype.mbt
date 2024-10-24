/// Low-level types. Main difference between this and Type is that it distinguishes between direct function pointers and closure function pointers.
pub enum LowType {
  Unit
  Bool
  Int
  Double
  ClosureFn(Array[LowType], LowType) // (fn_ptr, closure_args...)
  DirectFn(Array[LowType], LowType) // fn_ptr itself
  Tuple(Array[LowType])
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
    Array(arr) => Array(to_closure_fn_low_type(arr))
    Var({ val: Some(t) }) => to_closure_fn_low_type(t)
    Var({ val: None }) => @util.die("Unknown type \{typ}")
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
        args.map(fn { a => to_direct_fn_low_type(a) }),
        to_direct_fn_low_type(ret),
      )
    Tuple(els) => Tuple(els.map(fn { el => to_direct_fn_low_type(el) }))
    Array(arr) => Array(to_direct_fn_low_type(arr))
    Var({ val: Some(t) }) => to_direct_fn_low_type(t)
    Var({ val: None }) => @util.die("Unknown type \{typ}")
  }
}

fn unify(lhs : LowType, rhs : LowType) -> LowType {
  match (lhs, rhs) {
    (Unit, Unit) => Unit
    (Bool, Bool) => Bool
    (Int, Int) => Int
    (Double, Double) => Double
    (Ptr, Ptr) => Ptr
    (Array(lhs), Array(rhs)) => unify(lhs, rhs)
    (Tuple(lhs), Tuple(rhs)) =>
      if lhs.length() == rhs.length() {
        Tuple(lhs.mapi(fn { i, _ => unify(lhs[i], rhs[i]) }))
      } else {
        @util.die("Type mismatch: different tuple length \{lhs} - \{rhs}")
      }
    (
      DirectFn(l_args, l_ret) | ClosureFn(l_args, l_ret),
      DirectFn(r_args, r_ret) | ClosureFn(r_args, r_ret),
    ) =>
      if l_args.length() == r_args.length() {
        let args = l_args.mapi(fn { i, _ => unify(l_args[i], r_args[i]) })
        let ret = unify(l_ret, r_ret)
        match (lhs, rhs) {
          (DirectFn(_), DirectFn(_)) => DirectFn(args, ret)
          _ => ClosureFn(args, ret)
        }
      } else {
        @util.die("Type mismatch: different args length \{lhs} - \{rhs}")
      }
    _ => @util.die("Type mismatch: should be typechecked")
  }
}
