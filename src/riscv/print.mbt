pub fn print_assembly(asm : AssemblyProgram) -> String {
  let logger = Buffer::new()
  asm.output_data_section(logger)
  let funcs = asm.functions
  for f in funcs {
    f.output(logger)
    logger.write_string("\n")
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
    let (label, var) = v
    logger.write_string(".global \{label}\n")
    logger.write_string("\{label}:\n")
    match var.ty {
      Double => logger.write_string("  .float 0.0\n")
      _ => logger.write_string("  .word 0\n")
    }
  }
  for value, label in self.world.doubles {
    logger.write_string(".global \{label}\n")
    logger.write_string("\{label}:\n")
    logger.write_string("  .float \{value.to_string()}\n")
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
    // TODO
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
