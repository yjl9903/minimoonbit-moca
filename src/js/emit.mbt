pub fn emit(world : @ssa.World) -> JsResult {
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
  stmts : Array[String]
  labels : Map[Int, String]
  merged : Map[Int, @ssa.Var]
}

fn JsEmitter::push(self : JsEmitter, stmt : String) -> Unit {
  if stmt.length() != 0 {
    if stmt.ends_with("}") || stmt.ends_with("{") {
      self.stmts.push("  " + stmt)
    } else {
      self.stmts.push("  " + stmt + ";")
    }
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
  let emitter = JsEmitter::{
    method,
    stmts: [],
    labels: Map::new(),
    merged: Map::new(),
  }
  let params = method.params.map(fn { a => emitter.emit_var(a) }).join(", ")
  let def_start = if is_main {
    "export default function () {\n"
  } else {
    "function \{get_method_name(method.name)}(\{params}) {\n"
  }
  let def_end = "\n}"

  // 1. Def local vars
  let def_vars = method.local_vars.filter(
    fn { v => not(v.is_param) && v.const_value.is_empty() },
  )
  if def_vars.length() > 0 {
    emitter.push(
      "let " + def_vars.map(fn { v => emitter.emit_var(v) }).join(", "),
    )
  }

  // 2. Analyze phi and label
  for i = 0; i < method.body.length(); i = i + 1 {
    let stmt = method.body[i]
    match stmt.stmt {
      Definition(Some(var), Phi(merged)) =>
        merged.each(fn { m => emitter.merged.set(m.id, var) })
      // IfGoto(_, true_target, false_target) => {
      //   match true_target {
      //     Some(t) => emitter.labels.set(t, "L\{t}")
      //     None => ()
      //   }
      //   match false_target {
      //     Some(t) => emitter.labels.set(t, "L\{t}")
      //     None => ()
      //   }
      // }
      // Goto(t) => emitter.labels.set(t, "L\{t}")
      _ => ()
    }
  }

  // 3. Print stmts
  for i = 0; i < method.body.length(); i = i + 1 {
    let stmt = method.body[i]
    let stmt = emitter.emit_method_stmt(stmt)
    let label = emitter.labels.get(i)
    match label {
      Some(label) => emitter.push(label)
      None => ()
    }
    emitter.push(stmt)
  }

  // 3. Concat stmts
  def_start + emitter.to_string() + def_end
}

fn JsEmitter::emit_method_stmt(self : JsEmitter, stmt : @ssa.Stmt) -> String {
  match stmt.stmt {
    Definition(_, Phi(_)) => ""
    Definition(Some(var), rvalue) =>
      if var.const_value.is_empty() {
        "\{self.emit_var(var)} = \{self.emit_method_rvalue(rvalue)}"
      } else {
        ""
      }
    Definition(None, rvalue) => self.emit_method_rvalue(rvalue)
    PutArray(recv, idx, expr) =>
      "\{self.emit_var(recv)}[\{self.emit_var(idx)}] = \{self.emit_var(expr)}"
    Goto(_) => "}"
    IfGoto(cond, _, false_target) => {
      self.labels.set(false_target.unwrap(), "else {")
      let cond = match cond {
        Eq(lhs, rhs) => "\{self.emit_var(lhs)} === \{self.emit_var(rhs)}"
        Le(lhs, rhs) => "\{self.emit_var(lhs)} <= \{self.emit_var(rhs)}"
      }
      "if (\{cond}) {"
    }
    Nop => ""
    Return(var) => "return \{self.emit_var(var)}"
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
