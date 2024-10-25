struct Logger {
  mut indent : Int
  content : Array[String]
}

fn Logger::new() -> Logger {
  { indent: 0, content: [] }
}

fn Logger::indent(self : Logger) -> Unit {
  self.indent = self.indent + 1
}

fn Logger::dedent(self : Logger) -> Unit {
  self.indent = self.indent - 1
}

fn Logger::push(self : Logger, text : String) -> Unit {
  self.content.push(" ".repeat(self.indent) + text)
}

fn Logger::output(self : Logger) -> String {
  self.content.join("\n")
}

pub fn print_wasm(result : WasmResult) -> String {
  let logger = Logger::new()
  logger.push("(module")
  logger.indent()
  // 1. Memory section
  {
    let memory = result.memory_import
    memory.each(
      fn {
        memory =>
          match memory.import_info {
            Some((import_module, import_name)) =>
              logger.push(
                "(memory (import \"\{import_module}\" \"\{import_name}\") \{memory.limit})",
              )
            None => logger.push("(memory \{memory.limit})")
          }
      },
    )
    logger.push("")
  }
  // 2. Import section
  {
    let imports = result.imports
    imports
    .values()
    .each(
      fn {
        (imp, _) =>
          logger.push(
            "(func \{imp.identifier} (import \"\{imp.import_module}\" \"\{imp.import_name}\") \{print_import_function_type(imp.ty)})",
          )
      },
    )
    logger.push("")
  }
  // 3. Memory section
  {
    let memory = result.memory
    memory.each(
      fn {
        memory =>
          match memory.import_info {
            Some((import_module, import_name)) =>
              logger.push(
                "(memory (import \"\{import_module}\" \"\{import_name}\") \{memory.limit})",
              )
            None => logger.push("(memory \{memory.limit})")
          }
      },
    )
    logger.push("")
  }
  // 4. Type section
  {
    let types = result.types.values()
    types.each(
      fn {
        ty =>
          logger.push(
            "(type \{ty.identifier} (func \{print_function_type(ty.ty)}))",
          )
      },
    )
    logger.push("")
  }
  // 5. Table section
  if result.funcs.size() > 0 {
    let table = result.table
    let elems = result.funcs
      .values()
      .filter(fn { f => not(f.1.is_empty()) })
      .map(
        fn {
          f => (f.1.unwrap().table_index.unwrap(), "\{f.1.unwrap().identifier}")
        },
      )
      .collect()
    elems.sort_by_key(fn { (idx, _) => idx })
    let elems = elems.map(fn { (_, id) => id }).join(" ")
    logger.push("(table \{table.identifier} \{result.table.size} funcref)")
    logger.push("(elem (i32.const 0) \{elems})")
    logger.push("")
  }
  // 6. Global section
  {
    let globals = result.globals.values()
    globals.each(
      fn {
        g => {
          let value = g.value.or_else(
            fn() {
              match g.ty {
                Double => FConst(F64, 0.0)
                _ => IConst(I32, 0)
              }
            },
          )
          let value = match value {
            IConst(_, x) => "(i32.const \{x})"
            FConst(_, x) => "(f64.const \{x})"
            _ => @util.die("unexpected global value")
          }
          logger.push(
            "(global \{g.identifier} \{print_type(g.ty, mutable=g.mutable)} \{value})",
          )
        }
      },
    )
    logger.push("")
  }
  // 7. Func section
  {
    let imports = result.imports.values()
    imports.each(
      fn {
        (_, func) =>
          match func {
            Some(c_func) => print_func(logger, result, c_func)
            None => ()
          }
      },
    )
    let funcs = result.funcs.values()
    funcs.each(
      fn {
        func => {
          print_func(logger, result, func.0)
          match func.1 {
            Some(c_func) =>
              if func.0.identifier != c_func.identifier {
                print_func(logger, result, c_func)
              }
            _ => ()
          }
          logger.push("")
        }
      },
    )
  }
  // 8. Start section
  logger.push("(start \{minimoonbit_start_identifier})")
  logger.dedent()
  logger.push(")")
  logger.output()
}

fn print_func(logger : Logger, _result : WasmResult, func : WasmFunc) -> Unit {
  // 1. Signature
  let wasm_type = match func.wasm_type {
    Some(ty) => "(type \{ty.identifier})"
    None => ""
  }
  let params = func.params
    .map(fn { p => "(param \{p.0.identifier} \{print_type(p.1)})" })
    .join(" ")
  let ret_type = @closure.extract_return_type(func.ty)
  let result = if ret_type != Unit {
    "(result \{print_type(ret_type)})"
  } else {
    // Should not return Unit
    ""
  }
  logger.push("(func \{func.identifier} \{wasm_type} \{params} \{result}")
  logger.indent()
  // 2. Local vars
  if func.locals.size() > 0 {
    func.locals
    .values()
    .map(fn { l => "(local \{l.identifier} \{print_type(l.ty)})" })
    .each(fn { l => logger.push(l) })
  }
  // 3. Instructions
  func.stmts.each(
    fn {
      stmt =>
        logger.push(
          match stmt {
            IConst(_, x) => "(i32.const \{x})"
            FConst(_, x) => "(f64.const \{x})"
            FNeg(_) => "(f64.neg)"
            IPrim(_, Add) => "(i32.add)"
            IPrim(_, Sub) => "(i32.sub)"
            IPrim(_, Mul) => "(i32.mul)"
            IPrim(_, Div) => "(i32.div_s)"
            FPrim(_, Add) => "(f64.add)"
            FPrim(_, Sub) => "(f64.sub)"
            FPrim(_, Mul) => "(f64.mul)"
            FPrim(_, Div) => "(f64.div)"
            ICmp(_, Eq) => "(i32.eq)"
            ICmp(_, Ge_s) => "(i32.ge_s)"
            ICmp(_, Gt_s) => "(i32.gt_s)"
            ICmp(_, Le_s) => "(i32.le_s)"
            ICmp(_, Lt_s) => "(i32.lt_s)"
            FCmp(_, Eq) => "(f64.eq)"
            FCmp(_, Le) => "(f64.le)"
            LocalGet(v) => "(local.get \{v.identifier})"
            LocalSet(v) => "(local.set \{v.identifier})"
            LocalTee(v) => "(local.tee \{v.identifier})"
            GlobalGet(v) => "(global.get \{v.identifier})"
            GlobalSet(v) => "(global.set \{v.identifier})"
            Call(func) => "(call \{func.identifier})"
            CallImport(func) => "(call \{func.identifier})"
            CallIndirect(ty) => "(call_indirect (type \{ty.identifier}))"
            Drop => "(drop)"
            // Memory
            MemoryGrow => "(memory.grow)"
            Malloc => "(call \{external_malloc_identifier})"
            ILoad(_, offset) =>
              match offset {
                Some(offset) => "(i32.load offset=\{offset})"
                None => "(i32.load)"
              }
            IStore(_, offset) =>
              match offset {
                Some(offset) => "(i32.store offset=\{offset})"
                None => "(i32.store)"
              }
            FLoad(_, offset) =>
              match offset {
                Some(offset) => "(f64.load offset=\{offset})"
                None => "(f64.load)"
              }
            FStore(_, offset) =>
              match offset {
                Some(offset) => "(f64.store offset=\{offset})"
                None => "(f64.store)"
              }
            // Control flow
            If => "(if"
            IfThen => "(then"
            IfElse => "(else"
            IfEnd => ")"
            Loop(label) => "(loop $B\{label} (block $B\{label}_inner"
            LoopEnd => "))"
            Continue(label) => "(br $B\{label})"
            Break(label) => "(br $B\{label}_inner)"
            Nop => "(nop)"
            Return => "(return)"
          },
        )
    },
  )
  logger.dedent()
  logger.push(")")
}

fn print_import_function_type(ty : Type) -> String {
  match ty {
    DirectFn(args, ret) | ClosureFn(args, ret) => {
      let args = args.map(fn { a => "(param \{print_type(a)})" }).join(" ")
      let result = if ret == Unit { "" } else { "(result \{print_type(ret)})" }
      "\{args} \{result}"
    }
    _ => ""
  }
}

fn print_function_type(ty : Type) -> String {
  match ty {
    DirectFn(args, ret) | ClosureFn(args, ret) => {
      let args = args.map(fn { a => "(param \{print_type(a)})" }).join(" ")
      let result = if ret == Unit { "" } else { "(result \{print_type(ret)})" }
      "\{args} \{result}"
    }
    _ => ""
  }
}

fn print_type(ty : Type, ~mutable : Bool = false) -> String {
  let text = match ty {
    Unit => "i32"
    Int => "i32"
    Bool => "i32"
    Double => "f64"
    DirectFn(_) => "i32"
    ClosureFn(_) => "i32"
    Array(_) => "i32"
    Tuple(_) => "i32"
    Ptr => "i32"
  }
  if mutable {
    "(mut \{text})"
  } else {
    text
  }
}
