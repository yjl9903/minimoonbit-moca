/// KNF preprocess:
/// 1. De-apply
/// 2. Collect free vars

struct MutFuncDef {
  name : String
  def : @knf.FuncDef
  slot : Int

  /// It must be closure
  force_closure : Bool
  /// Collected free variables
  free_vars : @immut/hashset.T[Name]
}

fn MutFuncDef::new(
  world : KnfWorld,
  def : @knf.FuncDef,
  free_vars : @immut/hashset.T[Name]
) -> MutFuncDef {
  let slot = world.func_defs.length()
  let scope = String::concat(
    world.scope_path.map(fn { d => d.name }),
    separator="/",
  )
  let name = scope + "/" + def.name.name.or("$")
  let mutdef = { name, def, slot, force_closure: false, free_vars }
  world.func_defs.push(mutdef)
  mutdef
}

fn MutFuncDef::to_string(self : MutFuncDef) -> String {
  self.name + "." + self.slot.to_string()
}

struct KnfWorld {
  func_defs : Array[MutFuncDef]
  scope_path : Array[MutFuncDef]
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
    world: KnfWorld::{ func_defs: [], scope_path: [] },
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
    global: self.global,
    // func_defs: self.func_defs,
    free_vars: @immut/hashset.new(),
    local: @hashset.new(),
  }
}

fn KnfEnv::collect_free_var(self : KnfEnv, name : Name) -> Unit {
  match self.local.contains(name) {
    true => ()
    false =>
      match self.global.contains(name) {
        true => self.free_vars = self.free_vars.add(name)
        false => @util.die("Unknown identifier name \{name}")
      }
  }
}

/// -------------
fn knf_preprocess(knf : Knf, externals : Map[String, Type]) -> (Knf, KnfEnv) {
  let env = KnfEnv::new(externals)
  let knf = env.visit_stmt(knf)
  (knf, env)
}

fn KnfEnv::visit_stmt(
  self : KnfEnv,
  knf : Knf,
  // Used for apply
  ~applier : ((Name) -> Knf)? = None
) -> Knf {
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
    Apply(_) => abort("todo")

    // If
    IfEq(lhs, rhs, true_branch, false_branch) => {
      self.collect_free_var(lhs)
      self.collect_free_var(rhs)
      let true_branch = self.visit_stmt(true_branch, ~applier)
      let false_branch = self.visit_stmt(false_branch, ~applier)
      IfEq(lhs, rhs, true_branch, false_branch)
    }
    IfLe(lhs, rhs, true_branch, false_branch) => {
      self.collect_free_var(lhs)
      self.collect_free_var(rhs)
      let true_branch = self.visit_stmt(true_branch, ~applier)
      let false_branch = self.visit_stmt(false_branch, ~applier)
      IfLe(lhs, rhs, true_branch, false_branch)
    }

    // Binding
    Var(name) => {
      self.collect_free_var(name)
      match applier {
        Some(applier) => applier(name)
        None => knf
      }
    }
    Tuple(els) => {
      els.each(fn { el => self.collect_free_var(el) })
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
    Let((name, _), expr, rest) => abort("todo")
    LetTuple(els, expr, rest) => abort("todo")
    LetRec(def, rest) => abort("todo")

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
