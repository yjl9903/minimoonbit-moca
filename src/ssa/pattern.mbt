typealias Pattern = @knf.Pattern

typealias LowType = @closure.LowType

fn MethodBuilder::visit_pattern_matching(
  self : MethodBuilder,
  expr : Name,
  patterns : Array[(Pattern, @closure.Expr)],
  cont : (RValue) -> Unit,
  ~visiting_loop : Bool = false
) -> Unit {
  let ctx = PatternContext::new(self)
  let expr = self.ssa_builder.get_var(expr)
  ctx.root.var = Some(expr)
  for i, pattern in patterns.iter2() {
    ctx.insert(pattern.0, i)
  }
  ctx.generate_block(ctx.root, expr)
}

struct PatternContext {
  mut counter : Int
  root : Node
  block_map : Map[Int, Int] // node_id -> node block_id
  backwrite_body_map : Map[Int, Int] // stmt_id -> body_id, backwrite to goto body_block_id
  backwrite_node_map : Map[Int, Int] // stmt_id -> body_id, backwrite to goto node_block_id
  method : MethodBuilder
}

/// 最后一个是加defaul的边 倒数第二个是通配符(Var)
enum Edge {
  Var((Name, Type)?, Node, Node?)
  Unit(Node, Node?, Node?)
  Bool(Node?, Node?, Node?, Node?)
  Ints(Array[(Int, Node)], Node?, Node?)
  Doubles(Array[(Double, Node)], Node?, Node?)
  Tuple(Node, Node?, Node?)
  Enums(Array[(@types.EnumDef, @types.EnumKind, Node)], Node?, Node?)
  Default
}

struct Node {
  id : Int
  mut var : Var?
  mut pos : Pos?
  mut is_leaf : Bool
  mut edges : Edge
  mut body : Int?
}

enum Pos {
  Tuple(Int)
  Enum(@types.EnumDef, @types.EnumKind, Int)
}

fn PatternContext::new(method : MethodBuilder) -> PatternContext {
  {
    counter: 1,
    root: {
      id: 0,
      var: None,
      pos: None,
      is_leaf: false,
      edges: Default,
      body: None,
    },
    block_map: Map::new(),
    backwrite_body_map: Map::new(),
    backwrite_node_map: Map::new(),
    method,
  }
}

fn PatternContext::new_node(self : PatternContext, pos : Pos?) -> Node {
  let node = {
    id: self.counter,
    var: None,
    pos,
    is_leaf: false,
    edges: Default,
    body: None,
  }
  self.counter += 1
  node
}

fn PatternContext::insert(
  self : PatternContext,
  pattern : Pattern,
  body_id : Int
) -> Unit {
  let mut node = self.root
  fn dfs(pattern : Pattern, pos : Pos?) -> Unit {
    match pattern {
      Unit => {
        node.edges = match node.edges {
          Default => Unit(self.new_node(pos), None, None)
          Var(_) | Unit(_) => node.edges
          _ => @util.die("Type Error")
        }
        // 如果先有 var 就走 var
        node = match node.edges {
          Var(_, exp, _) => exp
          Unit(lhs, _, _) => lhs
          _ => @util.die("Impossible")
        }
      }
      Bool(val) => {
        let mut next = None
        // 初始化
        node.edges = match node.edges {
          Default =>
            if val {
              Bool(Some(self.new_node(pos)), None, None, None)
            } else {
              Bool(None, Some(self.new_node(pos)), None, None)
            }
          Var(_) | Bool(_) => node.edges
          _ => @util.die("Type Error")
        }

        // 新加节点
        if val {
          node.edges = match node.edges {
            Bool(_, _, Some(_), _) => node.edges
            Bool(None, lhs, rhs, None) =>
              Bool(Some(self.new_node(pos)), lhs, rhs, None)
            _ => node.edges
          }
        } else {
          node.edges = match node.edges {
            Bool(_, _, Some(_), _) => node.edges
            Bool(lhs, None, rhs, None) =>
              Bool(lhs, Some(self.new_node(pos)), rhs, None)
            _ => node.edges
          }
        }
        next = match node.edges {
          Var(_, exp, None) => Some(exp)
          Bool(lhs, rhs, last, None) =>
            if val {
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
          _ => @util.die("unreachable")
        }
        node = match next {
          Some(v) => v
          None => @util.die("Impossible")
        }
      }
      Var(def, ty) => {
        // 如果之前有别的类型，就加对应的通配符
        node.edges = match node.edges {
          Default =>
            Var(
              def.map(fn { def => (def, @closure.to_closure_fn_low_type(ty)) }),
              self.new_node(pos),
              None,
            )
          Unit(lhs, None, None) => Unit(lhs, Some(self.new_node(pos)), None)
          Bool(lhs, rhs, None, None) =>
            Bool(lhs, rhs, Some(self.new_node(pos)), None)
          Ints(array, None, None) => Ints(array, Some(self.new_node(pos)), None)
          Doubles(array, None, None) =>
            Doubles(array, Some(self.new_node(pos)), None)
          Enums(array, None, None) =>
            Enums(array, Some(self.new_node(pos)), None)
          Tuple(val, None, None) => Tuple(val, Some(self.new_node(pos)), None)
          _ => node.edges
        }
        let next = match node.edges {
          Unit(_, Some(val), None) => val
          Bool(_, _, Some(val), None) => val
          Ints(_, Some(val), None) => val
          Doubles(_, Some(val), None) => val
          Enums(_, Some(val), None) => val
          Tuple(_, Some(val), None) => val
          Var(_, val, None) => val
          _ => @util.die("unreachable")
        }
        node = next
      }
      Int(val) => {
        node.edges = match node.edges {
          Var(_) | Ints(_) => node.edges
          Default => Ints([], None, None)
          _ => @util.die("Type Error")
        }
        let next = match node.edges {
          Var(_, exp, None) => exp
          Ints(array, defalut, None) => {
            let mut res = None
            for item in array {
              if item.0 == val {
                res = Some(item.1)
              }
            }
            if res.is_empty() {
              if defalut.is_empty() { // 如果通配符不在 新建一个节点
                let new_node = self.new_node(pos)
                array.push((val, new_node))
                node.edges = Ints(array, defalut, None)
                res = Some(new_node)
              } else {
                res = defalut // 通配符在走通配符
              }
            }
            res.unwrap()
          }
          _ => @util.die("unreachable")
        }
        node = next
      }
      Double(val) => {
        node.edges = match node.edges {
          Var(_) | Doubles(_) => node.edges
          Default => Doubles([], None, None)
          _ => @util.die("Type Error")
        }
        let next = match node.edges {
          Var(_, exp, None) => exp
          Doubles(array, defalut, None) => {
            let mut res = None
            for item in array {
              if item.0 == val {
                res = Some(item.1)
              }
            }
            if res.is_empty() {
              if defalut.is_empty() {
                let new_node = self.new_node(pos)
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
        node = next
      }
      Tuple(array) => {
        // Into Tuple Node
        node.edges = match node.edges {
          Default => Tuple(self.new_node(pos), None, None)
          Var(_) | Tuple(_) => node.edges
          _ => @util.die("Type Error")
        }
        let mut has_continuation = false
        let next = match node.edges {
          Var(_, exp, None) => exp
          Tuple(exp, _, None) => {
            has_continuation = true
            exp
          }
          _ => @util.die("unreachable")
        }
        node = next
        // flag 来判断走的是不是Tuple节点，走Var的就不需要展开
        if has_continuation {
          for depth, item in array.iter2() {
            dfs(item, Some(Pos::Tuple(depth)))
          }
        }
      }
      Enum(name, kind, array) => {
        // Into Tuple Node
        node.edges = match node.edges {
          Default => Enums([], None, None)
          Var(_) | Enums(_) => node.edges
          _ => @util.die("Type Error")
        }
        let mut has_continuation = false
        let next = match node.edges {
          Var(_, exp, None) => exp // 有通配符 后面就都不需要了
          Enums(array, defalut, None) => {
            has_continuation = true
            let mut res = None
            for item in array {
              if item.0 == name && item.1 == kind {
                res = Some(item.2)
              }
            }
            if res.is_empty() {
              if defalut.is_empty() {
                let new_node = self.new_node(pos)
                array.push((name, kind, new_node))
                node.edges = Enums(array, defalut, None)
                res = Some(new_node)
              } else {
                res = defalut
              }
            }
            res.unwrap()
          }
          _ => @util.die("unreachable")
        }
        node = next
        // has_continuation 来判断走的是不是Tuple节点，走Var的就不需要展开
        if has_continuation {
          for depth, item in array.iter2() {
            dfs(item, Some(Pos::Enum(name, kind, depth)))
          }
        }
      }
    }
  }

  dfs(pattern, None)
  // Leaf node
  node.body = Some(body_id)
  node.is_leaf = true
}

// 添加 一条default边，建立AC自动机
fn PatternContext::add_edge(
  _self : PatternContext,
  source : Node,
  target : Node
) -> Unit {
  source.edges = match source.edges {
    Var(def, var, None) => Var(def, var, Some(target))
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
fn PatternContext::add_default(self : PatternContext, root : Node) -> Unit {
  let mp : @hashmap.T[Int, Int] = @hashmap.new() // 存储 每个Node的 default的儿子
  let identifier : @hashmap.T[Int, Node] = @hashmap.new()
  let stack : Array[Int] = Array::new()
  fn dfs(node : Node) {
    identifier[node.id] = node
    stack.push(node.id)
    // 寻找到祖先中分叉的default
    for i = stack.length() - 2; i >= 0; i = i - 1 {
      if mp.contains(stack[i]) && mp[stack[i]].unwrap() != stack[i + 1] {
        self.add_edge(node, identifier[stack[i]].unwrap())
        break
      }
    }
    // 下面的 add_edge 是兄弟向default点连边
    match node.edges {
      Var(_, next, _) => {
        mp[node.id] = next.id
        dfs(next)
      }
      Unit(next_node, defalut_node, _) =>
        if defalut_node.is_empty() {
          dfs(next_node)
        } else {
          mp[node.id] = defalut_node.unwrap().id
          dfs(defalut_node.unwrap())
          self.add_edge(next_node, defalut_node.unwrap())
          dfs(next_node)
        }
      Bool(lhs, rhs, defalut_node, _) =>
        if defalut_node.is_empty() {
          if lhs.is_empty() {
            dfs(lhs.unwrap())
          }
          if rhs.is_empty() {
            dfs(rhs.unwrap())
          }
        } else {
          mp[node.id] = defalut_node.unwrap().id
          dfs(defalut_node.unwrap())
          if lhs.is_empty() {
            self.add_edge(lhs.unwrap(), defalut_node.unwrap())
            dfs(lhs.unwrap())
          }
          if rhs.is_empty() {
            self.add_edge(lhs.unwrap(), defalut_node.unwrap())
            dfs(rhs.unwrap())
          }
        }
      Ints(array, defalut_node, _) => {
        if defalut_node.is_empty() == false {
          mp[node.id] = defalut_node.unwrap().id
          dfs(defalut_node.unwrap())
        }
        array.each(
          fn {
            item => {
              if defalut_node.is_empty() == false {
                self.add_edge(item.1, defalut_node.unwrap())
              }
              dfs(item.1)
            }
          },
        )
      }
      Doubles(array, defalut_node, _) => {
        if defalut_node.is_empty() == false {
          mp[node.id] = defalut_node.unwrap().id
          dfs(defalut_node.unwrap())
        }
        array.each(
          fn {
            item => {
              if defalut_node.is_empty() == false {
                self.add_edge(item.1, defalut_node.unwrap())
              }
              dfs(item.1)
            }
          },
        )
      }
      Enums(array, defalut_node, _) => {
        if defalut_node.is_empty() == false {
          mp[node.id] = defalut_node.unwrap().id
          dfs(defalut_node.unwrap())
        }
        array.each(
          fn {
            item => {
              if defalut_node.is_empty() == false {
                self.add_edge(item.2, defalut_node.unwrap())
              }
              dfs(item.2)
            }
          },
        )
      }
      Tuple(next_node, defalut_node, _) =>
        if defalut_node.is_empty() {
          dfs(next_node)
        } else {
          mp[node.id] = defalut_node.unwrap().id
          dfs(defalut_node.unwrap())
          self.add_edge(next_node, defalut_node.unwrap())
          dfs(next_node)
        }
      Default => ()
    }
    let _ = stack.pop()
    ()
  }

  // DFS END
  let new_node = self.new_node(None)
  new_node.body = Some(-1)
  let default = match root.edges {
    Var(_, val, _) => val
    Ints(_, Some(val), _) => val
    Doubles(_, Some(val), _) => val
    Enums(_, Some(val), _) => val
    Unit(_, Some(val), _) => val
    Bool(_, _, Some(val), _) => val
    Tuple(_, Some(val), _) => val
    _ => new_node
  }
  mp[root.id] = default.id
  dfs(root)
}

fn PatternContext::generate_block(
  self : PatternContext,
  node : Node,
  expr : Var
) -> Unit {
  let new_block = self.method.ssa_builder.create_new_block()
  self.block_map.set(node.id, new_block.label)
  let expr = match node.pos {
    Some(Tuple(idx)) => {
      let els_ty = @closure.extract_tuple_type(expr.ty)
      let el_ty = els_ty[idx]
      let tmp = self.method.ssa_builder.add_local_temp_var(el_ty)
      let _ = self.method.ssa_builder.emit(
        Definition(Some(tmp), GetTuple(expr, idx)),
      )
      tmp
    }
    Some(Enum(name, kind, idx)) => {
      let el_ty = @closure.to_closure_fn_low_type(kind.fields[idx])
      let tmp = self.method.ssa_builder.add_local_temp_var(el_ty)
      let _ = self.method.ssa_builder.emit(
        Definition(Some(tmp), GetEnum(name, kind, expr, idx)),
      )
      tmp
    }
    None => expr
  }
  match node.edges {
    Var(def, child, _fail) => {
      let goto = self.method.ssa_builder.emit(Goto(-1))
      match def {
        Some(def) => {
          let def = self.method.ssa_builder.add_local_var(def.0, def.1)
          let _ = self.method.ssa_builder.emit(
            Definition(Some(def), RValue::Var(expr)),
          )
          ()
        }
        None => ()
      }
      self.backwrite_body_map.set(goto.slot, child.body.unwrap())
      ()
    }
    Tuple(child, _default, _fail) => {
      let goto = self.method.ssa_builder.emit(Goto(-1))
      self.backwrite_node_map.set(goto.slot, child.id)
      // 
      self.generate_block(child, expr)
      // 
    }
    Unit(child, _default, _fail) => {
      let goto = self.method.ssa_builder.emit(Goto(-1))
      self.backwrite_body_map.set(goto.slot, child.body.unwrap())
      ()
    }
    Bool(true_branch, false_branch, default, fail) => {
      // new block -> if expr == 1 { ... } else { ... }
      let if_stmt = self.method.ssa_builder.emit(Nop)
      let backwrite_default = []

      // true block -> goto true_body
      let true_block = self.method.ssa_builder.create_new_block()
      match true_branch {
        Some(true_child) => {
          let goto = self.method.ssa_builder.emit(Goto(-1))
          self.backwrite_body_map.set(goto.slot, true_child.body.unwrap())
        }
        None => {
          let goto_default = self.method.ssa_builder.emit(Goto(-1))
          backwrite_default.push(goto_default)
          ()
        }
      }

      // false block -> goto false body
      let false_block = self.method.ssa_builder.create_new_block()
      match false_branch {
        Some(false_child) => {
          let goto = self.method.ssa_builder.emit(Goto(-1))
          self.backwrite_body_map.set(goto.slot, false_child.body.unwrap())
        }
        None => {
          let goto_default = self.method.ssa_builder.emit(Goto(-1))
          backwrite_default.push(goto_default)
          ()
        }
      }

      // backwrite if goto
      if_stmt.update(
        IfGoto(
          Eq(expr, self.method.ssa_builder.get_const_one()),
          Some(true_block.label),
          Some(false_block.label),
          None,
        ),
      )

      // default branch
      let default_block = self.method.ssa_builder.create_new_block()
      match default {
        Some(default_branch) => {
          let goto = self.method.ssa_builder.emit(Goto(-1))
          self.backwrite_body_map.set(goto.slot, default_branch.id)
          ()
        }
        None => {
          let fail_branch = fail.unwrap()
          let goto = self.method.ssa_builder.emit(Goto(-1))
          self.backwrite_body_map.set(goto.slot, fail_branch.id)
          ()
        }
      }
      backwrite_default.each(
        fn { stmt => stmt.update(Goto(default_block.label)) },
      )
    }
    Ints(children, default, fail) => @util.die("todo")
    Doubles(children, defalut, fail) => @util.die("todo")
    Enums(child, default, fail) => @util.die("todo")
    Default => ()
  }
}
