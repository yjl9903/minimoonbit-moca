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
    let memory = result.memory
    logger.push(
      "(memory (import \"\{memory.import_module}\" \"\{memory.import_name}\") \{memory.limit})",
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
  // 3. Type section
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
  // 4. Table section
  if result.funcs.size() > 0 {
    let table = result.table
    let elems = result.funcs
      .values()
      .map(fn { f => "\{f.identifier}" })
      .collect()
      .join(" ")
    logger.push("(table \{table.identifier} \{result.funcs.size()} funcref)")
    logger.push("(elem (i32.const 0) \{elems})")
    logger.push("")
  }
  // 5. Func section
  {
    let funcs = result.funcs.values()
    funcs.each(
      fn {
        func => {
          print_func(logger, result, func)
          logger.push("")
        }
      },
    )
  }
  // 6. Start section
  logger.push("(start \{minimoonbit_start_identifier})")
  logger.dedent()
  logger.push(")")
  logger.output()
}

fn print_func(logger : Logger, result : WasmResult, func : WasmFunc) -> Unit {

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
      let result = "(result \{print_type(ret)})"
      "\{args} \{result}"
    }
    _ => ""
  }
}

fn print_type(ty : Type) -> String {
  match ty {
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
}
