fn get_method_name(name : String) -> String {
  name.replace_all(old="/", new="_")
}

fn add_method_this_type(method : @ssa.Method) -> Type {
  match method.ty {
    ClosureFn(args, ret) | DirectFn(args, ret) => {
      let new_args = [Type::Ptr]
      new_args.push_iter(args.iter())
      Type::ClosureFn(new_args, ret)
    }
    _ => @util.die("should be function type")
  }
}

fn add_func_type_this_type(ty : Type) -> Type {
  match ty {
    ClosureFn(args, ret) | DirectFn(args, ret) => {
      let new_args = [Type::Ptr]
      new_args.push_iter(args.iter())
      Type::ClosureFn(new_args, ret)
    }
    _ => @util.die("should be function type")
  }
}

pub let i32_size : Int = 4

pub let f64_size : Int = 8

fn get_type_size(ty : Type) -> Int {
  match ty {
    Double => f64_size
    _ => i32_size
  }
}

fn get_vars_type_size(vars : Array[@ssa.Var], ~slice : Int? = None) -> Int {
  (match slice {
    Some(slice) => vars.iter().take(slice)
    None => vars.iter()
  }).fold(fn { acc, var => acc + get_type_size(var.ty) }, init=0)
}

fn get_types_type_size(vars : Array[Type], ~slice : Int? = None) -> Int {
  (match slice {
    Some(slice) => vars.iter().take(slice)
    None => vars.iter()
  }).fold(fn { acc, var => acc + get_type_size(var) }, init=0)
}

fn get_closure_size(
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
        init=i32_size,
      )
    None =>
      fvs.fold(fn { acc, fv => acc + get_type_size(fv.ty) }, init=i32_size)
  }
}

fn extract_tuple_type(ty : Type) -> Array[Type] {
  match ty {
    Tuple(els) => els
    _ => @util.die("unreachable")
  }
}

fn extract_array_type(ty : Type) -> Type {
  match ty {
    Array(el) => el
    _ => @util.die("unreachable")
  }
}
