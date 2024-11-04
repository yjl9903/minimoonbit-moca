pub fn transform_inst_fold(method : @riscv.AssemblyFunction) -> Unit {
  let stmts = method.body
  let mut i = 0
  while i < stmts.length() {
    let cur = stmts[i]
    let mut j = i + 1
    while j < stmts.length() {
      let found = match stmts[j] {
        Comment(_) => false
        Nop => false
        _ => true
      }
      if found {
        break
      } else {
        j = j + 1
      }
    }

    // (i, j)
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
        (Li(r, value), Add(r1, r2, r3)) => {
          let value = @strconv.parse_int?(value).unwrap()
          if -2048 <= value && value < 2048 {
            if r == r3 {
              // stmts[i] = Nop
              stmts[j] = Addi(r1, r2, value)
            } else if r == r2 {
              // stmts[i] = Nop
              stmts[j] = Addi(r1, r3, value)
            }
          }
        }
        (Li(r, value), Mul(r1, r2, r3)) =>
          if r == r3 {
            if value == "4" {
              // stmts[i] = Nop
              stmts[j] = Slli(r1, r2, 2)
            } else if value == "8" {
              // stmts[i] = Nop
              stmts[j] = Slli(r1, r2, 3)
            }
          } else if r == r2 {
            if value == "4" {
              // stmts[i] = Nop
              stmts[j] = Slli(r1, r3, 2)
            } else if value == "8" {
              // stmts[i] = Nop
              stmts[j] = Slli(r1, r3, 3)
            }
          }
        _ => ()
      }
    }
    i = j
  }
}
