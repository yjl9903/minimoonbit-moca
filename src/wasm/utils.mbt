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

fn get_type_size(ty : Type) -> Int {
  match ty {
    Double => 2
    _ => 1
  }
}

fn get_vars_type_size(vars : Array[@ssa.Var]) -> Int {
  vars.fold_left(fn { acc, var => acc + get_type_size(var.ty) }, init=0)
}
