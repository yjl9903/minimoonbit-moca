pub typealias LocalEnv = @immut/hashmap.T[String, Type]

pub let knf_counter : Ref[Int] = { val: 1 }

struct KnfEnv {
  mut env : @immut/hashmap.T[String, (Name, Type)]
  externals : @immut/hashmap.T[String, Type]
}

enum Edge { // 最后一个是加defaul的边 倒数第二个是通配符(Var)
  Ints(Array[(Int, Node)], Node?, Node?)
  Doubles(Array[(Double, Node)], Node?, Node?)
  Unit(Node, Node?, Node?)
  Bool(Node?, Node?, Node?, Node?)
  Tuple(Node, Node?, Node?)
  Enums(Array[(String, String, Node)], Node?, Node?)
  Var(Node, Node?)
  Default
}

struct Node {
  mut edges : Edge
  mut syntax : @types.Syntax?
  vars : Array[String]
  id : Int
  mut leaf : Bool
}

pub let node_counter : Ref[Int] = { val: 0 }

fn Node::new() -> Node {
  let node = {
    edges: Default,
    syntax: None,
    vars: [],
    id: node_counter.val,
    leaf: false,
  }
  node_counter.val += 1
  node
}

fn insert(root : Node, pattern : Pattern, syntax : @types.Syntax) -> Unit {
  let mut node = root
  let vars : Array[String] = Array::new()
  fn dfs(root : Node, pattern : Pattern, prefix : String, index : Int) -> Unit {
    match pattern {
      Unit => {
        vars.push(prefix + index.to_string())
        node.edges = match node.edges {
          Default => Unit(Node::new(), None, None)
          Var(_) | Unit(_) => node.edges
          _ => @util.die("Type Error")
        }
        // 如果先有var 就走 var
        node = match node.edges {
          Var(exp, _) => exp
          Unit(lhs, _, _) => lhs
          _ => @util.die("Impossible")
        }
      }
      Bool(val) => {
        vars.push(prefix + index.to_string())
        let mut next = None
        // 初始化
        node.edges = match node.edges {
          Default =>
            if val == false {
              Bool(Some(Node::new()), None, None, None)
            } else {
              Bool(None, Some(Node::new()), None, None)
            }
          Var(_) | Bool(_) => node.edges
          _ => @util.die("Type Error")
        }

        // 新加节点
        if val == false {
          node.edges = match node.edges {
            Bool(_, _, Some(val), _) => node.edges
            Bool(None, lhs, rhs, None) =>
              Bool(Some(Node::new()), lhs, rhs, None)
            _ => node.edges
          }
        } else {
          node.edges = match node.edges {
            Bool(_, _, Some(val), _) => node.edges
            Bool(lhs, None, rhs, None) =>
              Bool(lhs, Some(Node::new()), rhs, None)
            _ => node.edges
          }
        }
        next = match node.edges {
          Var(exp, None) => Some(exp)
          Bool(lhs, rhs, last, None) =>
            if val == false {
              if lhs.is_empty() {
                last
              } else {
                lhs
              }
            } else if rhs.is_empty() {
              last
            } else {
              rhs
            }
        }
        node = match next {
          Some(v) => v
          None => @util.die("Impossible")
        }
      }
      Var(name, ty) => {
        if name.is_empty() == false {
          vars.push(prefix + index.to_string())
        }
        // 如果之前有别的类型，就加对应的通配符
        node.edges = match node.edges {
          Default => Var(Node::new(), None)
          Unit(lhs, None, None) => Unit(lhs, Some(Node::new()), None)
          Bool(lhs, rhs, None, None) => Bool(lhs, rhs, Some(Node::new()), None)
          Ints(array, None, None) => Ints(array, Some(Node::new()), None)
          Doubles(array, None, None) => Doubles(array, Some(Node::new()), None)
          Enums(array, None, None) => Enums(array, Some(Node::new()), None)
          Tuple(val, None, None) => Tuple(val, Some(Node::new()), None)
          _ => node.edges
        }
        let next = match node.edges {
          Unit(_, Some(val), None) => val
          Bool(_, _, Some(val), None) => val
          Ints(_, Some(val), None) => val
          Doubles(_, Some(val), None) => val
          Enums(_, Some(val), None) => val
          Tuple(_, Some(val), None) => val
          Var(val, None) => val
        }
        node = next
      }
      Int(val) => {
        vars.push(prefix + index.to_string())
        node.edges = match node.edges {
          Var(_) | Ints(_) => node.edges
          Default => Ints(Array::new(), None, None)
          _ => @util.die("Type Error")
        }
        let next = match node.edges {
          Var(exp, None) => exp
          Ints(array, defalut, None) => {
            let mut res = None
            for item in array {
              if item.0 == val {
                res = Some(item.1)
              }
            }
            if res.is_empty() {
              if defalut.is_empty() { // 如果通配符不在 新建一个节点
                let new_node = Node::new()
                array.push((val, new_node))
                node.edges = Ints(array, defalut, None)
                res = Some(new_node)
              } else {
                res = defalut // 通配符在走通配符
              }
            }
            res.unwrap()
          }
          _ => @util.die("Impossible")
        }

      }
      Double(val) => {
        vars.push(prefix + index.to_string())
        node.edges = match node.edges {
          Var(_) | Doubles(_) => node.edges
          Default => Doubles(Array::new(), None, None)
          _ => @util.die("Type Error")
        }
        let next = match node.edges {
          Var(exp, None) => exp
          Doubles(array, defalut, None) => {
            let mut res = None
            for item in array {
              if item.0 == val {
                res = Some(item.1)
              }
            }
            if res.is_empty() {
              if defalut.is_empty() {
                let new_node = Node::new()
                array.push((val, new_node))
                node.edges = Doubles(array, defalut, None)
                res = Some(new_node)
              } else {
                res = defalut
              }
            }
            res.unwrap()
          }
          _ => @util.die("Impossible")
        }

      }
      Tuple(array) => {
        // Into Tuple Node
        let mut new_index = 0
        node.edges = match node.edges {
          Default => Tuple(Node::new(), None, None)
          Var(_) | Tuple(_) => node.edges
          _ => @util.die("Type Error")
        }
        let mut flag = false
        let next = match node.edges {
          Var(exp, None) => exp
          Tuple(exp, _, None) => {
            flag = true
            exp
          }
        }
        node = next
        // flag 来判断走的是不是Tuple节点，走Var的就不需要展开
        if flag {
          for item in array {
            dfs(node, item, get_tuple_name(), new_index)
            new_index += 1
          }
        }
      }
      Enum(lhs, rhs, array) => {
        // Into Tuple Node
        let mut new_index = 0
        node.edges = match node.edges {
          Default => Tuple(Node::new(), None, None)
          Var(_) | Enums(_) => node.edges
          _ => @util.die("Type Error")
        }
        let mut flag = false
        let next = match node.edges {
          Var(exp, None) => exp // 有通配符 后面就都不需要了
          Enums(array, defalut, None) => {
            let mut res = None
            for item in array {
              if item.0 == lhs && item.1 == rhs {
                res = Some(item.2)
              }
            }
            if res.is_empty() {
              if defalut.is_empty() {
                let new_node = Node::new()
                array.push((lhs, rhs, new_node))
                node.edges = Enums(array, defalut, None)
                res = Some(new_node)
              } else {
                res = defalut
              }
            }
            res.unwrap()
          }
        }
        node = next
        // flag 来判断走的是不是Tuple节点，走Var的就不需要展开
        if flag {
          for item in array {
            dfs(node, item, get_Enum_name(), new_index)
            new_index += 1
          }
        }
      }
    }
  }

  dfs(root, pattern, "temp", 0)
  node.syntax = Some(syntax)
  node.vars.append(vars)
  node.leaf = true
}

//添加 一条default边，建立AC自动机
fn add_edge(source : Node, target : Node, edge : Edge) -> Unit {
  source.edges = match source.edges {
    Var(var, None) => Var(var, Some(target))
    Unit(lhs, rhs, None) => Unit(lhs, rhs, Some(target))
    Bool(lhs, rhs, exp, None) => Bool(lhs, rhs, exp, Some(target))
    Ints(array, exp, None) => Ints(array, exp, Some(target))
    Doubles(array, exp, None) => Doubles(array, exp, Some(target))
    Tuple(expr, exp, None) => Tuple(expr, exp, Some(target))
    Enums(array, exp, None) => Enums(array, exp, Some(target))
    _ => source.edges
  }
}

// 添加default边
fn add_default(root : Node) -> Unit {
  let mut mp : @hashmap.T[Int, Int] = @hashmap.new() // 存储 每个Node的 default的儿子
  let mut identifier : @hashmap.T[Int, Node] = @hashmap.new()
  let stack : Array[Int] = Array::new()
  fn dfs(node : Node, is_default : Bool) {
    identifier[node.id] = node
    stack.push(node.id)
    // 寻找到祖先中分叉的default
    for i = stack.length() - 2; i >= 0; i = i - 1 {
      if mp.contains(stack[i]) && mp[stack[i]].unwrap() != stack[i + 1] {
        add_edge(node, identifier[stack[i]].unwrap(), Default)
        break
      }
    }
    // 下面的 add_edge 是兄弟向default点连边
    match node.edges {
      Var(next, _) => {
        mp[node.id] = next.id
        dfs(next, true)
      }
      Unit(next_node, defalut_node, _) =>
        if defalut_node.is_empty() {
          dfs(next_node, false)
        } else {
          mp[node.id] = defalut_node.unwrap().id
          dfs(defalut_node.unwrap(), true)
          add_edge(next_node, defalut_node.unwrap(), Edge::Default)
          dfs(next_node, false)
        }
      Bool(lhs, rhs, defalut_node, _) =>
        if defalut_node.is_empty() {
          if lhs.is_empty() {
            dfs(lhs.unwrap(), false)
          }
          if rhs.is_empty() {
            dfs(rhs.unwrap(), false)
          }
        } else {
          mp[node.id] = defalut_node.unwrap().id
          dfs(defalut_node.unwrap(), true)
          if lhs.is_empty() {
            add_edge(lhs.unwrap(), defalut_node.unwrap(), Edge::Default)
            dfs(lhs.unwrap(), false)
          }
          if rhs.is_empty() {
            add_edge(lhs.unwrap(), defalut_node.unwrap(), Edge::Default)
            dfs(rhs.unwrap(), false)
          }
        }
      Ints(array, defalut_node, _) => {
        if defalut_node.is_empty() == false {
          mp[node.id] = defalut_node.unwrap().id
          dfs(defalut_node.unwrap(), true)
        }
        array.each(
          fn {
            item => {
              if defalut_node.is_empty() == false {
                add_edge(item.1, defalut_node.unwrap(), Edge::Default)
              }
              dfs(item.1, false)
            }
          },
        )
      }
      Doubles(array, defalut_node, _) => {
        if defalut_node.is_empty() == false {
          mp[node.id] = defalut_node.unwrap().id
          dfs(defalut_node.unwrap(), true)
        }
        array.each(
          fn {
            item => {
              if defalut_node.is_empty() == false {
                add_edge(item.1, defalut_node.unwrap(), Edge::Default)
              }
              dfs(item.1, false)
            }
          },
        )
      }
      Enums(array, defalut_node, _) => {
        if defalut_node.is_empty() == false {
          mp[node.id] = defalut_node.unwrap().id
          dfs(defalut_node.unwrap(), true)
        }
        array.each(
          fn {
            item => {
              if defalut_node.is_empty() == false {
                add_edge(item.2, defalut_node.unwrap(), Edge::Default)
              }
              dfs(item.2, false)
            }
          },
        )
      }
      Tuple(next_node, defalut_node, _) =>
        if defalut_node.is_empty() {
          dfs(next_node, false)
        } else {
          mp[node.id] = defalut_node.unwrap().id
          dfs(defalut_node.unwrap(), true)
          add_edge(next_node, defalut_node.unwrap(), Edge::Default)
          dfs(next_node, false)
        }
    }
    let _ = stack.pop()

  }

  // DFS END
  let new_node = Node::new()
  new_node.syntax = Some(Var("Unreachable"))
  let default = match root.edges {
    Var(val, _) => val
    Ints(_, Some(val), _) => val
    Doubles(_, Some(val), _) => val
    Enums(_, Some(val), _) => val
    Unit(_, Some(val), _) => val
    Bool(_, _, Some(val), _) => val
    Tuple(_, Some(val), _) => val
    _ => new_node
  }
  mp[root.id] = default.id
  dfs(root, false)
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
  self.visit_top_level_defs(syntax)
}

enum TopLevel {
  Let((Name, Type), Knf)
  LetRec(FuncDef)
  Init(Knf)
  Main(Knf)
}

fn KnfEnv::visit_top_level_defs(self : KnfEnv, syntax : @types.Syntax) -> Knf {
  let inits : Array[TopLevel] = []
  fn visitor(syntax : @types.Syntax) {
    match syntax {
      Unit => Knf::Unit
      Let((name, typ), expr, rest) => {
        let (expr, _) = self.fork().visit_expr(expr)
        let name = self.new_let_binding(name, typ)
        inits.push(Let((name, typ), expr))
        visitor(rest)
      }
      LetEnum(def, rest) => {
        enum_defs.enums.set(def.name, def)
        visitor(rest)
      }
      LetRec(def, rest) =>
        match def.name.0 {
          "init" => {
            let (body, _) = self.fork().visit_stmt(def.body)
            inits.push(Init(body))
            visitor(rest)
          }
          "main" => {
            let main_body = self.fork().visit_stmt(def.body).0
            inits.push(Main(main_body))
            visitor(rest)
          }
          _ => {
            let funcdef = self.visit_let_rec(def)
            inits.push(LetRec(funcdef))
            visitor(rest)
          }
        }
      _ => @util.die("Unexpected node under global context")
    }
  }

  self.bind_global_const(
    fn() {
      let _ = visitor(syntax)
      let main = inits.filter(
        fn {
          t =>
            match t {
              Main(_) => true
              _ => false
            }
        },
      )
      if main.length() == 1 {
        let main = match main[0] {
          Main(body) => body
          _ => @util.die("unreachable")
        }
        inits.rev_fold(
          fn {
            acc, top =>
              match top {
                Let(binding, expr) => Let(binding, expr, acc)
                LetRec(func) => LetRec(func, acc)
                Init(init_body) => {
                  let temp = new_temp()
                  Knf::Let((temp, Unit), init_body, acc)
                }
                Main(_) => acc // skip main
              }
          },
          init=main,
        )
      } else {
        @util.die("Found many or zero main function")
      }
    },
  )
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
  // Validate
  if extract_params_type(def.name.1).length() != def.args.length() {
    @util.die("invalid let rec binding")
  } else {
    let targs = extract_params_type(def.name.1)
    let dargs = def.args
    for i = 0; i < targs.length(); i = i + 1 {
      match @typing.unify?(targs[i], dargs[i].1) {
        Ok(_) => ()
        Err(_) => @util.die("type mismatch")
      }
    }
  }

  // ----
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
    LetEnum(_, rest) => self.visit_stmt(rest)
    LetRec(def, rest) => {
      let funcdef = self.visit_let_rec(def)
      let (rest, rest_type) = self.visit_stmt(rest)
      (Knf::LetRec(funcdef, rest), rest_type)
    }
    LetTuple(names, expr, rest) =>
      self.to_let_temp(
        expr,
        fn {
          (expr, _) => {
            let bindings = names.map(
              fn { (name, typ) => (self.new_let_binding(name, typ), typ) },
            )
            let (rest, rest_type) = self.visit_stmt(rest)
            (Knf::LetTuple(bindings, expr, rest), rest_type)
          }
        },
      )
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
    Enum(name, kind, args) =>
      /// let a_0 = args[0] in
      ///   let a_1 = args[1] in
      ///     ...
      ///       Enum(name, kind, [a_0, a_1, ...])
      self.to_let_temps(
        args,
        fn {
          names =>
            match enum_defs.get_def(name) {
              Some(def) =>
                match def.get_kind(kind) {
                  Some(kind) =>
                    (Enum(def, kind, names.map(fn { n => n.0 })), Enum(name))
                  None => @util.die("unknown enum \{name}::\{kind}")
                }
              None => @util.die("unknown enum \{name}::\{kind}")
            }
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
                let (true_branch, true_type) = self
                  .fork()
                  .visit_stmt(true_branch)
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
                let (true_branch, true_type) = self
                  .fork()
                  .visit_stmt(true_branch)
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
                let (true_branch, true_type) = self
                  .fork()
                  .visit_stmt(true_branch)
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
    Match(expr, pats) => {
      let mut match_typ = Type::Var({ val: None })
      self.to_let_temp(
        expr,
        fn {
          expr => {
            let bodys = pats.map(
              fn {
                pat => {
                  let vars = @types.extract_vars(pat.0)
                  let new_env = self.fork()
                  let args = vars.map(
                    fn {
                      (name, typ) => (new_env.new_let_binding(name, typ), typ)
                    },
                  )
                  let (body, body_typ) = new_env.visit_stmt(pat.1)
                  match @typing.unify?(match_typ, body_typ) {
                    Ok(typ) => match_typ = typ
                    Err(_) => @util.die("Unknown match expr type")
                  }
                  (pat.0, args, body)
                }
              },
            )
            (Match(expr.0, bodys), match_typ)
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
    LetEnum(_) => self.visit_stmt(syntax)
    LetRec(_) => self.visit_stmt(syntax)
    LetTuple(_) => self.visit_stmt(syntax)
  }
}
