pub fn type_check(
  syntax : @types.Syntax,
  externals : @immut/hashmap.T[String, @types.Type]
) -> @types.Syntax {
  let gamma = Gamma::new(~externals)
  match gamma.inherit?(syntax, Type::Unit) {
    Ok(_) => syntax
    Err(TypeError(e)) => @util.die(e)
  }
}

fn Gamma::inherit(
  self : Gamma,
  syntax : @types.Syntax,
  expected : Type
) -> Unit!TypeError {
  match syntax {
    // Literal
    Unit | Bool(_) | Int(_) | Double(_) => {
      let synthed = self.synthesis!(syntax)
      let _ = unify!(synthed, expected)
      ()
    }

    // Binding
    Var(_) => {
      let synthed = self.synthesis!(syntax)
      let _ = unify!(synthed, expected)
      ()
    }
    Tuple(els) =>
      match expected {
        Tuple(expected) | Var({ val: Some(Tuple(expected)) }) =>
          if els.length() == expected.length() {
            let n = els.length()
            for i = 0; i < n; i = i + 1 {
              let el = els[i]
              let expected = expected[i]
              self.inherit!(el, expected)
            }
          } else {
            raise TypeError("Type mismatch: tuple length \{syntax}")
          }
        _ => raise TypeError("Type mismatch: should be tuple \{syntax}")
      }
    Array(n, el) => {
      self.inherit!(n, Type::Int)
      match expected {
        Array(expected) | Var({ val: Some(Array(expected)) }) =>
          self.inherit!(el, expected)
        _ => raise TypeError("Type mismatch: should be array \{syntax}")
      }
    }

    // Operation
    Not(expr) =>
      match expected {
        Bool | Var({ val: Some(Bool) }) => self.inherit!(expr, Type::Bool)
        _ => raise TypeError("Type mismatch: should be bool")
      }
    Neg(expr, ..) as neg =>
      match expected {
        Int | Var({ val: Some(Int) }) => {
          neg.kind = Some(Kind::Int)
          self.inherit!(expr, Type::Int)
        }
        Double | Var({ val: Some(Double) }) => {
          neg.kind = Some(Kind::Double)
          self.inherit!(expr, Type::Double)
        }
        _ => raise TypeError("Type mismatch: should be numeric")
      }
    Prim(lhs, rhs, _, ..) as prim =>
      match expected {
        Int | Var({ val: Some(Int) }) => {
          prim.kind = Some(Kind::Int)
          self.inherit!(lhs, Type::Int)
          self.inherit!(rhs, Type::Int)
        }
        Double | Var({ val: Some(Double) }) => {
          prim.kind = Some(Kind::Double)
          self.inherit!(lhs, Type::Double)
          self.inherit!(rhs, Type::Double)
        }
        Var({ val: None } as vt) => {
          let lhs_typ = self.synthesis!(lhs)
          let rhs_typ = self.synthesis!(rhs)
          match unify!(lhs_typ, rhs_typ) {
            Int => {
              vt.val = Some(Int)
              prim.kind = Some(Kind::Int)
              self.inherit!(lhs, Type::Int)
              self.inherit!(rhs, Type::Int)
            }
            Double => {
              vt.val = Some(Double)
              prim.kind = Some(Kind::Double)
              self.inherit!(lhs, Type::Double)
              self.inherit!(rhs, Type::Double)
            }
            _ => raise TypeError("Type mismatch: should be numeric")
          }
        }
        _ => raise TypeError("Type mismatch: should be numeric")
      }
    Eq(lhs, rhs) | LE(lhs, rhs) =>
      match expected {
        Bool | Var({ val: Some(Bool) }) => {
          let lhs_typ = self.synthesis!(lhs)
          let rhs_typ = self.synthesis!(rhs)
          let unified = unify!(lhs_typ, rhs_typ)
          match unified {
            Int | Bool | Double | Var({ val: Some(Int | Bool | Double) }) => ()
            _ =>
              raise TypeError(
                "Type mismatch: should be Int, Bool, Double, \{syntax}",
              )
          }
        }
        _ => raise TypeError("Type mismatch: should be Bool, \{syntax}")
      }
    App(sig, args) => {
      let synthed_sig = self.synthesis!(sig)
      match synthed_sig {
        Fun(targs, tret) | Var({ val: Some(Fun(targs, tret)) }) =>
          if targs.length() == args.length() {
            for i = 0; i < targs.length(); i = i + 1 {
              self.inherit!(args[i], targs[i])
            }
            let _ = unify!(tret, expected)
            ()
          } else {
            raise TypeError(
              "Type mismatch: different args length \{synthed_sig}",
            )
          }
        Var({ val: None } as ref) => {
          let targs : Array[Type] = Array::new()
          for i = 0; i < args.length(); i = i + 1 {
            let synthed = self.synthesis!(args[i])
            targs.push(synthed)
          }
          let typ = Type::Fun(targs, expected)
          ref.val = Some(typ)
          self.inherit!(sig, typ)
        }
        _ => raise TypeError("Type mismatch: \{sig} : \{synthed_sig}")
      }
    }

    // Branch
    If(cond, true_branch, false_branch) => {
      self.inherit!(cond, Type::Bool)
      self.inherit!(true_branch, expected)
      self.inherit!(false_branch, expected)
    }

    // Array
    Get(recv, idx) => {
      self.inherit!(recv, Type::Array(expected))
      self.inherit!(idx, Type::Int)
    }
    Put(_) =>
      match expected {
        Unit | Var({ val: Some(Unit) }) => {
          let _ = self.synthesis!(syntax)
          ()
        }
        _ =>
          raise TypeError(
            "Type mismatch: should be Unit, find \{expected}, \{syntax}",
          )
      }

    // Let
    Let(binding, expr, rest) => {
      self.inherit_let!(binding, expr)
      self.inherit!(rest, expected)
    }
    LetRec(def, rest) => {
      self.inherit_let_rec!(def)
      self.inherit!(rest, expected)
    }
    LetTuple(els, expr, rest) => {
      self.inherit_let_tuple!(els, expr)
      self.inherit!(rest, expected)
    }
  }
}

fn Gamma::inherit_let(
  self : Gamma,
  binding : (String, Type),
  expr : @types.Syntax
) -> Unit!TypeError {
  let (name, typ) = binding
  if is_having_type(typ) {
    // Annotated with type, check it
    if not(is_known_type(typ)) {
      raise TypeError("Unknown type \{typ}")
    }
    self.inherit!(expr, typ)
  } else {
    // Infer type from expr
    let synthed = self.synthesis!(expr)
    match typ {
      Var(typ) => typ.val = Some(synthed)
      _ => ()
    }
  }
  self.add(name, typ)
}

fn Gamma::inherit_let_rec(self : Gamma, def : @types.Fundef) -> Unit!TypeError {
  if is_having_type(def.name.1) {
    // Annotated with type, check it
    match def.name.1 {
      Fun(t_args, t_ret) | Var({ val: Some(Fun(t_args, t_ret)) }) => {
        self.add(def.name.0, def.name.1)
        let new_env = self.fork()
        // Check args
        if def.args.length() == t_args.length() {
          let n = def.args.length()
          for i = 0; i < n; i = i + 1 {
            let arg = def.args[i]
            let typ = t_args[i]
            if arg.1 != typ {
              raise TypeError(
                "Type mismatch: different arg type \{arg.1}, expected \{typ}",
              )
            } else {
              new_env.add(arg.0, arg.1)
            }
          }
        } else {
          raise TypeError(
            "Type mismatch: args length \{def.args}, expected \{t_args}",
          )
        }
        if is_having_type(t_ret) {
          // Check ret
          new_env.inherit!(def.body, t_ret)
        } else {
          let synthed = new_env.synthesis!(def.body)
          new_env.inherit!(def.body, synthed)
        }
      }
      _ =>
        raise TypeError(
          "Type mismatch: should be function \{def} : \{def.name.1}",
        )
    }
  } else {
    match def.name.1 {
      Var(vt) =>
        vt.val = Some(
          Fun(def.args.map(fn { (_, t) => t }), Type::Var(Ref::new(None))),
        )
      _ => @util.die("unreachable")
    }
    self.add(def.name.0, def.name.1)
    let new_env = self.fork()
    def.args.each(fn { (name, typ) => new_env.add(name, typ) })
    let synthed = new_env.synthesis!(def.body)
    new_env.inherit!(def.body, synthed)
  }
}

fn Gamma::inherit_let_tuple(
  self : Gamma,
  els : Array[(String, Type)],
  expr : @types.Syntax
) -> Unit!TypeError {
  let synthed_tuple = self.synthesis!(expr)
  match synthed_tuple {
    Tuple(synthed_els) | Var({ val: Some(Tuple(synthed_els)) }) =>
      if els.length() == synthed_els.length() {
        for i = 0; i < els.length(); i = i + 1 {
          let unified = unify!(els[i].1, synthed_els[i])
          self.add(els[i].0, unified)
        }
      } else {
        raise TypeError("Type mismatch: different tuple length")
      }
    _ => raise TypeError("Type mismatch: should be Tuple")
  }
}

fn Gamma::synthesis(self : Gamma, syntax : @types.Syntax) -> Type!TypeError {
  match syntax {
    // Literal
    Unit => Type::Unit
    Bool(_) => Type::Bool
    Int(_) => Type::Int
    Double(_) => Type::Double

    // Binding
    Var(name) =>
      match self.find(name) {
        Some(typ) => typ
        None =>
          // TODO: check should fallback to external
          match self.find_external(name) {
            Some(typ) => typ
            None => raise TypeError("Unknown identifier \{name}")
          }
      }
    Tuple(els) => {
      let types = els.map(fn { e => self.synthesis?(e) })
      let type_error = types.search_by(fn { t => t.is_err() })
      let types = match type_error {
        Some(i) =>
          match types[i] {
            Ok(_) => raise TypeError("Unknown")
            Err(e) => raise e
          }
        None => types.map(fn { t => t.unwrap() })
      }
      Type::Tuple(types)
    }
    Array(n, el) => {
      self.inherit!(n, Type::Int)
      Type::Array(self.synthesis!(el))
    }

    // Operation
    Not(expr) => {
      self.inherit!(expr, Type::Bool)
      Type::Bool
    }
    Neg(expr, ..) as neg =>
      match self.synthesis?(expr) {
        Ok(Int) | Ok(Var({ val: Some(Int) })) => {
          neg.kind = Some(Kind::Int)
          Type::Int
        }
        Ok(Double) | Ok(Var({ val: Some(Double) })) => {
          neg.kind = Some(Kind::Double)
          Type::Double
        }
        Ok(Var({ val: None }) as nt) => nt
        _ => raise TypeError("Type mismatch: should be numeric")
      }
    Prim(lhs, rhs, _, ..) as prim =>
      match unify!(self.synthesis!(lhs), self.synthesis!(rhs)) {
        Int => {
          prim.kind = Some(Kind::Int)
          Int
        }
        Double => {
          prim.kind = Some(Kind::Double)
          Double
        }
        Var({ val: None }) as vt => vt
        _ => raise TypeError("Type mismatch: should be Int, Double")
      }
    Eq(lhs, rhs) | LE(lhs, rhs) =>
      match unify!(self.synthesis!(lhs), self.synthesis!(rhs)) {
        Int | Double | Bool => Bool
        _ => raise TypeError("Type mismatch: should be Int, Bool, Double")
      }
    App(sig, args) => {
      let tsig = self.synthesis!(sig)
      match tsig {
        Fun(targs, tret) | Var({ val: Some(Fun(targs, tret)) }) => {
          for i = 0; i < targs.length(); i = i + 1 {
            self.inherit!(args[i], targs[i])
          }
          tret
        }
        Var({ val: None } as at) => {
          let targs : Array[Type] = Array::new(capacity=args.length())
          for i = 0; i < args.length(); i = i + 1 {
            let argt = self.synthesis!(args[i])
            targs.push(argt)
          }
          let syn = Type::Fun(targs, Type::Var({ val: None }))
          at.val = Some(syn)
          syn
        }
        _ => raise TypeError("Type mismatch: should be function type \{tsig}")
      }
    }

    // Branch
    If(cond, true_branch, false_branch) => {
      self.inherit!(cond, Type::Bool)
      let true_type = self.synthesis!(true_branch)
      let false_type = self.synthesis!(false_branch)
      unify!(true_type, false_type)
    }

    // Array
    Get(recv, idx) => {
      let trecv = self.synthesis!(recv)
      self.inherit!(idx, Type::Int)
      match trecv {
        Array(el) | Var({ val: Some(Array(el)) }) => el
        Var({ val: None } as at) => {
          let syn = Type::Array(Type::Var({ val: None }))
          at.val = Some(syn)
          syn
        }
        _ => raise TypeError("Type mismatch: should be array type \{trecv}")
      }
    }
    Put(recv, idx, expr) => {
      let recv_typ = self.synthesis!(recv)
      self.inherit!(idx, Type::Int)
      let expr_typ = self.synthesis!(expr)
      let _ = unify!(recv_typ, Array(expr_typ))
      Type::Unit
    }

    // Let
    Let((name, typ), expr, rest) => {
      self.inherit_let!((name, typ), expr)
      self.synthesis!(rest)
    }
    LetRec(def, rest) => {
      self.inherit_let_rec!(def)
      self.synthesis!(rest)
    }
    LetTuple(els, expr, rest) => {
      self.inherit_let_tuple!(els, expr)
      self.synthesis!(rest)
    }
  }
}
