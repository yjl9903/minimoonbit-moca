fn transform_args(
  args : Array[(Name, @types.Type)],
  body : Knf
) -> (Array[(Name, @types.Type)], Knf) {
  let args = args.map(
    fn {
      (name, ty) =>
        (
          name.name.map_or_else(
            fn() { @knf.new_temp() },
            fn { n => @knf.new_named_temp(n) },
          ),
          name,
          ty,
        )
    },
  )
  (
    args.map(fn { a => (a.0, a.2) }),
    args.rev_fold(
      fn { rest, (new_temp, arg, ty) => Let((arg, ty), Var(new_temp), rest) },
      init=body,
    ),
  )
}
