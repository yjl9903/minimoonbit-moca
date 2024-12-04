/// Extract generic function
pub fn KnfEnv::syntax_preprocess(
  self : KnfEnv,
  syntax : @types.Syntax
) -> @types.Syntax {
  let ctx = {
    funcs: @immut/hashmap.new(),
    replacement: @immut/hashmap.new(),
    generics: @hashset.new(),
    instances: Map::new(),
  }
  ctx.collect_generics(syntax)
  let syntax = ctx.transform_generics(syntax)
  @typing.type_check(syntax, self.externals)
}

struct GenericsContext {
  mut funcs : @immut/hashmap.T[String, Int]
  mut replacement : @immut/hashmap.T[Int, Type]
  generics : @hashset.T[Int]
  instances : Map[Int, Array[Array[Type]]]
}

fn GenericsContext::collect_generics(
  self : GenericsContext,
  syntax : @types.Syntax
) -> Unit {
  match syntax {
    Unit | Bool(_) | Int(_) | Double(_) => ()

    // Prim
    Not(syntax) => self.collect_generics(syntax)
    Neg(syntax, kind=_) => self.collect_generics(syntax)
    Prim(lhs, rhs, _, kind=_) => {
      self.collect_generics(lhs)
      self.collect_generics(rhs)
    }

    // Var
    Var(_) => ()
    Tuple(els) => els.each(fn { el => self.collect_generics(el) })
    Enum(_, _, els) => els.each(fn { el => self.collect_generics(el) })
    Array(size, base) => {
      self.collect_generics(size)
      self.collect_generics(base)
    }

    // If
    If(cond, true_branch, false_branch) => {
      self.collect_generics(cond)
      self.collect_generics(true_branch)
      self.collect_generics(false_branch)
    }
    Eq(lhs, rhs) => {
      self.collect_generics(lhs)
      self.collect_generics(rhs)
    }
    LE(lhs, rhs) => {
      self.collect_generics(lhs)
      self.collect_generics(rhs)
    }
    Match(expr, pats) => {
      self.collect_generics(expr)
      pats.each(fn { pat => self.collect_generics(pat.1) })
    }

    // Array
    Get(recv, idx) => {
      self.collect_generics(recv)
      self.collect_generics(idx)
    }
    Put(recv, idx, expr) => {
      self.collect_generics(recv)
      self.collect_generics(idx)
      self.collect_generics(expr)
    }

    // App
    App(sig, typs, args) => {
      match sig {
        Var(name) =>
          match self.funcs.find(name) {
            Some(id) =>
              if self.generics.contains(id) {
                let arr = match self.instances.get(id) {
                  Some(arr) => arr
                  None => {
                    let arr = []
                    self.instances.set(id, arr)
                    arr
                  }
                }
                arr.push(typs)
              }
            None => ()
          }
        _ => ()
      }
      self.collect_generics(sig)
      args.each(fn { arg => self.collect_generics(arg) })
    }

    // Let
    Let(_, expr, rest) => {
      self.collect_generics(expr)
      self.collect_generics(rest)
    }
    LetTuple(_, expr, rest) => {
      self.collect_generics(expr)
      self.collect_generics(rest)
    }
    LetEnum(_, rest) => self.collect_generics(rest)
    LetRec(def, rest) => {
      match def.name.1 {
        Pi(_) => self.generics.insert(def.id)
        _ => ()
      }
      self.funcs = self.funcs.add(def.name.0, def.id)
      self.collect_generics(def.body)
      self.collect_generics(rest)
    }
  }
}

fn GenericsContext::transform_generics(
  self : GenericsContext,
  syntax : @types.Syntax
) -> @types.Syntax {
  match syntax {
    Unit | Bool(_) | Int(_) | Double(_) => syntax

    // Prim
    Not(syntax) => Not(self.transform_generics(syntax))
    Neg(syntax, ~kind) => Neg(self.transform_generics(syntax), ~kind)
    Prim(lhs, rhs, op, ~kind) =>
      Prim(
        self.transform_generics(lhs),
        self.transform_generics(rhs),
        op,
        ~kind,
      )

    // Var
    Var(_) => syntax
    Tuple(els) => Tuple(els.map(fn { el => self.transform_generics(el) }))
    Enum(name, kind, els) =>
      Enum(name, kind, els.map(fn { el => self.transform_generics(el) }))
    Array(size, base) =>
      Array(self.transform_generics(size), self.transform_generics(base))

    // If
    If(cond, true_branch, false_branch) =>
      If(
        self.transform_generics(cond),
        self.transform_generics(true_branch),
        self.transform_generics(false_branch),
      )
    Eq(lhs, rhs) =>
      Eq(self.transform_generics(lhs), self.transform_generics(rhs))
    LE(lhs, rhs) =>
      LE(self.transform_generics(lhs), self.transform_generics(rhs))
    Match(expr, pats) => {
      let expr = self.transform_generics(expr)
      let pats = pats.map(fn { pat => (pat.0, self.transform_generics(pat.1)) })
      Match(expr, pats)
    }

    // Array
    Get(recv, idx) =>
      Get(self.transform_generics(recv), self.transform_generics(idx))
    Put(recv, idx, expr) =>
      Put(
        self.transform_generics(recv),
        self.transform_generics(idx),
        self.transform_generics(expr),
      )

    // App
    App(sig, typs, args) =>
      match sig {
        Var(name) =>
          match self.funcs.find(name) {
            Some(id) =>
              if self.generics.contains(id) {
                let suffix = generate_type_params_name(typs)
                App(Var(name + suffix), typs, args)
              } else {
                let sig = self.transform_generics(sig)
                let args = args.map(fn { arg => self.transform_generics(arg) })
                App(sig, typs, args)
              }
            None => {
              let sig = self.transform_generics(sig)
              let args = args.map(fn { arg => self.transform_generics(arg) })
              App(sig, typs, args)
            }
          }
        _ => {
          let sig = self.transform_generics(sig)
          let args = args.map(fn { arg => self.transform_generics(arg) })
          App(sig, typs, args)
        }
      }

    // Let
    Let((name, typ), expr, rest) =>
      Let(
        (name, self.replace_type(typ)),
        self.transform_generics(expr),
        self.transform_generics(rest),
      )
    LetTuple(binding, expr, rest) =>
      LetTuple(
        binding.map(fn { b => (b.0, self.replace_type(b.1)) }),
        self.transform_generics(expr),
        self.transform_generics(rest),
      )
    LetEnum(def, rest) => LetEnum(def, self.transform_generics(rest))
    LetRec(def, rest) =>
      match def.name.1 {
        Pi(type_params, def_typ) =>
          match self.instances.get(def.id) {
            Some(instances) => {
              let replacement = self.replacement
              let defs = instances.map(
                fn {
                  instance => {
                    let suffix = generate_type_params_name(instance)
                    let mut replacement = replacement
                    for i = 0; i < type_params.length(); i = i + 1 {
                      replacement = replacement.add(
                        type_params[i].1,
                        instance[i],
                      )
                    }
                    self.replacement = replacement
                    let body = self.transform_generics(def.body)
                    @types.Fundef::{
                      id: @types.generate_fun_def_id(),
                      name: (def.name.0 + suffix, self.replace_type(def_typ)),
                      args: def.args.map(
                        fn { arg => (arg.0, self.replace_type(arg.1)) },
                      ),
                      body,
                    }
                  }
                },
              )
              defs.rev_fold(
                fn { acc, def => LetRec(def, acc) },
                init=self.transform_generics(rest),
              )
            }
            None => self.transform_generics(rest)
          }
        _ => {
          let body = self.transform_generics(def.body)
          let def = { ..def, body, }
          LetRec(def, self.transform_generics(rest))
        }
      }
  }
}

fn GenericsContext::replace_type(
  self : GenericsContext,
  typ : Type,
  ~loc : SourceLoc = _
) -> Type {
  match typ {
    Var({ val: None }) | Identifier(_) | Pi(_) =>
      @util.die("Type error: \{typ}", ~loc)
    Var({ val: Some(typ) }) => self.replace_type(typ)
    Unit | Bool | Int | Double | Enum(_) | Ptr => typ
    Fun(args, ret) =>
      Fun(
        args.map(fn { arg => self.replace_type(arg) }),
        self.replace_type(ret),
      )
    Tuple(els) => Tuple(els.map(fn { el => self.replace_type(el) }))
    Array(base) => Array(self.replace_type(base))
    Param(_, id) =>
      match self.replacement.find(id) {
        Some(typ) => typ
        None => @util.die("Unknown type params \{typ}")
      }
  }
}

fn generate_type_params_name(typs : Array[Type]) -> String {
  if typs.length() == 0 {
    ""
  } else {
    let pieces = typs.map(fn { typ => typ.to_string() })
    "_" + pieces.join("_")
  }
}
