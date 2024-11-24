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

let malloc_arena_label = "minimoonbit.malloc_arena"

let arena_cursor = "minimoonbit.malloc_arena.cursor"

let arena_end_cursor = "minimoonbit.malloc_arena.size"

fn init_malloc_arena() -> Array[RvAsm] {
  // size = 1 MB
  let size = 1 * 128 * 1024
  [
    Li(A0, size.to_string()),
    Call("minimbt_malloc"),
    La(A1, arena_cursor),
    Sd(A0, MemAccess::new(A1, 0)),
    Li(A2, size.to_string()),
    Add(A0, A0, A2),
    La(A3, arena_end_cursor),
    Sd(A0, MemAccess::new(A3, 0)),
  ]
}

fn output_malloc_arena_globals(logger : Logger) -> Unit {
  logger.write_string(".global \{arena_cursor}\n")
  logger.write_string("\{arena_cursor}:\n")
  logger.write_string("  .dword 0x0\n")
  logger.write_string(".global \{arena_end_cursor}\n")
  logger.write_string("\{arena_end_cursor}:\n")
  logger.write_string("  .dword 0x0\n")
}

/// Custom malloc arena:
/// Param: T0 = size
/// Return: T1 = pointer
/// Should save T6
fn output_malloc_arena(logger : Logger) -> Unit {
  logger.write_string("# --- areana ---\n")
  logger.write_string(".global \{malloc_arena_label}\n")
  logger.write_string(".text\n")
  logger.write_string(".type \{malloc_arena_label}, @function\n")
  logger.write_string("\{malloc_arena_label}:\n")
  let stmts = [
    La(T6, arena_cursor),
    Ld(T1, MemAccess::new(T6, 0)),
    Add(T0, T0, T1),
    Sd(T0, MemAccess::new(T6, 0)),
    // --- bound checker ---
    La(T6, arena_end_cursor),
    Ld(T0, MemAccess::new(T6, 0)),
    Bge(T1, T0, Label("malloc_exit")),
    // ---------------------
    Ret,
    // --- bound checker ---
    Label("malloc_exit"),
    Li(A0, "123"),
    RvAsm::Li(A7, "93"),
    RvAsm::Ecall,
  ]
  for asm in stmts {
    Show::output(asm, logger)
    logger.write_string("\n")
  }
  logger.write_string("# --- areana ---\n")
}
