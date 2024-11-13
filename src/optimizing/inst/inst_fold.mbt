pub fn transform_inst_fold(method : @riscv.AssemblyFunction) -> Unit {
  let ph = PeepholeFunc::new(method)
  ph.transform_return()
  ph.transform_single()
  ph.transform_pair()
  ph.transform_quad()
  // ph.transform_store_load()
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
                Add(rd, rs1, rs2) =>
                  if rs1 == rs2 {
                    self.update(i, Slli(rd, rs1, 1))
                  }
                Sub(rd, rs1, rs2) =>
                  if rs1 == rs2 {
                    self.update(i, Mv(rd, Zero))
                  }
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
            // mv  a0, a1
            // add a0, a2, a0 -> add a0, a2, a1
            (Mv(rd1, rs11), Add(rd2, rs21, rs22)) =>
              if rd1 == rd2 {
                if rd1 == rs21 {
                  self.update(i, Nop)
                  self.update(j, Add(rd2, rs11, rs22))
                } else if rd1 == rs22 {
                  self.update(i, Nop)
                  self.update(j, Add(rd2, rs21, rs11))
                }
              }
            // mv  a0, a1
            // sub a0, a2, a0 -> sub a0, a2, a1
            (Mv(rd1, rs11), Sub(rd2, rs21, rs22)) =>
              if rd1 == rd2 {
                if rd1 == rs21 {
                  self.update(i, Nop)
                  self.update(j, Sub(rd2, rs11, rs22))
                } else if rd1 == rs22 {
                  self.update(i, Nop)
                  self.update(j, Sub(rd2, rs21, rs11))
                }
              }
            (Mv(rd1, rs11), Mul(rd2, rs21, rs22)) =>
              if rd1 == rd2 {
                if rd1 == rs21 {
                  self.update(i, Nop)
                  self.update(j, Mul(rd2, rs11, rs22))
                } else if rd1 == rs22 {
                  self.update(i, Nop)
                  self.update(j, Mul(rd2, rs21, rs11))
                }
              }
            (Mv(rd1, rs11), Div(rd2, rs21, rs22)) =>
              if rd1 == rd2 {
                if rd1 == rs21 {
                  self.update(i, Nop)
                  self.update(j, Div(rd2, rs11, rs22))
                } else if rd1 == rs22 {
                  self.update(i, Nop)
                  self.update(j, Div(rd2, rs21, rs11))
                }
              }
            (Mv(rd1, rs11), Mulw(rd2, rs21, rs22)) =>
              if rd1 == rd2 {
                if rd1 == rs21 {
                  self.update(i, Nop)
                  self.update(j, Mulw(rd2, rs11, rs22))
                } else if rd1 == rs22 {
                  self.update(i, Nop)
                  self.update(j, Mulw(rd2, rs21, rs11))
                }
              }
            (Mv(rd1, rs11), Divw(rd2, rs21, rs22)) =>
              if rd1 == rd2 {
                if rd1 == rs21 {
                  self.update(i, Nop)
                  self.update(j, Divw(rd2, rs11, rs22))
                } else if rd1 == rs22 {
                  self.update(i, Nop)
                  self.update(j, Divw(rd2, rs21, rs11))
                }
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

fn PeepholeFunc::transform_quad(self : PeepholeFunc) -> Unit {
  self.blocks.each(
    fn {
      block =>
        for t = 0; t + 3 < block.insts.length(); t = t + 1 {
          let (_, s1) = block.insts[t]
          let (_, s2) = block.insts[t + 1]
          let (k, s3) = block.insts[t + 2]
          let (l, s4) = block.insts[t + 3]
          match (s1, s2, s3, s4) {
            (
              Add(rd1, rs11, rs12),
              Ld(rd2, { base: b2, offset: o2 }),
              Add(rd3, rs31, rs32),
              Ld(rd4, { base: b4, offset: o4 }),
            ) =>
              if rs11 == rs31 && rs12 == rs32 {
                if rd1 == b2 && rd3 == b4 && o2 == o4 {
                  self.update(k, Nop)
                  self.update(l, Mv(rd4, rd2))
                }
              }
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

fn PeepholeFunc::transform_return(self : PeepholeFunc) -> Unit {
  self.blocks.each(
    fn {
      block => {
        let stmts = block.insts
        for i = stmts.length() - 1; i >= 0; i = i - 1 {
          // ?  reg, ...
          // mv a0, reg
          // ret
          if stmts[i].1 == Ret && i > 3 {
            let is_mv2 = match stmts[i - 2].1 {
              Mv(A0, _) => true
              FmvD(Fa0, _) => true
              _ => false
            }
            let is_mv5 = i > 5 &&
              (match stmts[i - 5].1 {
                Mv(A0, _) => true
                FmvD(Fa0, _) => true
                _ => false
              })
            if not(is_mv2) || not(is_mv5) {
              continue
            }
            let i2 = if is_mv2 { i - 2 } else { i - 5 }
            let i3 = if is_mv2 { i - 3 } else { i - 6 }
            match stmts[i2].1 {
              Mv(A0, t) =>
                match stmts[i3].1 {
                  Mv(rd, rs1) =>
                    if rd == t {
                      self.update(stmts[i3].0, Mv(A0, rs1))
                      self.update(stmts[i2].0, Nop)
                    }
                  Neg(rd, rs1) =>
                    if rd == t {
                      self.update(stmts[i3].0, Neg(A0, rs1))
                      self.update(stmts[i2].0, Nop)
                    }
                  Add(rd, rs1, rs2) =>
                    if rd == t {
                      self.update(stmts[i3].0, Add(A0, rs1, rs2))
                      self.update(stmts[i2].0, Nop)
                    }
                  Addi(rd, rs1, imm) =>
                    if rd == t {
                      self.update(stmts[i3].0, Addi(A0, rs1, imm))
                      self.update(stmts[i2].0, Nop)
                    }
                  Slli(rd, rs1, imm) =>
                    if rd == t {
                      self.update(stmts[i3].0, Slli(A0, rs1, imm))
                      self.update(stmts[i2].0, Nop)
                    }
                  Sub(rd, rs1, rs2) =>
                    if rd == t {
                      self.update(stmts[i3].0, Sub(A0, rs1, rs2))
                      self.update(stmts[i2].0, Nop)
                    }
                  Mul(rd, rs1, rs2) =>
                    if rd == t {
                      self.update(stmts[i3].0, Mul(A0, rs1, rs2))
                      self.update(stmts[i2].0, Nop)
                    }
                  Mulw(rd, rs1, rs2) =>
                    if rd == t {
                      self.update(stmts[i3].0, Mulw(A0, rs1, rs2))
                      self.update(stmts[i2].0, Nop)
                    }
                  Div(rd, rs1, rs2) =>
                    if rd == t {
                      self.update(stmts[i3].0, Div(A0, rs1, rs2))
                      self.update(stmts[i2].0, Nop)
                    }
                  Divw(rd, rs1, rs2) =>
                    if rd == t {
                      self.update(stmts[i3].0, Divw(A0, rs1, rs2))
                      self.update(stmts[i2].0, Nop)
                    }
                  Lw(rd, mem) =>
                    if rd == t {
                      self.update(stmts[i3].0, Lw(A0, mem))
                      self.update(stmts[i2].0, Nop)
                    }
                  Ld(rd, mem) =>
                    if rd == t {
                      self.update(stmts[i3].0, Ld(A0, mem))
                      self.update(stmts[i2].0, Nop)
                    }
                  Li(rd, value) =>
                    if rd == t {
                      self.update(stmts[i3].0, Li(A0, value))
                      self.update(stmts[i2].0, Nop)
                    }
                  La(rd, label) =>
                    if rd == t {
                      self.update(stmts[i3].0, La(A0, label))
                      self.update(stmts[i2].0, Nop)
                    }
                  FcvtWD(rd, rs1) =>
                    if rd == t {
                      self.update(stmts[i3].0, FcvtWD(A0, rs1))
                      self.update(stmts[i2].0, Nop)
                    }
                  _ => ()
                }
              FmvD(Fa0, t) =>
                match stmts[i - 2].1 {
                  FmvD(rd, rs1) =>
                    if rd == t {
                      self.update(stmts[i3].0, FmvD(Fa0, rs1))
                      self.update(stmts[i2].0, Nop)
                    }
                  FnegD(rd, rs1) =>
                    if rd == t {
                      self.update(stmts[i3].0, FnegD(Fa0, rs1))
                      self.update(stmts[i2].0, Nop)
                    }
                  FaddD(rd, rs1, rs2) =>
                    if rd == t {
                      self.update(stmts[i3].0, FaddD(Fa0, rs1, rs2))
                      self.update(stmts[i2].0, Nop)
                    }
                  FsubD(rd, rs1, rs2) =>
                    if rd == t {
                      self.update(stmts[i3].0, FsubD(Fa0, rs1, rs2))
                      self.update(stmts[i2].0, Nop)
                    }
                  FmulD(rd, rs1, rs2) =>
                    if rd == t {
                      self.update(stmts[i3].0, FmulD(Fa0, rs1, rs2))
                      self.update(stmts[i2].0, Nop)
                    }
                  FdivD(rd, rs1, rs2) =>
                    if rd == t {
                      self.update(stmts[i3].0, FdivD(Fa0, rs1, rs2))
                      self.update(stmts[i2].0, Nop)
                    }
                  FcvtDW(rd, rs1) =>
                    if rd == t {
                      self.update(stmts[i3].0, FcvtDW(Fa0, rs1))
                      self.update(stmts[i2].0, Nop)
                    }
                  _ => ()
                }
              _ => ()
            }
          }
        }
      }
    },
  )
}
