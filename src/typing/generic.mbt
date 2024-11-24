fn Gamma::mark_type_params(
  self : Gamma,
  params : Map[String, Int],
  typ : Type
) -> Type {
  match typ {
    Unit | Int | Bool | Double | Var({ val: None }) => typ
    Var({ val: Some(typ) }) => self.mark_type_params(params, typ)
    Identifier(name) =>
      match params.get(name) {
        Some(id) => Param(name, id)
        None =>
          match self.enums.find(name) {
            Some(_) => Enum(name)
            _ => @util.die("Unknown type variable")
          }
      }
    Tuple(els) => Tuple(els.map(fn { el => self.mark_type_params(params, el) }))
    Array(base) => Array(self.mark_type_params(params, base))
    Fun(targs, tret) =>
      Fun(
        targs.map(fn { el => self.mark_type_params(params, el) }),
        self.mark_type_params(params, tret),
      )
    Enum(_) | Param(_) | Ptr => typ
    Pi(_) => @util.die("Unknown Pi type")
  }
}

fn replace_generic(env : Map[Int, Type], typ : Type) -> Type!TypeError {
  match typ {
    Var({ val: None }) => typ
    Var({ val: Some(typ) }) => replace_generic!(env, typ)
    Unit | Int | Bool | Double => typ
    Fun(args, ret) => {
      let res = []
      for i = 0; i < args.length(); i = i + 1 {
        res.push(replace_generic!(env, args[i]))
      }
      Fun(res, replace_generic!(env, ret))
    }
    Tuple(els) => {
      let res = []
      for i = 0; i < els.length(); i = i + 1 {
        res.push(replace_generic!(env, els[i]))
      }
      Tuple(res)
    }
    Array(base) => Array(replace_generic!(env, base))
    Enum(_) | Ptr => typ
    Param(_, id) =>
      match env.get(id) {
        Some(t) => t
        None => typ
      }
    Identifier(_) | Pi(_) => @util.die("not support here")
  }
}

fn unify_with_generic(
  env : Map[Int, Type],
  lhs : Type,
  rhs : Type
) -> Type!TypeError {
  match (lhs, rhs) {
    (_, Var({ val: Some(rhs) })) => unify_with_generic!(env, lhs, rhs)
    (Var({ val: Some(lhs) }), rhs) => unify_with_generic!(env, lhs, rhs)

    // Determined
    (Unit, Unit) => Unit
    (Bool, Bool) => Bool
    (Int, Int) => Int
    (Double, Double) => Double
    (Fun(l_args, l_ret), Fun(r_args, r_ret)) =>
      if l_args.length() == r_args.length() {
        let args : Array[Type] = Array::new(capacity=l_args.length())
        for i = 0; i < l_args.length(); i = i + 1 {
          let l_arg = l_args[i]
          let r_arg = r_args[i]
          args.push(unify_with_generic!(env, l_arg, r_arg))
        }
        Fun(args, unify_with_generic!(env, l_ret, r_ret))
      } else {
        raise TypeError("Unify generic mismatch: \{lhs} - \{rhs}")
      }
    (Tuple(l_els), Tuple(r_els)) =>
      if l_els.length() == r_els.length() {
        let els : Array[Type] = Array::new(capacity=l_els.length())
        for i = 0; i < l_els.length(); i = i + 1 {
          let l_el = l_els[i]
          let r_el = r_els[i]
          els.push(unify_with_generic!(env, l_el, r_el))
        }
        Tuple(els)
      } else {
        raise TypeError("Unify generic mismatch: \{lhs} - \{rhs}")
      }
    (Enum(l_enum), Enum(r_enum)) =>
      if l_enum == r_enum {
        Enum(l_enum)
      } else {
        raise TypeError("Unify generic mismatch: \{lhs} - \{rhs}")
      }
    (Enum(l_enum), Identifier(r_id)) =>
      if l_enum == r_id {
        Enum(l_enum)
      } else {
        raise TypeError("Unify generic mismatch: \{lhs} - \{rhs}")
      }
    (Identifier(l_id), Enum(r_enum)) =>
      if l_id == r_enum {
        Enum(r_enum)
      } else {
        raise TypeError("Unify generic mismatch: \{lhs} - \{rhs}")
      }
    (Array(lhs), Array(rhs)) => Array(unify_with_generic!(env, lhs, rhs))

    // Unify literal
    (Unit | Int | Bool | Double as base, Param(_, id)) => {
      match env.get(id) {
        Some(typ) => env.set(id, unify!(typ, base))
        None => env.set(id, base)
      }
      base
    }

    //
    (Unit, Var({ val: None } as ref)) | (Var({ val: None } as ref), Unit) => {
      ref.val = Some(Unit)
      Unit
    }
    (Int, Var({ val: None } as ref)) | (Var({ val: None } as ref), Int) => {
      ref.val = Some(Int)
      Int
    }
    (Bool, Var({ val: None } as ref)) | (Var({ val: None } as ref), Bool) => {
      ref.val = Some(Bool)
      Bool
    }
    (Double, Var({ val: None } as ref)) | (Var({ val: None } as ref), Double) => {
      ref.val = Some(Double)
      Double
    }

    // Unify composed
    (Fun(_) | Tuple(_) | Enum(_) | Array(_) as base, Param(_, id)) => {
      match env.get(id) {
        Some(typ) => env.set(id, unify!(typ, base))
        None => env.set(id, base)
      }
      base
    }

    //
    (Fun(_) as base, Var({ val: None } as ref))
    | (Var({ val: None } as ref), Fun(_) as base) => {
      ref.val = Some(base)
      base
    }
    (Tuple(_) as base, Var({ val: None } as ref))
    | (Var({ val: None } as ref), Tuple(_) as base) => {
      ref.val = Some(base)
      base
    }
    (Enum(_) as base, Var({ val: None } as ref))
    | (Var({ val: None } as ref), Enum(_) as base) => {
      ref.val = Some(base)
      base
    }
    (Array(_) as base, Var({ val: None } as ref))
    | (Var({ val: None } as ref), Array(_) as base) => {
      ref.val = Some(base)
      base
    }

    // Unknown: TODO some type should be equal
    (Var({ val: None }), Var({ val: None })) => Var({ val: None })

    // Error
    _ => raise TypeError("Unify generic mismatch: \{lhs} - \{rhs}")
  }
}
