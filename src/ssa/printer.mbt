pub fn World::print(self : World) -> Unit {
  self.global.each(
    fn {
      v => {
        println("let \{v} : \{v.ty};")
        println("")
      }
    },
  )
  self.methods
  .values()
  .each(
    fn {
      method => {
        method.print()
        println("")
      }
    },
  )
  let main_method = self.main_method
  main_method.print()
}

pub fn Method::print(self : Method) -> Unit {
  // 1. Signature
  let params = self.params
    .map(fn { p => "\{p.to_string()} : \{p.ty}" })
    .join(", ")
  let ret_type = @closure.extract_return_type(self.ty)
  println("fn \{self.name} (\{params}) -> \{ret_type} {")

  // 2. Closure
  if self.formal_free_vars.length() > 0 {
    println("  closure {")
    self.formal_free_vars.each(
      fn { fv => println("    \{fv.to_string()} : \{fv.ty}") },
    )
    println("  }")
  }

  // 3. Stmts
  // let pad_len = self.body.stmts.fold(
  //   fn { len, stmt => @math.maximum(len, stmt.slot.to_string().length()) },
  //   init=1,
  // )
  let labels = self.body.labels()
  self.body.stmts.each(
    fn {
      stmt => {
        if labels.size() > 1 {
          match labels.get(stmt.slot) {
            Some(block) => println("B\{block.label}:")
            None => ()
          }
        }
        println("  \{self.print_stmt(stmt.stmt)}")
      }
    },
  )
  println("}")
}

fn Method::print_stmt(self : Method, stmt : StmtKind) -> String {
  match stmt {
    Definition(Some(lhs), rvalue) =>
      "\{lhs.to_string()} : \{lhs.ty.to_string()} = \{self.print_rvalue(rvalue)}"
    Definition(None, rvalue) => self.print_rvalue(rvalue)
    PutArray(recv, idx, expr) => "\{recv}[\{idx}] = \{expr}"
    IfGoto(cond, true_block, false_block) => {
      let cond = match cond {
        Eq(lhs, rhs) => "\{lhs} == \{rhs}"
        Le(lhs, rhs) => "\{lhs} <= \{rhs}"
      }
      let true_block = true_block.map_or_else(
        fn() { "" },
        fn { b => "B" + b.to_string() },
      )
      let false_block = false_block.map_or_else(
        fn() { "" },
        fn { b => "B" + b.to_string() },
      )
      "if \{cond} then \{true_block} else \{false_block}"
    }
    Goto(t) => "goto B\{t};"
    Nop => ""
    Return(rvalue) => "return \{rvalue.to_string()}"
  }
}

fn Method::print_rvalue(_self : Method, rvalue : RValue) -> String {
  match rvalue {
    Unit => "Unit"
    Int(v) => "(Int) \{v}"
    Double(v) => "(Double) \{v}"
    Neg(v, kind) => "(\{kind}) -\{v.to_string()}"
    Prim(lhs, rhs, op, kind) => "(\{kind}) \{lhs} \{op} \{rhs}"
    Var(v) => v.to_string()
    Tuple(els) => {
      let els = els.map(fn { el => el.to_string() }).join(", ")
      "(\{els})"
    }
    Closure(label, free_vars) => {
      let bindings = free_vars
        .map(fn { (fv, var) => "\{fv.to_string()} = \{var.to_string()}" })
        .join(", ")
      "make_closure \"\{label}\" { \{bindings} } "
    }
    GetTuple(recv, idx) => "\{recv.to_string()}.\{idx.to_string()}"
    GetArray(recv, idx) => "\{recv.to_string()}[\{idx.to_string()}]"
    GetClosure(v, fv) => "get_closure \{v} -> \{fv.to_string()}"
    InvokeClosure(callee, args) => {
      let args = args.map(fn { el => el.to_string() }).join(", ")
      "invoke_closure \{callee} (\{args})"
    }
    InvokeDirect(label, args) => {
      let args = args.map(fn { el => el.to_string() }).join(", ")
      "invoke_direct \"\{label}\" (\{args})"
    }
    Phi(els) => {
      let els = els.map(fn { el => el.to_string() }).join(", ")
      "phi (\{els})"
    }
  }
}
