pub fn transform_inst_fold(method : @riscv.AssemblyFunction) -> Unit {
  let stmts = method.body
  let mut i = 0
  while i < stmts.length() {
    let cur = stmts[i]
    let mut j = i + 1
    while j < stmts.length() {
      let found = match stmts[j] {
        Comment(_) => false
        _ => true
      }
      if found {
        break
      } else {
        j = j + 1
      }
    }
    if j < stmts.length() {
      match (cur, stmts[j]) {
        (Sw(r1, mem1), Lw(r2, mem2)) =>
          if r1 == r2 && r1 != mem1.base && mem1 == mem2 {
            stmts[j] = Nop
          }
        (Sd(r1, mem1), Ld(r2, mem2)) =>
          if r1 == r2 && r1 != mem1.base && mem1 == mem2 {
            stmts[j] = Nop
          }
        (Fsd(r1, mem1), Fld(r2, mem2)) =>
          if r1 == r2 && mem1 == mem2 {
            stmts[j] = Nop
          }
        _ => ()
      }
    }
    i = j
  }
}
