/// KNF preprocess: collect free vars

struct KnfEnv {
  world : KnfWorld
  scope_path : Array[MutFuncDef]
  local : @hashset.T[Name]
  global : @immut/hashset.T[Name]
  mut free_vars : @immut/hashset.T[Name]
  mut top_level : @immut/hashmap.T[Name, LowType]
  mut top_level_free_vars : @immut/hashmap.T[Name, LowType]
}

fn KnfEnv::new(externals : Map[String, Type]) -> KnfEnv {
  let mut world_global = @immut/hashmap.new()
  let mut global = @immut/hashset.new()
  let mut top_level = @immut/hashmap.new()
  externals.each(
    fn {
      name, typ => {
        let binding = Name::name_only(@shared.ffi_prefix + name)
        world_global = world_global.add(binding, to_direct_fn_low_type(typ))
        global = global.add(binding)
        top_level = top_level.add(binding, to_direct_fn_low_type(typ))
      }
    },
  )
  {
    world: KnfWorld::{ externals: world_global, func_defs: Map::new() },
    scope_path: [],
    local: @hashset.new(),
    global,
    top_level,
    free_vars: @immut/hashset.new(),
    top_level_free_vars: @immut/hashmap.new(),
  }
}

fn KnfEnv::fork(self : KnfEnv) -> KnfEnv {
  let mut global = self.global
  self.local.each(fn { name => global = global.add(name) })
  {
    world: self.world,
    scope_path: self.scope_path,
    local: @hashset.new(),
    global,
    top_level: self.top_level,
    free_vars: @immut/hashset.new(),
    top_level_free_vars: @immut/hashmap.new(),
  }
}

fn KnfEnv::add_top_level(self : KnfEnv, name : Name, typ : LowType) -> Unit {
  self.local.insert(name)
  self.top_level = self.top_level.add(name, typ)
}

fn KnfEnv::add_local_var(self : KnfEnv, name : Name) -> Unit {
  self.local.insert(name)
}

fn KnfEnv::collect_free_var(
  self : KnfEnv,
  name : Name,
  ~loc : SourceLoc = _
) -> Unit {
  match self.local.contains(name) {
    true => ()
    false =>
      match self.global.contains(name) {
        true =>
          match self.top_level.find(name) {
            Some(typ) =>
              self.top_level_free_vars = self.top_level_free_vars.add(name, typ)
            None => self.free_vars = self.free_vars.add(name)
          }
        false => @util.die("Unknown identifier name \{name}", ~loc)
      }
  }
}

fn KnfEnv::collect_free_vars(self : KnfEnv, names : Iter[Name]) -> Unit {
  names.each(fn { name => self.collect_free_var(name) })
}

fn KnfEnv::enter_scope(self : KnfEnv, def : MutFuncDef) -> Unit {
  self.scope_path.push(def)
}

fn KnfEnv::get_scope_path_name(self : KnfEnv, def : @knf.FuncDef) -> String {
  if self.scope_path.length() > 0 {
    let scope = self.scope_path.map(fn { d => d.def.name.name.or("unknown") })
    let scope = scope.join("/")
    scope + "/" + def.name.name.or("?")
  } else {
    def.name.name.or("?")
  }
}

fn KnfEnv::exit_scope(self : KnfEnv) -> Unit {
  let _ = self.scope_path.pop()
  ()
}

/// -------------
fn knf_preprocess(knf : Knf, externals : Map[String, Type]) -> (Knf, KnfWorld) {
  let env = KnfEnv::new(externals)
  let knf = env.visit_stmt(knf, top_level=true)
  (knf, env.world)
}

fn KnfEnv::visit_stmt(self : KnfEnv, knf : Knf, ~top_level : Bool) -> Knf {
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
    ExternalFunctionApplication(_, args) => {
      self.collect_free_vars(args.iter())
      knf
    }

    // If
    IfEq(lhs, rhs, true_branch, false_branch, typ) => {
      self.collect_free_var(lhs)
      self.collect_free_var(rhs)
      let true_branch = self.visit_stmt(true_branch, top_level=false)
      let false_branch = self.visit_stmt(false_branch, top_level=false)
      IfEq(lhs, rhs, true_branch, false_branch, typ)
    }
    IfLe(lhs, rhs, true_branch, false_branch, typ) => {
      self.collect_free_var(lhs)
      self.collect_free_var(rhs)
      let true_branch = self.visit_stmt(true_branch, top_level=false)
      let false_branch = self.visit_stmt(false_branch, top_level=false)
      IfLe(lhs, rhs, true_branch, false_branch, typ)
    }

    // Loop
    Loop(label, args, body) => {
      self.collect_free_vars(args.map(fn { a => a.0 }).iter())
      Loop(label, args, self.visit_stmt(body, top_level=false))
    }
    Continue(label, args) => {
      self.collect_free_vars(args.iter())
      Continue(label, args)
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
      let expr = self.visit_stmt(expr, top_level=false)
      if top_level {
        self.add_top_level(name, to_closure_fn_low_type(typ))
      } else {
        self.add_local_var(name)
      }
      Let((name, typ), expr, self.visit_stmt(rest, ~top_level))
    }
    LetTuple(els, expr, rest) => {
      self.collect_free_var(expr)
      els.each(fn { el => self.add_local_var(el.0) })
      LetTuple(els, expr, self.visit_stmt(rest, ~top_level))
    }
    LetRec(def, rest) => {
      // Add func def to local env
      if top_level {
        self.add_top_level(def.name, to_direct_fn_low_type(def.ty))
      } else {
        self.add_local_var(def.name)
      }
      // Create mutable func def to maintain some extra information
      let mutdef = MutFuncDef::new(self, def)
      // 1. Fork new env for function body
      let new_env = self.fork()
      new_env.enter_scope(mutdef)
      // 2. Add params to local env
      def.args.each(fn { (name, _) => new_env.add_local_var(name) })
      // 3. Visit the function body, and update the current def
      let updated_def = mutdef.update_body(
        new_env.visit_stmt(def.body, top_level=false),
      )
      // 4. Record function free variables, and nest free variables
      mutdef.free_vars = @immut/hashset.from_array(
        // Note: we should not pass itself for recursion, for it has not been initialized
        new_env.free_vars.iter().filter(fn { n => n != def.name }).collect(),
      )
      mutdef.top_level_free_vars = @immut/hashmap.from_iter(
        new_env.top_level_free_vars.iter(),
      )
      self.collect_free_vars(new_env.free_vars.iter())
      self.collect_free_vars(
        new_env.top_level_free_vars.iter().map(fn { v => v.0 }),
      )
      // 5. Back to the prev env
      new_env.exit_scope()
      LetRec(updated_def, self.visit_stmt(rest, ~top_level))
    }

    // External
    ExternalArray(_) => @util.die("unreachable")
  }
}
