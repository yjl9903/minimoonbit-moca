struct WorldBuilder {
  externals : @immut/hashmap.T[String, @types.Type]
  all_funs : Map[String, @closure.FuncDef]
  // Builders
  builders : Map[String, MethodBuilder]
  // Mark some closure name as call direct
  direct_closure : Map[Name, @closure.FuncDef]
  // Global functions
  global_funs : Map[String, @closure.FuncDef]
  /// Global variables
  global_vars : Map[Name, Var]
  mut global_vars_counter : Int
}

pub let global_vars_counter : Ref[Int] = { val: 0 }

pub fn WorldBuilder::new(
  externals : @immut/hashmap.T[String, @types.Type]
) -> WorldBuilder {
  {
    externals,
    all_funs: Map::new(),
    builders: Map::new(),
    direct_closure: Map::new(),
    global_funs: Map::new(),
    global_vars: Map::new(),
    global_vars_counter: 0,
  }
}

fn WorldBuilder::get_func_def(
  self : WorldBuilder,
  label : @closure.Label
) -> @closure.FuncDef {
  self.all_funs.get(label._).unwrap()
}

fn WorldBuilder::get_method_builder(
  self : WorldBuilder,
  label : String
) -> MethodBuilder {
  self.builders.get(label).unwrap()
}

fn WorldBuilder::add_global_var(
  self : WorldBuilder,
  name : Name,
  typ : Type
) -> Unit {
  if self.global_vars.contains(name) {
    return
  }
  let var : Var = {
    id: self.global_vars_counter,
    name: name.name,
    ty: typ,
    is_this: false,
    is_param: false,
    is_global: true,
    is_mut: false,
    const_value: get_const_value(name),
    is_phi: false,
    outcoming: None,
  }
  self.global_vars_counter = self.global_vars_counter + 1
  self.global_vars.set(name, var)
}

fn WorldBuilder::add_global_fun(
  self : WorldBuilder,
  name : Name,
  closure : @closure.Closure
) -> Unit {
  let def = self.get_func_def(closure.name)
  def.formal_free_vars = def.formal_free_vars.filter(
    fn {
      (name, _) =>
        not(self.global_vars.contains(name)) &&
        not(self.direct_closure.contains(name))
    },
  )
  def.is_closure = def.formal_free_vars.length() > 0
  self.global_funs.set(closure.name._, def)
  if not(def.is_closure) {
    self.direct_closure.set(name, def)
  }
}

pub fn WorldBuilder::build(
  self : WorldBuilder,
  prog : @closure.Program
) -> World {
  // Collect all functions
  prog.fundefs.each(fn { f => self.all_funs.set(f.name._, f) })
  // 1. Preprocess closure
  let main_expr = self.preprocess(prog.body)
  prog.fundefs.each(fn { def => def.body = self.preprocess(def.body) })
  // 2. Prepare all the method builders
  let main_method_builder = self.create_main_method_builder()
  let method_builders = prog.fundefs.map(
    fn { def => (def, self.create_method_builder(def)) },
  )
  // 3. Build all the method
  let main_method = main_method_builder.build(main_expr)
  let methods = method_builders.map(
    fn { (def, builder) => (def.name._, builder.build(def.body)) },
  )
  // 4. Create the world
  let world : World = {
    externals: Map::from_iter(
      self.externals
      .iter()
      .map(
        fn {
          (name, ty) =>
            (@shared.ffi_prefix + name, @closure.to_direct_fn_low_type(ty))
        },
      ),
    ),
    global: self.global_vars.values().collect(),
    methods: Map::from_array(methods),
    main_method,
  }
  set_world(world)
  global_vars_counter.val = self.global_vars_counter
  world
}

fn WorldBuilder::preprocess(
  self : WorldBuilder,
  expr : @closure.Expr
) -> @closure.Expr {
  match expr {
    // Bypass
    Unit
    | Int(_)
    | Double(_)
    | Var(_)
    | Neg(_)
    | Add(_, _)
    | Sub(_, _)
    | Mul(_, _)
    | Div(_, _)
    | FNeg(_)
    | FAdd(_, _)
    | FSub(_, _)
    | FMul(_, _)
    | FDiv(_, _) | MakeTuple(_) | ArrayGet(_) | ArrayPut(_) | ExternalArray(_) =>
      expr

    // If
    IfEq(lhs, rhs, true_branch, false_branch, if_type) =>
      IfEq(
        lhs,
        rhs,
        self.preprocess(true_branch),
        self.preprocess(false_branch),
        if_type,
      )
    IfLe(lhs, rhs, true_branch, false_branch, if_type) =>
      IfLe(
        lhs,
        rhs,
        self.preprocess(true_branch),
        self.preprocess(false_branch),
        if_type,
      )

    // Loop
    Loop(label, args, body) => Loop(label, args, self.preprocess(body))
    Continue(label, args) => Continue(label, args)

    // Call
    CallDirect(_) => expr
    CallClosure(name, args) =>
      match self.direct_closure.get(name) {
        Some(def) => CallDirect(def.name, args)
        None => CallClosure(name, args)
      }

    // Let
    MakeClosure((name, typ), closure, rest) => {
      // let def = self.get_func_def(closure.name)
      // closure.actual_free_vars.eachi(
      //   fn { i, name => self.add_global_var(name, def.formal_free_vars[i].1) },
      // )
      let actual_free_vars = closure.actual_free_vars.filter(
        fn {
          name =>
            not(self.global_vars.contains(name)) &&
            not(self.direct_closure.contains(name))
        },
      )
      self.add_global_fun(name, closure)
      self.add_global_var(name, typ)
      MakeClosure(
        (name, typ),
        { name: closure.name, actual_free_vars },
        self.preprocess(rest),
      )
    }
    Let((name, typ), expr, rest) => {
      match get_const_value(name) {
        Some(Int(_)) => self.add_global_var(name, Int)
        _ => ()
      }
      Let((name, typ), self.preprocess(expr), self.preprocess(rest))
    }
    LetTuple(els, expr, rest) => LetTuple(els, expr, self.preprocess(rest))
  }
}

fn WorldBuilder::create_main_method_builder(
  self : WorldBuilder
) -> MethodBuilder {
  let builder = MethodBuilder::new_main(self)
  self.builders.set(builder.name, builder)
  builder
}

fn WorldBuilder::create_method_builder(
  self : WorldBuilder,
  def : @closure.FuncDef
) -> MethodBuilder {
  let builder = MethodBuilder::new(self, def)
  self.builders.set(builder.name, builder)
  builder
}
