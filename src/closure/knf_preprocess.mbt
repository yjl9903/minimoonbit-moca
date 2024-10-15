/// KNF preprocess:
/// 1. De-apply
/// 2. Collect free vars

/// Mutable func def
struct MutFuncDef {
  name : String
  slot : Int
  mut def : @knf.FuncDef

  /// It must be closure
  mut force_closure : Bool
  /// Collected free variables
  mut free_vars : @immut/hashset.T[Name]
}

fn MutFuncDef::new(world : KnfWorld, def : @knf.FuncDef) -> MutFuncDef {
  let slot = world.func_defs.length()
  let scope = String::concat(
    world.scope_path.map(fn { d => d.name }),
    separator="/",
  )
  let name = scope + "/" + def.name.name.or("$")
  let mutdef = {
    name,
    def,
    slot,
    force_closure: false,
    free_vars: @immut/hashset.new(),
  }
  world.func_defs.push(mutdef)
  mutdef
}

fn MutFuncDef::update_body(self : MutFuncDef, body : Knf) -> @knf.FuncDef {
  let def = { ..self.def, body, }
  self.def = def
  def
}

fn MutFuncDef::to_string(self : MutFuncDef) -> String {
  self.name + "." + self.slot.to_string()
}

struct KnfWorld {
  externals : @immut/hashset.T[Name]
  func_defs : Array[MutFuncDef]
  scope_path : Array[MutFuncDef]
}

fn KnfWorld::enter_scope(self : KnfWorld, def : MutFuncDef) -> Unit {
  self.scope_path.push(def)
}

fn KnfWorld::exit_scope(self : KnfWorld) -> Unit {
  let _ = self.scope_path.pop()
  ()
}

struct KnfEnv {
  world : KnfWorld
  global : @immut/hashset.T[Name]
  local : @hashset.T[Name]
  mut free_vars : @immut/hashset.T[Name]
}

fn KnfEnv::new(externals : Map[String, Type]) -> KnfEnv {
  let mut global = @immut/hashset.new()
  externals.each(
    fn {
      name, _ => {
        let binding = Name::name_only(@shared.ffi_prefix + name)
        global = global.add(binding)
      }
    },
  )
  {
    world: KnfWorld::{ externals: global, func_defs: [], scope_path: [] },
    global,
    free_vars: @immut/hashset.new(),
    local: @hashset.new(),
  }
}

fn KnfEnv::fork(self : KnfEnv) -> KnfEnv {
  let mut global = self.global
  self.local.each(fn { name => global = global.add(name) })
  {
    world: self.world,
    global,
    free_vars: @immut/hashset.new(),
    local: @hashset.new(),
  }
}

fn KnfEnv::add_local_var(self : KnfEnv, name : Name) -> Unit {
  self.local.insert(name)
}

fn KnfEnv::collect_free_var(self : KnfEnv, name : Name) -> Unit {
  match self.local.contains(name) {
    true => ()
    false =>
      match self.global.contains(name) {
        true =>
          if not(self.world.externals.contains(name)) {
            self.free_vars = self.free_vars.add(name)
          }
        false => @util.die("Unknown identifier name \{name}")
      }
  }
}

fn KnfEnv::collect_free_vars(self : KnfEnv, names : Iter[Name]) -> Unit {
  names.each(fn { name => self.collect_free_var(name) })
}

/// -------------
fn knf_preprocess(knf : Knf, externals : Map[String, Type]) -> (Knf, KnfEnv) {
  let env = KnfEnv::new(externals)
  let knf = env.visit_stmt(knf)
  (knf, env)
}

fn KnfEnv::visit_stmt(self : KnfEnv, knf : Knf) -> Knf {
  match knf {
    // Literal
    Unit | Int(_) | Double(_) => knf

    // Operator
    Neg(name) | FNeg(name) => {
      self.collect_free_var(name)
      knf
    }
    Add(lhs, rhs)
    | Sub(lhs, rhs)
    | Mul(lhs, rhs)
    | Div(lhs, rhs)
    | FAdd(lhs, rhs) | FSub(lhs, rhs) | FMul(lhs, rhs) | FDiv(lhs, rhs) => {
      self.collect_free_var(lhs)
      self.collect_free_var(rhs)
      knf
    }
    Apply(sig, args) => {
      self.collect_free_var(sig)
      self.collect_free_vars(args.iter())
      knf
    }

    // If
    IfEq(lhs, rhs, true_branch, false_branch) => {
      self.collect_free_var(lhs)
      self.collect_free_var(rhs)
      let true_branch = self.visit_stmt(true_branch)
      let false_branch = self.visit_stmt(false_branch)
      IfEq(lhs, rhs, true_branch, false_branch)
    }
    IfLe(lhs, rhs, true_branch, false_branch) => {
      self.collect_free_var(lhs)
      self.collect_free_var(rhs)
      let true_branch = self.visit_stmt(true_branch)
      let false_branch = self.visit_stmt(false_branch)
      IfLe(lhs, rhs, true_branch, false_branch)
    }

    // Binding
    Var(name) => {
      self.collect_free_var(name)
      knf
    }
    Tuple(els) => {
      self.collect_free_vars(els.iter())
      knf
    }

    // Array
    Get(recv, idx) => {
      self.collect_free_var(recv)
      self.collect_free_var(idx)
      knf
    }
    Put(recv, idx, name) => {
      self.collect_free_var(recv)
      self.collect_free_var(idx)
      self.collect_free_var(name)
      knf
    }

    // Let
    Let((name, typ), expr, rest) => {
      let expr = self.visit_stmt(expr)
      self.add_local_var(name)
      Let((name, typ), expr, self.visit_stmt(rest))
    }
    LetTuple(els, expr, rest) => {
      self.collect_free_var(expr)
      els.each(fn { el => self.add_local_var(el.0) })
      LetTuple(els, expr, self.visit_stmt(rest))
    }
    LetRec(def, rest) => {
      // Add func def to local env
      self.add_local_var(def.name)
      // Create mutable func def to maintain some extra information
      let mutdef = MutFuncDef::new(self.world, def)
      // 1. Fork new env for function body
      let new_env = self.fork()
      new_env.world.enter_scope(mutdef)
      // 2. Add params to local env
      def.args.each(fn { (name, _) => new_env.add_local_var(name) })
      // 3. Visit the function body, and update the current def
      let updated_def = mutdef.update_body(new_env.visit_stmt(def.body))
      // 4. Record function free variables, and nest free variables
      mutdef.free_vars = new_env.free_vars
      self.collect_free_vars(new_env.free_vars.iter())
      // 5. Back to the prev env
      new_env.world.exit_scope()
      LetRec(updated_def, self.visit_stmt(rest))
    }

    // Unused
    ExternalArray(_) | ExternalFunctionApplication(_) =>
      @util.die("unreachable")
  }
}

/// --- Types ---

fn to_direct_fn_low_type(typ : Type) -> LowType {
  match typ {
    Unit => Unit
    Bool => Bool
    Int => Int
    Double => Double
    Ptr => Ptr
    Fun(args, ret) =>
      DirectFn(
        args.map(fn { a => to_direct_fn_low_type(a) }),
        to_direct_fn_low_type(ret),
      )
    Tuple(els) => Tuple(els.map(fn { el => to_direct_fn_low_type(el) }))
    Array(arr) => Array(to_direct_fn_low_type(arr))
    Var({ val: Some(t) }) => to_direct_fn_low_type(t)
    Var({ val: None }) => @util.die("Unknown type \{typ}")
  }
}
