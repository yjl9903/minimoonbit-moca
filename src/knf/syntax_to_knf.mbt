pub typealias LocalEnv = @immut/hashmap.T[String, Type]

pub let knf_counter : Ref[Int] = { val: 0 }

struct KnfEnv {
  mut env : @immut/hashmap.T[String, (Name, Type)]
  externals : @immut/hashmap.T[String, Type]
}

pub fn KnfEnv::new(externals : @immut/hashmap.T[String, Type]) -> KnfEnv {
  let knf_env = { env: @immut/hashmap.new(), externals }
  externals.each(
    fn {
      name, typ => {
        let binding = Name::name_only(@shared.ffi_prefix + name)
        knf_env.env = knf_env.env.add(name, (binding, typ))
      }
    },
  )
  knf_env
}

pub fn KnfEnv::fork(self : KnfEnv) -> KnfEnv {
  { env: self.env, externals: self.externals }
}

pub fn KnfEnv::init_counter_from_existing(
  _self : KnfEnv,
  _existing : Knf
) -> Unit {
  ()
}

pub fn new_temp() -> Name {
  let temp = Name::slot_only(knf_counter.val)
  knf_counter.val += 1
  temp
}

pub fn new_named_temp(name : String) -> Name {
  let name = Name::{ name: Some(name), slot: knf_counter.val }
  knf_counter.val += 1
  name
}

fn KnfEnv::new_let_binding(self : KnfEnv, name : String, typ : Type) -> Name {
  let binding : Name = { name: Some(name), slot: knf_counter.val }
  self.env = self.env.add(name, (binding, typ))
  knf_counter.val += 1
  binding
}

fn KnfEnv::new_let_rec_binding(self : KnfEnv, def : @types.Fundef) -> Name {
  let name = def.name.0
  let binding : Name = { name: Some(name), slot: knf_counter.val }
  self.env = self.env.add(name, (binding, def.name.1))
  knf_counter.val += 1
  binding
}

fn KnfEnv::find_binding_by_string(
  self : KnfEnv,
  name : String
) -> (Name, Type)? {
  self.env.find(name)
}

fn KnfEnv::find_name_by_string(self : KnfEnv, name : String) -> Name? {
  self.env.find(name).map(fn { v => v.0 })
}

pub fn KnfEnv::to_knf(self : KnfEnv, syntax : @types.Syntax) -> Knf {
  self.visit_global_defs(syntax)
}

fn KnfEnv::visit_global_defs(self : KnfEnv, syntax : @types.Syntax) -> Knf {
  fn visitor(syntax : @types.Syntax) {
    match syntax {
      Unit => Knf::Unit
      Let((name, typ), expr, rest) => {
        let (expr, _) = self.fork().visit_expr(expr)
        let name = self.new_let_binding(name, typ)
        Knf::Let((name, typ), expr, visitor(rest))
      }
      LetRec(def, rest) =>
        match def.name.0 {
          "init" => {
            let (body, _) = self.fork().visit_stmt(def.body)
            let temp = new_temp()
            let rest = visitor(rest)
            Knf::Let((temp, Unit), body, rest)
          }
          "main" => self.visit_stmt(def.body).0
          _ => {
            let funcdef = self.visit_let_rec(def)
            let rest = visitor(rest)
            Knf::LetRec(funcdef, rest)
          }
        }
      _ => @util.die("Unexpected node under global context")
    }
  }

  self.bind_global_const(fn() { visitor(syntax) })
}

/// Bind const: %const_1
fn KnfEnv::bind_global_const(self : KnfEnv, rest : () -> Knf) -> Knf {
  let ty = Type::Int
  let const0 = self.new_let_binding(@shared.zero_binding_name, ty)
  let expr0 = Knf::Int(0)
  let const1 = self.new_let_binding(@shared.one_binding_name, ty)
  let expr1 = Knf::Int(1)
  Knf::Let((const0, ty), expr0, Knf::Let((const1, ty), expr1, rest()))
}

fn KnfEnv::visit_let_rec(self : KnfEnv, def : @types.Fundef) -> FuncDef {
  let name = self.new_let_rec_binding(def)
  let new_env = self.fork()
  let args = def.args.map(
    fn { (name, typ) => (new_env.new_let_binding(name, typ), typ) },
  )
  let (body, _) = new_env.visit_stmt(def.body)
  { id: generate_func_id(), name, ty: def.name.1, args, body }
}

fn KnfEnv::visit_stmt(self : KnfEnv, syntax : @types.Syntax) -> (Knf, Type) {
  match syntax {
    Let((name, typ), expr, rest) => {
      let (expr, _) = self.fork().visit_expr(expr)
      let name = self.new_let_binding(name, typ)
      let (rest, rest_type) = self.visit_stmt(rest)
      (Knf::Let((name, typ), expr, rest), rest_type)
    }
    LetRec(def, rest) => {
      let funcdef = self.visit_let_rec(def)
      let (rest, rest_type) = self.visit_stmt(rest)
      (Knf::LetRec(funcdef, rest), rest_type)
    }
    LetTuple(names, expr, rest) => {
      let bindings = names.map(
        fn { (name, typ) => (self.new_let_binding(name, typ), typ) },
      )
      self.to_let_temp(
        expr,
        fn {
          (expr, _) => {
            let (rest, rest_type) = self.visit_stmt(rest)
            (Knf::LetTuple(bindings, expr, rest), rest_type)
          }
        },
      )
    }
    _ => self.visit_expr(syntax)
  }
}

/// Bind a temp variable
/// let _x = (expr) in (rest(_x))
fn KnfEnv::to_let_temp(
  self : KnfEnv,
  expr : @types.Syntax,
  rest : ((Name, Type)) -> (Knf, Type)
) -> (Knf, Type) {
  let (expr, expr_type) = self.fork().visit_expr(expr)
  let name = new_temp()
  let (rest, rest_type) = rest((name, expr_type))
  (Knf::Let((name, expr_type), expr, rest), rest_type)
}

/// Bind two temp variables
/// let _1 = (expr1) in let _2 = (expr2) in ... in (rest(_1, _2, ...))
fn KnfEnv::to_let_binary_temps(
  self : KnfEnv,
  lhs : @types.Syntax,
  rhs : @types.Syntax,
  rest : ((Name, Type), (Name, Type)) -> (Knf, Type)
) -> (Knf, Type) {
  self.to_let_temp(
    lhs,
    fn { lhs => self.to_let_temp(rhs, fn { rhs => rest(lhs, rhs) }) },
  )
}

/// Bind three temp variables
/// let _1 = (expr1) in let _2 = (expr2) in ... in (rest(_1, _2, ...))
fn KnfEnv::to_let_triple_temps(
  self : KnfEnv,
  op1 : @types.Syntax,
  op2 : @types.Syntax,
  op3 : @types.Syntax,
  rest : ((Name, Type), (Name, Type), (Name, Type)) -> (Knf, Type)
) -> (Knf, Type) {
  self.to_let_temp(
    op1,
    fn {
      op1 =>
        self.to_let_temp(
          op2,
          fn { op2 => self.to_let_temp(op3, fn { op3 => rest(op1, op2, op3) }) },
        )
    },
  )
}

/// Bind a list of temp variables
/// let _1 = (expr1) in let _2 = (expr2) in ... in (rest(_1, _2, ...))
fn KnfEnv::to_let_temps(
  self : KnfEnv,
  exprs : Array[@types.Syntax],
  rest : (Array[(Name, Type)]) -> (Knf, Type)
) -> (Knf, Type) {
  let exprs = exprs.map(
    fn {
      expr => {
        let (expr, expr_type) = self.fork().visit_expr(expr)
        let name = new_temp()
        (name, expr_type, expr)
      }
    },
  )
  let bindings = exprs.map(fn { t => (t.0, t.1) })
  exprs.rev_fold(
    fn {
      suffix, (name, typ, expr) =>
        (Knf::Let((name, typ), expr, suffix.0), suffix.1)
    },
    init=rest(bindings),
  )
}

fn KnfEnv::visit_expr(self : KnfEnv, syntax : @types.Syntax) -> (Knf, Type) {
  match syntax {
    // Literal
    Unit => (Knf::Unit, Type::Unit)
    Int(v) => (Knf::Int(v), Type::Int)
    Bool(v) =>
      (
        Knf::Var(
          self
          .find_name_by_string(
            match v {
              true => @shared.one_binding_name
              false => @shared.zero_binding_name
            },
          )
          .unwrap(),
        ),
        Type::Int,
      )
    Double(v) => (Knf::Double(v), Type::Double)

    // Expr
    Var(name) =>
      match self.find_binding_by_string(name) {
        Some((name, typ)) => (Knf::Var(name), typ)
        None => @util.die("Can not resolve variable \{name}")
      }
    Tuple(els) =>
      ///   let _0 = (expr0) in
      ///     let _1 = (expr1) in
      ///       let _2 = (expr2) in
      ///         ...
      ///           (_0, _1, _2, ...)
      self.to_let_temps(
        els,
        fn {
          names =>
            (
              Knf::Tuple(names.map(fn { n => n.0 })),
              Type::Tuple(names.map(fn { n => n.1 })),
            )
        },
      )
    Not(expr) =>
      /// let _expr = (expr) in Sub(%const_1, _expr)
      self.to_let_temp(
        expr,
        fn {
          (name, _) =>
            (
              Knf::Sub(
                self.find_name_by_string(@shared.one_binding_name).unwrap(),
                name,
              ),
              Int,
            )
        },
      )
    Array(n, expr) =>
      /// let _n = (n) in let _expr = (expr) in Array::make(_n, _expr)
      self.to_let_temp(
        n,
        fn {
          n =>
            self.to_let_temp(
              expr,
              fn {
                (expr, expr_type) =>
                  (
                    Knf::ExternalFunctionApplication(
                      match expr_type {
                        Double | Var({ val: Some(Double) }) =>
                          @shared.make_float_array_binding_name
                        Int
                        | Bool | Unit | Var({ val: Some(Int | Bool | Unit) }) =>
                          @shared.make_array_binding_name
                        _ => @shared.make_ptr_array_binding_name
                      },
                      [n.0, expr],
                    ),
                    Type::Array(expr_type),
                  )
              },
            )
        },
      )
    Neg(expr, ~kind) =>
      /// let _expr = (expr) in Neg(_expr)
      match kind {
        Some(Int) =>
          self.to_let_temp(expr, fn { (name, _) => (Knf::Neg(name), Int) })
        Some(Double) =>
          self.to_let_temp(expr, fn { (name, _) => (Knf::FNeg(name), Double) })
        None => @util.die("miss typing information : Neg(expr, None)")
      }
    /// let _sig = (sig) in let _arg0 = (arg0) in ... in Apply(_sig, (_arg0, ...)) 
    App(sig, args) =>
      match sig {
        Var(name) =>
          match self.env.find(name) {
            Some((func, func_ty)) =>
              self.to_let_temps(
                args,
                fn {
                  args =>
                    (
                      if func.slot == 0 {
                        // ExternalApplication
                        Knf::ExternalFunctionApplication(
                          @shared.ffi_prefix + name,
                          args.map(fn { a => a.0 }),
                        )
                      } else {
                        Knf::Apply(func, args.map(fn { a => a.0 }))
                      },
                      match extract_return_type(func_ty) {
                        Some(t) => t
                        None =>
                          @util.die("Type mismatch: should be function type")
                      },
                    )
                },
              )
            None =>
              match self.externals.find(name) {
                Some(external_typ) =>
                  self.to_let_temps(
                    args,
                    fn {
                      args =>
                        (
                          ExternalFunctionApplication(
                            @shared.ffi_prefix + name,
                            args.map(fn { a => a.0 }),
                          ),
                          match extract_return_type(external_typ) {
                            Some(t) => t
                            None =>
                              @util.die(
                                "Type mismatch: should be function type",
                              )
                          },
                        )
                    },
                  )
                None => @util.die("unknown function \{name}")
              }
          }
        _ =>
          self.to_let_temp(
            sig,
            fn {
              (sig, sig_type) =>
                self.to_let_temps(
                  args,
                  fn {
                    args =>
                      (
                        Knf::Apply(sig, args.map(fn { a => a.0 })),
                        match extract_return_type(sig_type) {
                          Some(t) => t
                          None =>
                            @util.die("Type mismatch: should be array type")
                        },
                      )
                  },
                )
            },
          )
      }
    Get(recv, idx) =>
      /// let _recv = (recv) in let _idx = (idx) in Get(_recv, _idx)
      self.to_let_temp(
        recv,
        fn {
          (recv, recv_type) =>
            self.to_let_temp(
              idx,
              fn {
                (idx, _) =>
                  (
                    Knf::Get(recv, idx),
                    match extract_array_type(recv_type) {
                      Some(t) => t
                      None => @util.die("Type mismatch: should be array type")
                    },
                  )
              },
            )
        },
      )
    If(cond, true_branch, false_branch) =>
      /// let _lhs = (lhs) in let _rhs = (rhs) in IfEq / IfLe (lhs, rhs, true_branch, false_branch)
      match cond {
        Eq(lhs, rhs) =>
          self.to_let_binary_temps(
            lhs,
            rhs,
            fn {
              (lhs, _), (rhs, _) => {
                let (true_branch, true_type) = self.fork().visit_stmt(true_branch)
                let (false_branch, _) = self.fork().visit_stmt(false_branch)
                (
                  Knf::IfEq(lhs, rhs, true_branch, false_branch, true_type),
                  true_type,
                )
              }
            },
          )
        LE(lhs, rhs) =>
          self.to_let_binary_temps(
            lhs,
            rhs,
            fn {
              (lhs, _), (rhs, _) => {
                let (true_branch, true_type) = self.fork().visit_stmt(true_branch)
                let (false_branch, _) = self.fork().visit_stmt(false_branch)
                (
                  Knf::IfLe(lhs, rhs, true_branch, false_branch, true_type),
                  true_type,
                )
              }
            },
          )
        _ =>
          self.to_let_temp(
            cond,
            fn {
              (cond, _) => {
                let (true_branch, true_type) = self.fork().visit_stmt(true_branch)
                let (false_branch, _) = self.fork().visit_stmt(false_branch)
                (
                  Knf::IfEq(
                    cond,
                    self.find_name_by_string(@shared.one_binding_name).unwrap(),
                    true_branch,
                    false_branch,
                    true_type,
                  ),
                  true_type,
                )
              }
            },
          )
      }
    Prim(lhs, rhs, op, ~kind) =>
      /// let _lhs = (lhs) in let _rhs = (rhs) in Add / Sub / Mul / Div (_lhs, _rhs)
      match kind {
        Some(Int) =>
          self.to_let_binary_temps(
            lhs,
            rhs,
            fn {
              (lhs, _), (rhs, _) =>
                match op {
                  Add => (Knf::Add(lhs, rhs), Int)
                  Sub => (Knf::Sub(lhs, rhs), Int)
                  Mul => (Knf::Mul(lhs, rhs), Int)
                  Div => (Knf::Div(lhs, rhs), Int)
                }
            },
          )
        Some(Double) =>
          self.to_let_binary_temps(
            lhs,
            rhs,
            fn {
              (lhs, _), (rhs, _) =>
                match op {
                  Add => (Knf::FAdd(lhs, rhs), Double)
                  Sub => (Knf::FSub(lhs, rhs), Double)
                  Mul => (Knf::FMul(lhs, rhs), Double)
                  Div => (Knf::FDiv(lhs, rhs), Double)
                }
            },
          )
        None => @util.die("miss typing information : Prim(lhs, rhs, op, None)")
      }
    Eq(lhs, rhs) =>
      /// let _lhs = (lhs) in let _rhs = (rhs) in IfEq(_lhs, _rhs, Int(1), Int(0))
      self.to_let_binary_temps(
        lhs,
        rhs,
        fn {
          (lhs, _), (rhs, _) =>
            (Knf::IfEq(lhs, rhs, Knf::Int(1), Knf::Int(0), Type::Int), Int)
        },
      )
    LE(lhs, rhs) =>
      /// let _lhs = (lhs) in let _rhs = (rhs) in IfLe(_lhs, _rhs, Int(1), Int(0))
      self.to_let_binary_temps(
        lhs,
        rhs,
        fn {
          (lhs, _), (rhs, _) =>
            (Knf::IfLe(lhs, rhs, Knf::Int(1), Knf::Int(0), Type::Int), Int)
        },
      )

    // Binding
    Put(recv, idx, expr) =>
      self.to_let_triple_temps(
        recv,
        idx,
        expr,
        fn {
          (recv, _), (idx, _), (expr, _) =>
            (Knf::Put(recv, idx, expr), Type::Unit)
        },
      )
    Let(_) => self.visit_stmt(syntax)
    LetRec(_) => self.visit_stmt(syntax)
    LetTuple(_) => self.visit_stmt(syntax)
  }
}
