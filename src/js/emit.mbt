pub fn emit_js(world : @ssa.World) -> JsResult {
  let result = { definitions: [], main_method: "" }
  result.definitions.push_iter(emit_global(world).iter())
  world.methods.each(
    fn { _, method => result.definitions.push(emit_method(world, method)) },
  )
  result.main_method = emit_method(world, world.main_method, is_main=true)
  result
}

fn emit_global(world : @ssa.World) -> Array[String] {
  world.global
  .filter(fn { v => v.const_value.is_empty() })
  .map(fn { v => "let \{v.to_string()};" })
}

struct JsEmitter {
  method : @ssa.Method
  local_vars : Array[@ssa.Var]
  stmts : Array[String]
  merged : Map[Int, @ssa.Var]
}

fn JsEmitter::new(method : @ssa.Method) -> JsEmitter {
  let emitter = JsEmitter::{
    method,
    local_vars: [],
    stmts: [],
    merged: Map::new(),
  }
  // 1. Build merged vars
  for i = 0; i < method.body.stmts.length(); i = i + 1 {
    let stmt = method.body.stmts[i]
    match stmt.stmt {
      Definition(Some(var), Phi(merged)) => {
        let var = match emitter.merged.get(var.id) {
          Some(v) => v
          _ => var
        }
        merged.each(fn { m => emitter.merged.set(m.id, var) })
      }
      _ => ()
    }
  }
  // 2. Build local vars
  let local_vars = method.local_vars
    .filter(
      fn {
        v =>
          if not(v.is_param) && v.const_value.is_empty() {
            match emitter.merged.get(v.id) {
              Some(m) => m.id == v.id
              None => true
            }
          } else {
            false
          }
      },
    )
    .iter()
  emitter.local_vars.push_iter(local_vars.iter())
  emitter
}

fn JsEmitter::push(self : JsEmitter, stmt : String) -> Unit {
  if stmt.length() != 0 {
    self.stmts.push("  " + stmt)
  }
}

fn JsEmitter::to_string(self : JsEmitter) -> String {
  self.stmts.join("\n")
}

fn emit_method(
  _world : @ssa.World,
  method : @ssa.Method,
  ~is_main : Bool = false
) -> String {
  let emitter = JsEmitter::new(method)
  let params = method.params.map(fn { a => emitter.emit_var(a) }).join(", ")
  let def_start = if is_main {
    "export default function () {\n"
  } else {
    "function \{get_method_name(method.name)}(\{params}) {\n"
  }
  let def_end = "\n}"

  // 1. Def local vars
  if emitter.local_vars.length() > 0 {
    emitter.push(
      "let " +
      emitter.local_vars.map(fn { v => emitter.emit_var(v) }).join(", ") +
      ";",
    )
  }

  // 2. Print stmts
  emitter.emit_block(method.body.blocks[0])

  // 3. Concat stmts
  def_start + emitter.to_string() + def_end
}

fn JsEmitter::emit_block(self : JsEmitter, block : @ssa.Block) -> Unit {
  // Last stmt
  // let stmt = block.stmts[block.stmts.length() - 1]
  for i = 0; i < block.stmts.length(); i = i + 1 {
    let stmt = block.stmts[i]
    match stmt.stmt {
      IfGoto(cond, true_target, false_target, merge_target) => {
        let cond = match cond {
          Eq(lhs, rhs) => "\{self.emit_var(lhs)} === \{self.emit_var(rhs)}"
          Le(lhs, rhs) => "\{self.emit_var(lhs)} <= \{self.emit_var(rhs)}"
        }
        self.push("if (\{cond}) {")
        match true_target {
          Some(t) => self.emit_block(self.method.body.blocks[t])
          _ => ()
        }
        self.push("} else {")
        match false_target {
          Some(t) => self.emit_block(self.method.body.blocks[t])
          _ => ()
        }
        self.push("}")
        match merge_target {
          Some(t) => self.emit_block(self.method.body.blocks[t])
          _ => ()
        }
        break
      }
      Goto(_) => break // if () { ... } else { ... }
      Break(loop_label, _) => {
        // break B_;
        self.push("break B\{loop_label};")
        break
      }
      Continue(loop_label) => {
        // continue B_;
        self.push("continue B\{loop_label};")
        break
      }
      Return(var) => {
        // return _;
        self.push("return \{self.emit_var(var)};")
        break
      }
      _ => {
        // Not a control flow ir
        self.push(self.emit_method_stmt(stmt))
        if i + 1 == block.stmts.length() {
          match block.succ {
            Some(edge) =>
              match edge {
                Next(block) => self.emit_block(block)
                While(loop_block, return_block) => {
                  // Start a while loop
                  let label = loop_block.label
                  self.push("B\{label}: while (true) {")
                  self.emit_block(loop_block)
                  self.push("}")
                  self.emit_block(return_block)
                }
                // The end of a if branch, stop building following
                IfEnd(_) => ()
                Break(_) => @util.die("unexpected break")
                Continue(_) => @util.die("unexpected continue")
                IfStart(_) => @util.die("unexpected if branch")
              }
            None => ()
          }
        }
      }
    }
  }
}

fn JsEmitter::emit_method_stmt(self : JsEmitter, stmt : @ssa.Stmt) -> String {
  match stmt.stmt {
    Definition(_, Phi(_)) => ""
    Definition(Some(var), rvalue) =>
      if var.const_value.is_empty() {
        "\{self.emit_var(var)} = \{self.emit_method_rvalue(rvalue)};"
      } else {
        ""
      }
    Definition(None, rvalue) => self.emit_method_rvalue(rvalue)
    PutArray(recv, idx, expr) =>
      "\{self.emit_var(recv)}[\{self.emit_var(idx)}] = \{self.emit_var(expr)};"
    Nop => ""
    Goto(_) => @util.die("unexpected")
    Break(_) => @util.die("unexpected")
    Continue(_) => @util.die("unexpected")
    IfGoto(_) => @util.die("unexpected")
    Return(_) => @util.die("unexpected")
  }
}

fn JsEmitter::emit_method_rvalue(
  self : JsEmitter,
  rvalue : @ssa.RValue
) -> String {
  match rvalue {
    Unit => "undefined"
    Int(x) => x.to_string()
    Double(x) => x.to_string()
    Prim(lhs, rhs, op, _) =>
      self.emit_var(lhs) + " " + op.to_string() + " " + self.emit_var(rhs)
    Neg(expr, _) => "-" + self.emit_var(expr)
    Var(var) => self.emit_var(var)
    Tuple(els) => {
      let els = els.map(fn { e => self.emit_var(e) }).join(", ")
      "[\{els}]"
    }
    Closure(label, bindings) => {
      let name = get_method_name(label)
      let bindings = bindings
        .map(fn { (fv, var) => "\"\{fv.to_string()}\": \{self.emit_var(var)}" })
        .join(", ")
      "\{name}.bind({\{bindings}})"
    }

    // Get from structure
    GetTuple(var, idx) => "\{self.emit_var(var)}[\{idx}]"
    GetArray(recv, idx) => "\{self.emit_var(recv)}[\{self.emit_var(idx)}]"
    GetClosure(closure, fv) =>
      if closure.is_this {
        "this[\"\{fv.to_string()}\"]"
      } else {
        @util.die("")
      }

    // Invoke
    InvokeClosure(callee, args) => {
      let args = args.map(fn { a => self.emit_var(a) }).join(", ")
      "\{self.emit_var(callee)}(\{args})"
    }
    InvokeDirect(label, args) => {
      let args = args.map(fn { a => self.emit_var(a) }).join(", ")
      "\{get_method_name(label)}(\{args})"
    }

    // Phi
    Phi(_) => ""
  }
}

fn JsEmitter::emit_var(self : JsEmitter, var : @ssa.Var) -> String {
  match var.const_value {
    Some(Int(x)) => x.to_string()
    Some(Double(x)) => x.to_string()
    _ => {
      let merged = self.merged.get(var.id)
      let var = merged.or(var)
      if var.is_this {
        if self.method.formal_free_vars.length() > 0 {
          get_method_name(self.method.name) + ".bind(this)"
        } else {
          get_method_name(self.method.name)
        }
      } else if var.is_global {
        var.to_string()
      } else {
        "_" + var.id.to_string()
      }
    }
  }
}
