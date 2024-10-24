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
