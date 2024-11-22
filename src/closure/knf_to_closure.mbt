priv struct Context {
  world : KnfWorld
  mut current_func : MutFuncDef?
  func_defs : @hashmap.T[Int, FuncDef]
  global : @immut/hashmap.T[Name, LowType]
  local_closures : @hashmap.T[Name, FuncDef?]
  local_vars : @hashmap.T[Name, LowType]
}

fn Context::new(externals : Map[String, Type], world : KnfWorld) -> Context {
  let mut global = @immut/hashmap.new()
  externals.each(
    fn {
      name, typ => {
        let binding = Name::name_only(@shared.ffi_prefix + name)
        global = global.add(binding, to_direct_fn_low_type(typ))
      }
    },
  )
  {
    world,
    current_func: None,
    func_defs: @hashmap.new(),
    global,
    local_closures: @hashmap.new(),
    local_vars: @hashmap.new(),
  }
}

fn Context::fork(self : Context) -> Context {
  let mut global = self.global
  self.local_vars.each(fn { name, typ => global = global.add(name, typ) })
  {
    world: self.world,
    current_func: None,
    func_defs: self.func_defs,
    global,
    local_closures: @hashmap.new(),
    local_vars: @hashmap.new(),
  }
}

fn Context::add_local_var(self : Context, name : Name, typ : LowType) -> Unit {
  self.local_vars.set(name, typ)
}

fn Context::get_low_type_of(self : Context, name : Name) -> LowType {
  match self.local_vars.get(name) {
    Some(t) => t
    None =>
      match self.global.find(name) {
        Some(t) => t
        None => @util.die("Unknown identifier name \{name}")
      }
  }
}

fn Context::get_low_types_of(
  self : Context,
  names : Array[Name]
) -> Array[LowType] {
  names.map(fn { n => self.get_low_type_of(n) })
}

/// -------
pub fn knf_program_to_closure(
  knf : Knf,
  externals : Map[String, Type]
) -> Program {
  let (knf, world) = knf_preprocess(knf, externals)
  let context = Context::new(externals, world)
  context.visit_global_defs(knf)
}

fn Context::visit_global_defs(self : Context, knf : Knf) -> Program {
  let body = self.visit_stmt(knf, true)
  Program::{
    fundefs: self.func_defs.iter().map(fn { (_, d) => d }).collect(),
    body,
  }
}

fn Context::visit_stmt(self : Context, knf : Knf, is_top_level : Bool) -> Expr {
  match knf {
    // Literal
    Unit => Unit
    Int(v) => Int(v)
    Double(v) => Double(v)

    // Operator
    Neg(expr) => Neg(expr)
    Add(lhs, rhs) => Add(lhs, rhs)
    Sub(lhs, rhs) => Sub(lhs, rhs)
    Mul(lhs, rhs) => Mul(lhs, rhs)
    Div(lhs, rhs) => Div(lhs, rhs)
    FNeg(expr) => FNeg(expr)
    FAdd(lhs, rhs) => FAdd(lhs, rhs)
    FSub(lhs, rhs) => FSub(lhs, rhs)
    FMul(lhs, rhs) => FMul(lhs, rhs)
    FDiv(lhs, rhs) => FDiv(lhs, rhs)
    Apply(sig, args) =>
      match self.local_closures.get(sig) {
        // It is defined locally
        Some(Some(func)) =>
          if not(func.is_closure) {
            CallDirect(func.name, args)
          } else {
            CallClosure(sig, args)
          }
        Some(None) => {
          // Self recusrion
          let def = self.current_func.or_else(
            fn() { @util.die("should have func def") },
          )
          if def.force_closure || def.free_vars.size() > 0 {
            CallClosure(sig, args)
          } else {
            CallDirect(def.to_label(), args)
          }
        }
        // It may be passed from outside
        None => CallClosure(sig, args)
      }
    ExternalFunctionApplication(sig, args) => CallDirect(sig, args)

    // If
    IfEq(lhs, rhs, true_branch, false_branch, if_type) => {
      let true_branch = self.visit_stmt(true_branch, is_top_level)
      let false_branch = self.visit_stmt(false_branch, is_top_level)
      IfEq(lhs, rhs, true_branch, false_branch, to_closure_fn_low_type(if_type))
    }
    IfLe(lhs, rhs, true_branch, false_branch, if_type) => {
      let true_branch = self.visit_stmt(true_branch, is_top_level)
      let false_branch = self.visit_stmt(false_branch, is_top_level)
      IfLe(lhs, rhs, true_branch, false_branch, to_closure_fn_low_type(if_type))
    }

    // Match 
    Match(expr, pats) =>
      Match(
        expr,
        pats.map(
          fn {
            pat =>
              (
                pat.0,
                self.visit_stmt(pat.1, is_top_level),
              )
          },
        ),
      )
    // Loop
    Loop((label, ty), args, body) => {
      let args = args.map(fn { a => (a.0, to_closure_fn_low_type(a.1)) })
      let body = self.visit_stmt(body, is_top_level)
      Loop((label, to_closure_fn_low_type(ty)), args, body)
    }
    Continue(label, args) => Continue(label, args)

    // Array
    Get(recv, idx) => ArrayGet(recv, idx)
    Put(recv, idx, expr) => ArrayPut(recv, idx, expr)

    // Binding
    Var(name) => Var(name)
    Tuple(els) => MakeTuple(els)

    // Enum 
    Enum(lhs, rhs, array) => MakeEnum(lhs, rhs, array)

    // Let
    Let((name, typ), expr, rest) => {
      let expr = self.visit_stmt(expr, false)
      let low_type = to_closure_fn_low_type(typ)
      self.add_local_var(name, low_type)
      let rest = self.visit_stmt(rest, is_top_level)
      Let((name, low_type), expr, rest)
    }
    LetTuple(els, expr, rest) =>
      LetTuple(
        els.mapi(
          fn {
            _, (name, typ) => {
              let low_type = to_closure_fn_low_type(typ)
              self.add_local_var(name, low_type)
              (name, low_type)
            }
          },
        ),
        expr,
        self.visit_stmt(rest, is_top_level),
      )
    LetRec(def, rest) => {
      // 1. Check whether it should be closure
      let name = def.name
      let mutdef = self.world.func_defs.get(def.id).unwrap()
      let is_closure = mutdef.force_closure || mutdef.free_vars.size() > 0
      let args_type = def.args.map(fn { a => to_closure_fn_low_type(a.1) })
      let ret_type = match def.ty {
        Fun(_, ret) => to_closure_fn_low_type(ret)
        _ => @util.die("unreachable")
      }
      let func_type = if is_closure {
        ClosureFn(args_type, ret_type)
      } else {
        DirectFn(args_type, ret_type)
      }
      // 2. Fork new env
      self.add_local_var(name, func_type)
      let new_env = self.fork()
      new_env.current_func = Some(mutdef)
      new_env.local_closures.set(name, None)
      def.args.eachi(
        fn { i, (name, _) => new_env.add_local_var(name, args_type[i]) },
      )
      let body = new_env.visit_stmt(def.body, false)
      // 3. Func def
      let func : FuncDef = {
        id: def.id,
        name: mutdef.to_label(),
        old_name: name,
        is_closure,
        ty: func_type,
        args: def.args.mapi(fn { i, a => (a.0, args_type[i]) }),
        formal_free_vars: mutdef.free_vars
        .iter()
        .map(fn { fv => (fv, self.get_low_type_of(fv)) })
        .collect(),
        body,
      }
      self.func_defs.set(def.id, func)
      self.local_closures.set(name, Some(func))
      // 4. Build rest stmts
      let rest = self.visit_stmt(rest, is_top_level)
      if is_top_level {
        // TODO: this is not safe
        MakeClosure(
          (name, func_type),
          Closure::{
            name: mutdef.to_label(),
            actual_free_vars: mutdef.free_vars.iter().collect(),
          },
          rest,
        )
      } else {
        MakeClosure(
          (name, func_type),
          Closure::{
            name: mutdef.to_label(),
            actual_free_vars: mutdef.free_vars.iter().collect(),
          },
          rest,
        )
      }
    }

    // Unused
    ExternalArray(_) => @util.die("unreachable")
  }
}
