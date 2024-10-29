pub fn print_assembly(asm : AssemblyProgram) -> String {
  let logger = Buffer::new()
  let funcs = asm.functions
  for f in funcs {
    f.output(logger)
    logger.write_string("\n")
  }
  logger.to_string()
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
  } else {
    // TODO
    if is_debug {
      logger.write_string(".global \{label}\n")
    } else {
      logger.write_string(".local \{label}\n")
    }
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
