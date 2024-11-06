pub fn transform_inst_fold(method : @riscv.AssemblyFunction) -> Unit {
  let ph = PeepholeFunc::new(method)
  ph.transform_single()
  ph.transform_pair()
}

fn PeepholeFunc::transform_single(self : PeepholeFunc) -> Unit {
  self.blocks.each(
    fn {
      block =>
        block.insts.each(
          fn {
            (i, asm) =>
              match asm {
                Mv(r1, r2) => if r1 == r2 { self.update(i, Nop) }
                FmvD(r1, r2) => if r1 == r2 { self.update(i, Nop) }
                Addi(r1, r2, x) => if r1 == r2 && x == 0 { self.update(i, Nop) }
                _ => ()
              }
          },
        )
    },
  )
}

fn PeepholeFunc::transform_pair(self : PeepholeFunc) -> Unit {
  self.blocks.each(
    fn {
      block =>
        for t = 0; t + 1 < block.insts.length(); t = t + 1 {
          let (i, s1) = block.insts[t]
          let (j, s2) = block.insts[t + 1]
          match (s1, s2) {
            (Mv(r1, r2), Mv(r3, r4)) =>
              if r1 == r3 && r2 == r4 {
                // mv a0, a1
                // mv a0, a1
                self.update(i, Nop)
              } else if r1 == r4 && r2 == r3 {
                // mv a0, a1
                // mv a1, a0
                self.update(j, Nop)
              }
            // (Sw(r1, mem1), Lw(r2, mem2)) =>
            //   if r1 != mem1.base && mem1 == mem2 {
            //     if r1 == r2 {
            //       self.update(j, Nop)
            //     } else if r2 != mem1.base {
            //       // stmts[i] = Mv(r2, r1)
            //       // stmts[j] = Sw(r1, mem1)
            //     }
            //   }
            // (Sd(r1, mem1), Ld(r2, mem2)) =>
            //   if r1 != mem1.base && mem1 == mem2 {
            //     if r1 == r2 {
            //       self.update(j, Nop)
            //     } else if r2 != mem1.base {
            //       // stmts[i] = Mv(r2, r1)
            //       // stmts[j] = Sd(r1, mem1)
            //     }
            //   }
            // (Fsd(r1, mem1), Fld(r2, mem2)) =>
            //   if mem1 == mem2 {
            //     if r1 == r2 {
            //       self.update(j, Nop)
            //     } else {
            //       // stmts[j] = FmvD(r2, r1)
            //       // stmts[j] = Fsd(r1, mem1)
            //     }
            //   }
            // (Li(r, value), Add(r1, r2, r3)) => {
            //   let value = @strconv.parse_int?(value).unwrap()
            //   if -2048 <= value && value < 2048 {
            //     if r == r3 {
            //       // stmts[i] = Nop
            //       self.update(j, Addi(r1, r2, value))
            //     } else if r == r2 {
            //       // stmts[i] = Nop
            //       self.update(j, Addi(r1, r3, value))
            //     }
            //   }
            // }
            // (Li(r, value), Mul(r1, r2, r3)) =>
            //   if r == r3 {
            //     if value == "4" {
            //       // stmts[i] = Nop
            //       self.update(j, Slli(r1, r2, 2))
            //     } else if value == "8" {
            //       // stmts[i] = Nop
            //       self.update(j, Slli(r1, r2, 3))
            //     }
            //   } else if r == r2 {
            //     if value == "4" {
            //       // stmts[i] = Nop
            //       self.update(j, Slli(r1, r3, 2))
            //     } else if value == "8" {
            //       // stmts[i] = Nop
            //       self.update(j, Slli(r1, r3, 3))
            //     }
            //   }
            _ => ()
          }
        }
    },
  )
}
