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
    slot: self.global_vars_counter,
    ty: typ,
    is_this: false,
    is_param: false,
    is_global: true,
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
  def.is_closure = false
  def.formal_free_vars = []
  self.global_funs.set(closure.name._, def)
  self.direct_closure.set(name, def)
}

pub fn WorldBuilder::build(
  self : WorldBuilder,
  prog : @closure.Program
) -> World {
  // Collect all functions
  prog.fundefs.each(fn { f => self.all_funs.set(f.name._, f) })
  // 1. Build top-level expr
  let main_expr = self.build_top_level(prog.body)
  // 2. Prepare all the method builders
  let main_method_builder = self.create_main_method_builder()
  let method_builders = prog.fundefs.map(
    fn { def => (def, self.create_method_builder(def)) },
  )
  // 3. Build all the method
  let main_method = main_method_builder.build(main_expr)
  let methods = method_builders.map(
    fn { (def, builder) => (def.id, builder.build(def.body)) },
  )
  // 4. Create the world
  let world : World = {
    global: @hashset.new(),
    methods: Map::from_array(methods),
    main_method,
  }
  set_world(world)
  world
}

fn WorldBuilder::build_top_level(
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
    IfEq(lhs, rhs, true_branch, false_branch) =>
      IfEq(
        lhs,
        rhs,
        self.build_top_level(true_branch),
        self.build_top_level(false_branch),
      )
    IfLe(lhs, rhs, true_branch, false_branch) =>
      IfLe(
        lhs,
        rhs,
        self.build_top_level(true_branch),
        self.build_top_level(false_branch),
      )

    // Call
    CallDirect(_) => expr
    CallClosure(name, args) =>
      match self.direct_closure.get(name) {
        Some(def) => CallDirect(def.name, args)
        None => CallClosure(name, args)
      }

    // Let
    MakeClosure((name, typ), closure, rest) => {
      let def = self.get_func_def(closure.name)
      closure.actual_free_vars.eachi(
        fn { i, name => self.add_global_var(name, def.args[i].1) },
      )
      self.add_global_fun(name, closure)
      MakeClosure(
        (name, typ),
        { name: closure.name, actual_free_vars: [] },
        self.build_top_level(rest),
      )
    }
    Let((name, typ), expr, rest) =>
      Let((name, typ), expr, self.build_top_level(rest))
    LetTuple(els, expr, rest) => LetTuple(els, expr, self.build_top_level(rest))
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
