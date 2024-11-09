pub fn transform_inst_fold(method : @riscv.AssemblyFunction) -> Unit {
  let ph = PeepholeFunc::new(method)
  ph.transform_single()
  ph.transform_pair()
  ph.transform_store_load()
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

let count: Ref[Int] = { val: 0 }

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

// Transform, sw -> ... -> lw -> ... -> sw ->  ... -> lw
fn PeepholeFunc::transform_store_load(self : PeepholeFunc) -> Unit {
  self.blocks.each(
    fn {
      block => {
        let stmts = block.insts
        for i = 0; i < stmts.length(); i = i + 1 {
          match stmts[i].1 {
            Lw(r1, { base, offset }) =>
              if base == Fp && r1 != T0 && r1 != T1 {
                let arr = []
                for j = i + 1; j < stmts.length(); j = j + 1 {
                  if stmts[j].1 == Sw(r1, { base: Fp, offset }) {
                    arr.push(stmts[j])
                    break
                  } else if is_modify_reg(stmts[j].1, r1) ||
                    is_modify_mem(stmts[j].1, offset) {
                    break
                  }
                }
                if arr.length() == 1 {
                  // println("optimized :\{stmts[i].1}")
                  // println("optimized :\{arr[0].1}")
                  // self.update(stmts[i].0, Comment("optimized :\{stmts[i].1}"))
                  self.update(arr[0].0, Comment("optimized :\{arr[0].1}"))
                }
              }
            Ld(r1, { base, offset }) =>
              if base == Fp && r1 != T0 && r1 != T1 {
                let arr = []
                for j = i + 1; j < stmts.length(); j = j + 1 {
                  if stmts[j].1 == Sd(r1, { base: Fp, offset }) {
                    arr.push(stmts[j])
                    break
                  } else if is_modify_reg(stmts[j].1, r1) ||
                    is_modify_mem(stmts[j].1, offset) {
                    break
                  }
                }
                if arr.length() == 1 {
                  // println("optimized :\{stmts[i].1}")
                  // println("optimized :\{arr[0].1}")
                  // self.update(stmts[i].0, Comment("optimized :\{stmts[i].1}"))
                  self.update(arr[0].0, Comment("optimized :\{arr[0].1}"))
                }
              }
            Fld(r1, { base, offset }) =>
              if base == Fp && r1 != Ft0 && r1 != Ft0 {
                let arr = []
                for j = i + 1; j < stmts.length(); j = j + 1 {
                  if stmts[j].1 == Fsd(r1, { base: Fp, offset }) {
                    arr.push(stmts[j])
                    break
                  } else if is_modify_freg(stmts[j].1, r1) ||
                    is_modify_mem(stmts[j].1, offset) {
                    break
                  }
                }
                if arr.length() == 1 {
                  // println("optimized :\{stmts[i].1}")
                  // println("optimized :\{arr[0].1}")
                  // self.update(stmts[i].0, Comment("optimized :\{stmts[i].1}"))
                  self.update(arr[0].0, Comment("optimized :\{arr[0].1}"))
                }
              }
            _ => ()
          }
        }
      }
    },
  )
}
