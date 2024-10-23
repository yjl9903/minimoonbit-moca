let knf_counter : Ref[Int] = Ref::new(0)

fn new_temp() -> Name {
  let name = Name::slot_only(knf_counter.val)
  knf_counter.val = knf_counter.val + 1
  name
}

fn new_named_temp(name : Name) -> Name {
  let name = Name::{ ..name, slot: knf_counter.val }
  knf_counter.val = knf_counter.val + 1
  name
}

fn transform_args(
  args : Array[(Name, @types.Type)],
  body : Knf
) -> (Array[(Name, @types.Type)], Knf) {
  let args = args.map(fn { a => (new_named_temp(a.0), a.0, a.1) })
  (
    args.map(fn { a => (a.0, a.2) }),
    args.rev_fold(
      fn { rest, (new_temp, arg, ty) => Let((arg, ty), Var(new_temp), rest) },
      init=body,
    ),
  )
}
