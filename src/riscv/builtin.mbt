let sanitizer_label = "minimoonbit.address_sanitizer"

pub fn emit_sanitizer(self : AssemblyFunction, reg : Reg, code : Int) -> Unit {
  if enable_sanitizer {
    self.body.push(Comment("--- start sanitizer ---"))
    self.body.push(Addi(Sp, Sp, -16)) // sp = sp - 16
    self.body.push(Sd(A0, MemAccess::new(Sp, 8))) // push a0
    self.body.push(Sd(A1, MemAccess::new(Sp, 0))) // push a1
    self.body.push(Mv(A0, reg))
    self.body.push(Li(A1, code.to_string()))
    self.body.push(Call(sanitizer_label))
    self.body.push(Ld(A1, MemAccess::new(Sp, 0))) // pop a1
    self.body.push(Ld(A0, MemAccess::new(Sp, 8))) // pop a0
    self.body.push(Addi(Sp, Sp, 16)) // sp = sp + 16
    self.body.push(Comment("--- end sanitizer ---"))
  }
}

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

fn output_alloc_arena(logger : Logger) -> Unit {

}
