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
  for value, label in self.world.doubles {
    logger.write_string("\n")
    logger.write_string(".global \{label}\n")
    logger.write_string("\{label}:\n")
    logger.write_string("  .dword \{value.reinterpret_as_i64().to_string()}\n")
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

let sanitizer_label = "minimoonbit.address_sanitizer"

fn output_sanitizer(logger : Logger) -> Unit {
  logger.write_string("# --- address sanitizer ---\n")
  logger.write_string(".global \{sanitizer_label}\n")
  logger.write_string(".text\n")
  logger.write_string(".type \{sanitizer_label}, @function\n")
  logger.write_string("\{sanitizer_label}:\n")
  let stmts = [
    RvAsm::Addi(Sp, Sp, -16),
    RvAsm::Sd(T0, MemAccess::new(Sp, 8)), // Push t0
    RvAsm::Sd(T1, MemAccess::new(Sp, 0)), // Push t1
    // a0 < 4096 goto error
    RvAsm::Li(T0, "4096"),
    RvAsm::Blt(A0, T0, "\{sanitizer_label}_exit"),
    RvAsm::Li(T0, "0x0000004F00000000"),
    RvAsm::Bge(A0, T0, "\{sanitizer_label}_exit"),
    // return
    RvAsm::Ld(T1, MemAccess::new(Sp, 0)), // Pop t0
    RvAsm::Ld(T0, MemAccess::new(Sp, 8)), // Pop t1
    RvAsm::Addi(Sp, Sp, 16),
    RvAsm::Ret,
    // exit with a1
    RvAsm::Label("\{sanitizer_label}_exit"),
    RvAsm::Mv(A0, A1), // Return a1
    RvAsm::Li(A7, "93"),
    RvAsm::Ecall,
  ]
  for asm in stmts {
    Show::output(asm, logger)
    logger.write_string("\n")
  }
  logger.write_string("# --- address sanitizer ---\n")
}
