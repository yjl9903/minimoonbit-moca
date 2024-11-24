fn Gamma::inherit_patterns(
  self : Gamma,
  expr_type : Type,
  pats : Array[(Pattern, @types.Syntax)]
) -> Type!TypeError {
  // println("\{expr_type} --- \{pats}")
  let mut expr_type = expr_type
  for i = 0; i < pats.length(); i = i + 1 {
    expr_type = self.inherit_pattern!(expr_type, pats[i].0)
  }
  // Typing unknown pattern vars
  for i = 0; i < pats.length(); i = i + 1 {
    let _ = self.inherit_pattern!(expr_type, pats[i].0)
    ()
  }
  if is_known_type(expr_type) {
    expr_type
  } else {
    raise TypeError("Unknown pattern matching: \{expr_type}")
  }
}

fn Gamma::inherit_pattern(
  self : Gamma,
  expr_type : Type,
  pattern : Pattern
) -> Type!TypeError {
  match (expr_type, pattern) {
    (Var({ val: None }), Var(_)) => expr_type
    (Var({ val: None }) | Unit, Unit) => Unit
    (Var({ val: None }) | Int, Int(_)) => Int
    (Var({ val: None }) | Bool, Bool(_)) => Bool
    (Var({ val: None }) | Double, Double(_)) => Double
    (Var({ val: None }), Tuple(pats)) => {
      let typs = []
      for i = 0; i < pats.length(); i = i + 1 {
        let el_type = self.inherit_pattern!(Var({ val: None }), pats[i])
        typs.push(el_type)
      }
      Tuple(typs)
    }
    (Var({ val: None }), Enum(name, kind, pats)) => {
      let kind = self.enums
        .find(name)
        .map(fn { def => def.get_kind(kind) })
        .flatten()
      match kind {
        Some(kind) =>
          if kind.fields.length() == pats.length() {
            for i = 0; i < pats.length(); i = i + 1 {
              let _ = self.inherit_pattern!(kind.fields[i], pats[i])
              ()
            }
            Enum(name)
          } else {
            raise TypeError("Pattern mismatch: unknown enum \{name}::\{kind}")
          }
        None =>
          raise TypeError("Pattern mismatch: unknown enum \{name}::\{kind}")
      }
    }
    (Var({ val: Some(t) }), _) => self.inherit_pattern!(t, pattern)

    // Unknown pattern
    (Unit, Var(_, Var(typ))) => {
      typ.val = Some(Unit)
      Unit
    }
    (Int, Var(_, Var(typ))) => {
      typ.val = Some(Int)
      Int
    }
    (Bool, Var(_, Var(typ))) => {
      typ.val = Some(Bool)
      Bool
    }
    (Double, Var(_, Var(typ))) => {
      typ.val = Some(Double)
      Double
    }
    (Tuple(els), Var(_, Var(typ))) => {
      typ.val = Some(Tuple(els))
      Tuple(els)
    }
    (Enum(t_name), Var(_, Var(typ))) => {
      typ.val = Some(Enum(t_name))
      Enum(t_name)
    }

    // Check pattern
    (Tuple(els), Tuple(pats)) =>
      if els.length() == pats.length() {
        let res = []
        for i = 0; i < els.length(); i = i + 1 {
          let typ = self.inherit_pattern!(els[i], pats[i])
          res.push(typ)
        }
        Tuple(res)
      } else {
        raise TypeError("Pattern mismatch: \{expr_type} in \{pattern}")
      }
    (Enum(t_name), Enum(p_name, p_kind, pats)) =>
      if t_name == p_name {
        let kind = self.enums
          .find(p_name)
          .map(fn { def => def.get_kind(p_kind) })
          .flatten()
        match kind {
          Some(kind) =>
            if kind.fields.length() == pats.length() {
              for i = 0; i < pats.length(); i = i + 1 {
                let _ = self.inherit_pattern!(kind.fields[i], pats[i])
                ()
              }
              Enum(p_name)
            } else {
              raise TypeError(
                "Pattern mismatch: unknown enum \{p_name}::\{kind}",
              )
            }
          None =>
            raise TypeError("Pattern mismatch: unknown enum \{p_name}::\{kind}")
        }
      } else {
        raise TypeError("Pattern mismatch: \{expr_type} in \{pattern}")
      }
    _ => raise TypeError("Pattern mismatch: \{expr_type} in \{pattern}")
  }
}
