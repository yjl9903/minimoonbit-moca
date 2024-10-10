pub fn type_check(syntax : @types.Syntax) -> @types.Syntax {
  let gamma = Gamma::new()
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
    Unit | Bool(_) | Int(_) | Double(_) =>
      if self.synthesis!(syntax) == expected {
        ()
      } else {
        raise TypeError("Type mismatch: \{syntax}")
      }

    // Binding
    Var(_) => {
      // TODO: check type or fill the inferred type
      let synthed = self.synthesis!(syntax)
      abort("todo")
    }
    Tuple(els) =>
      match expected {
        Tuple(expected) =>
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
        Array(expected) => self.inherit!(el, expected)
        _ => raise TypeError("Type mismatch: should be array \{syntax}")
      }
    }

    // Operation
    Not(expr) =>
      match expected {
        Bool => self.inherit!(expr, Type::Bool)
        _ => raise TypeError("Type mismatch: should be bool")
      }
    Neg(expr, ..) as neg =>
      match expected {
        Int => {
          neg.kind = Some(Kind::Int)
          self.inherit!(expr, Type::Int)
        }
        Double => {
          neg.kind = Some(Kind::Double)
          self.inherit!(expr, Type::Double)
        }
        _ => raise TypeError("Type mismatch: should be numeric")
      }
    Prim(lhs, rhs, _, ..) as prim =>
      match expected {
        Int => {
          prim.kind = Some(Kind::Int)
          self.inherit!(lhs, Type::Int)
          self.inherit!(rhs, Type::Int)
        }
        Double => {
          prim.kind = Some(Kind::Double)
          self.inherit!(lhs, Type::Double)
          self.inherit!(rhs, Type::Double)
        }
        _ => raise TypeError("Type mismatch: should be numeric")
      }
    Eq(lhs, rhs) | LE(lhs, rhs) =>
      match expected {
        Bool => abort("todo")
        _ => raise TypeError("Type mismatch: should be Bool \{syntax}")
      }
    App(sig, args) => abort("todo")

    // Branch
    If(cond, true_branch, false_branch) => {
      self.inherit!(cond, Type::Bool)
      abort("todo")
    }

    // Array
    Get(recv, idx) => {
      self.inherit!(recv, Type::Array(expected))
      self.inherit!(idx, Type::Int)
    }
    Put(recv, idx, expr) =>
      match expected {
        Unit => {
          // TODO: check
          self.inherit!(idx, Type::Int)
          abort("todo")
        }
        _ => raise TypeError("Type mismatch: should be Unit \{syntax}")
      }

    // Let
    Let((name, typ), expr, rest) => {
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
      self.inherit!(rest, expected)
    }
    LetRec(def, rest) => {
      if is_having_type(def.name.1) {
        // Annotated with type, check it
        match def.name.1 {
          Fun(t_args, t_ret) => {
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
            // Check ret
            new_env.inherit!(def.body, t_ret)
          }
          _ =>
            raise TypeError("Type mismatch: should be function \{syntax} : \{def.name.1}")
        }
      } else {
        match def.name.1 {
          Var(vt) =>
            vt.val = Some(
              Fun(def.args.map(fn { (_, t) => t }), Type::Var(Ref::new(None))),
            )
          _ => abort("unreachable")
        }
        self.add(def.name.0, def.name.1)
        let new_env = self.fork()
        def.args.each(fn { (name, typ) => new_env.add(name, typ) })
        let synthed = new_env.synthesis!(def.body)
        new_env.inherit!(def.body, synthed)
      }
      self.inherit!(rest, expected)
    }
    LetTuple(els, expr, rest) =>
      // TODO: check type
      self.inherit!(rest, expected)
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
        None => raise TypeError("Unknown identifier \{name}")
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
      match (self.synthesis?(lhs), self.synthesis?(rhs)) {
        (Ok(Int | Var({ val: Some(Int) })), Ok(Int | Var({ val: Some(Int) }))) => {
          prim.kind = Some(Kind::Int)
          Type::Int
        }
        (Ok(Int | Var({ val: Some(Int) })), Ok(Var({ val: None } as mt))) => {
          prim.kind = Some(Kind::Int)
          mt.val = Some(Int)
          Type::Int
        }
        (Ok(Var({ val: None } as mt)), Ok(Int | Var({ val: Some(Int) }))) => {
          prim.kind = Some(Kind::Int)
          mt.val = Some(Int)
          Type::Int
        }
        (
          Ok(Double | Var({ val: Some(Double) })),
          Ok(Double | Var({ val: Some(Double) })),
        ) => {
          prim.kind = Some(Kind::Double)
          Type::Double
        }
        (Ok(Double | Var({ val: Some(Double) })), Ok(Var({ val: None } as mt))) => {
          prim.kind = Some(Kind::Double)
          mt.val = Some(Double)
          Type::Double
        }
        (Ok(Var({ val: None } as mt)), Ok(Double | Var({ val: Some(Double) }))) => {
          prim.kind = Some(Kind::Double)
          mt.val = Some(Double)
          Type::Double
        }
        _ => raise TypeError("Type mismatch: should be numeric")
      }
    Eq(lhs, rhs) | LE(lhs, rhs) =>
      match (self.synthesis?(lhs), self.synthesis?(rhs)) {
        (Ok(Int | Var({ val: Some(Int) })), Ok(Int | Var({ val: Some(Int) }))) =>
          Type::Int
        (Ok(Int | Var({ val: Some(Int) })), Ok(Var({ val: None } as mt))) => {
          mt.val = Some(Int)
          Type::Int
        }
        (Ok(Var({ val: None } as mt)), Ok(Int | Var({ val: Some(Int) }))) => {
          mt.val = Some(Int)
          Type::Int
        }
        (
          Ok(Double | Var({ val: Some(Double) })),
          Ok(Double | Var({ val: Some(Double) })),
        ) => Type::Double
        (Ok(Double | Var({ val: Some(Double) })), Ok(Var({ val: None } as mt))) => {
          mt.val = Some(Double)
          Type::Double
        }
        (Ok(Var({ val: None } as mt)), Ok(Double | Var({ val: Some(Double) }))) => {
          mt.val = Some(Double)
          Type::Double
        }
        _ => raise TypeError("Type mismatch: should be numeric")
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
    If(cond, _true_branch, _false_branch) => {
      self.inherit!(cond, Type::Bool)
      abort("todo")
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
    Put(_) => {
      self.inherit!(syntax, Type::Unit)
      Type::Unit
    }

    // Let
    Let((_name, _typ), _expr, rest) => self.synthesis!(rest)
    LetRec(_def, rest) => self.synthesis!(rest)
    LetTuple(_els, _expr, rest) => self.synthesis!(rest)
  }
}
