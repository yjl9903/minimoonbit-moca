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
    Neg(expr, ..) as neg => abort("todo")
    Prim(lhs, rhs, _, ..) as prim => abort("todo")
    App(sig, args) => abort("todo")
    Get(recv, idx) =>
      match expected {
        Array(_) => {
          self.inherit!(recv, expected)
          self.inherit!(idx, Type::Int)
        }
        _ => raise TypeError("Type mismatch: should be array \{syntax}")
      }

    // Branch
    If(cond, true_branch, false_branch) => {
      self.inherit!(cond, Type::Bool)
      abort("todo")
    }
    Eq(lhs, rhs) => abort("todo")
    LE(lhs, rhs) => abort("todo")

    // Let
    Let((name, typ), expr, rest) => {
      // TODO: check this cond
      let typ = if is_known_type(typ) {
        self.inherit!(expr, typ)
        typ
      } else {
        let synthed = self.synthesis!(expr)
        match typ {
          Var(typ) => typ.val = Some(synthed)
          _ => ()
        }
        synthed
      }
      self.add(name, typ)
      self.inherit!(rest, expected)
    }
    LetRec(def, rest) => {
      let typ = def.name.1
      // TODO: check this cond
      if is_known_type(typ) {

      } else {
        // let synthed = self.synthesis!(expr)
        // match typ {
        //   Var(typ) => typ.val = Some(synthed)
        //   _ => ()
        // }
        // synthed
      }
      self.inherit!(rest, expected)
    }
    LetTuple(els, expr, rest) =>
      // TODO: check type
      self.inherit!(rest, expected)
    Put(recv, idx, expr) =>
      match expected {
        Unit => {
          // TODO: check
          self.inherit!(idx, Type::Int)
          abort("todo")
        }
        _ => raise TypeError("Type mismatch: should be Unit \{syntax}")
      }
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
            Ok(_) => raise TypeError("")
            Err(e) => raise e
          }
        None => types.map(fn { t => t.unwrap() })
      }
      Type::Tuple(types)
    }
    Array(_n, el) => Type::Array(self.synthesis!(el))

    // Operation
    Not(expr) => {
      self.inherit!(expr, Type::Bool)
      Type::Bool
    }
    Neg(expr, ..) as neg =>
      /// 1. Try synthesising the expr type
      /// 2. Guess Int
      /// 3. Guess Double
      match self.synthesis?(expr) {
        Ok(Int) => {
          neg.kind = Some(Kind::Int)
          Type::Int
        }
        Ok(Double) => {
          neg.kind = Some(Kind::Double)
          Type::Double
        }
        _ =>
          match self.inherit?(expr, Type::Int) {
            Ok(_) => {
              neg.kind = Some(Kind::Int)
              Type::Int
            }
            Err(_) =>
              match self.inherit?(expr, Type::Double) {
                Ok(_) => {
                  neg.kind = Some(Kind::Double)
                  Type::Double
                }
                Err(TypeError(e)) => raise TypeError(e)
              }
          }
      }
    Prim(lhs, rhs, _, ..) as prim =>
      match (self.synthesis?(lhs), self.synthesis?(rhs)) {
        (Ok(Int), Ok(Int)) => {
          prim.kind = Some(Kind::Int)
          Type::Int
        }
        (Ok(Double), Ok(Double)) => {
          prim.kind = Some(Kind::Double)
          Type::Double
        }
        _ =>
          match (self.inherit?(lhs, Type::Int), self.inherit?(rhs, Type::Int)) {
            (Ok(_), Ok(_)) => {
              prim.kind = Some(@types.Kind::Int)
              Type::Int
            }
            _ =>
              match
                (
                  self.inherit?(lhs, Type::Double),
                  self.inherit?(rhs, Type::Double),
                ) {
                (Ok(_), Ok(_)) => {
                  prim.kind = Some(@types.Kind::Double)
                  Type::Double
                }
                (Err(TypeError(e)), _) => raise TypeError(e)
                (_, Err(TypeError(e))) => raise TypeError(e)
              }
          }
      }
    App(_sig, _args) => abort("todo")
    Get(_recv, _idx) => abort("todo")

    // Branch
    If(cond, _true_branch, _false_branch) => {
      self.inherit!(cond, Type::Bool)
      abort("todo")
    }
    Eq(_lhs, _rhs) => abort("todo")
    LE(_lhs, _rhs) => abort("todo")

    // Let
    Let((_name, _typ), _expr, rest) => self.synthesis!(rest)
    LetRec(_def, rest) => self.synthesis!(rest)
    LetTuple(_els, _expr, rest) => self.synthesis!(rest)
    Put(_recv, _idx, _expr) => abort("todo")
  }
}
