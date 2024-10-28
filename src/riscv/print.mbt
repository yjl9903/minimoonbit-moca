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
  let name = self.name
  if self.export {
    logger.write_string(".global \{name}\n")
  }
  logger.write_string("\{name}:\n")
  for asm in self.body {
    Show::output(asm, logger)
    logger.write_string("\n")
  }
}
