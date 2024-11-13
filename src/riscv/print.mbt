pub fn print_assembly(asm : AssemblyProgram) -> String {
  let logger = Buffer::new()
  asm.output_data_section(logger)
  let funcs = asm.functions
  for f in funcs {
    f.output(logger)
    logger.write_string("\n")
  }
  if enable_sanitizer {
    output_sanitizer(logger)
  }
  logger.to_string()
}

pub fn AssemblyProgram::output_data_section(
  self : AssemblyProgram,
  logger : Logger
) -> Unit {
  if is_debug {
    logger.write_string("# --- global variables ---\n")
  }
  // ---
  logger.write_string(".section .data\n")
  for _, v in self.world.globals {
    match v.1.const_value {
      Some(_) => ()
      None => {
        logger.write_string("\n")
        let (label, var) = v
        logger.write_string(".global \{label}\n")
        logger.write_string("\{label}:\n")
        match var.width {
          Int => logger.write_string("  .word 0\n")
          Double => logger.write_string("  .double 0.0\n")
          Ptr => logger.write_string("  .dword 0\n")
        }
      }
    }
  }
  for value, label in self.world.doubles {
    logger.write_string("\n")
    logger.write_string(".global \{label}\n")
    logger.write_string("\{label}:\n")
    logger.write_string(
      "  .dword \{@util.i64_to_hex(value.reinterpret_as_i64())}\n",
    )
  }
  // ---
  if is_debug {
    logger.write_string("# --- global variables ---\n\n")
  }
}

pub fn AssemblyFunction::output(
  self : AssemblyFunction,
  logger : Logger
) -> Unit {
  if is_debug {
    logger.write_string("# --- function \{self.name} ---\n")
  }
  // ---
  let label = self.label
  if self.export {
    logger.write_string(".global \{label}\n")
  } else if is_debug {
    logger.write_string(".global \{label}\n")
  } else {
    logger.write_string(".local \{label}\n")
  }
  logger.write_string(".text\n")
  logger.write_string(".type \{label}, @function\n")
  logger.write_string("\{label}:\n")
  for asm in self.body {
    Show::output(asm, logger)
    logger.write_string("\n")
  }
  // ---
  if is_debug {
    logger.write_string("# --- function \{self.name} ---\n")
  }
}
