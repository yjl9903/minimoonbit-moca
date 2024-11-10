pub fn unify(lhs : Type, rhs : Type) -> Type!TypeError {
  match (lhs, rhs) {
    (_, Var({ val: Some(rhs) })) => unify!(lhs, rhs)
    (Var({ val: Some(lhs) }), rhs) => unify!(lhs, rhs)

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
          args.push(unify!(l_arg, r_arg))
        }
        Fun(args, unify!(l_ret, r_ret))
      } else {
        raise TypeError("Unify mismatch: \{lhs} - \{rhs}")
      }
    (Tuple(l_els), Tuple(r_els)) =>
      if l_els.length() == r_els.length() {
        let els : Array[Type] = Array::new(capacity=l_els.length())
        for i = 0; i < l_els.length(); i = i + 1 {
          let l_el = l_els[i]
          let r_el = r_els[i]
          els.push(unify!(l_el, r_el))
        }
        Tuple(els)
      } else {
        raise TypeError("Unify mismatch: \{lhs} - \{rhs}")
      }
    (Array(lhs), Array(rhs)) => Array(unify!(lhs, rhs))

    // Unify literal
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
    (Array(_) as base, Var({ val: None } as ref))
    | (Var({ val: None } as ref), Array(_) as base) => {
      ref.val = Some(base)
      base
    }

    // Unknown: TODO some type should be equal
    (Var({ val: None }), Var({ val: None })) => Var({ val: None })

    // Error
    _ => raise TypeError("Unify mismatch: \{lhs} - \{rhs}")
  }
}
