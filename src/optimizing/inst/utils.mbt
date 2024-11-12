fn is_modify_mem(asm : @riscv.RvAsm, offset : Int) -> Bool {
  match asm {
    Sb(_, { base: r1, offset: o })
    | Sh(_, { base: r1, offset: o })
    | Sw(_, { base: r1, offset: o })
    | Sd(_, { base: r1, offset: o }) | Fsd(_, { base: r1, offset: o }) =>
      if r1 == Fp && o == offset {
        true
      } else {
        false
      }
    _ => false
  }
}

fn is_modify_reg(asm : @riscv.RvAsm, reg : @riscv.Reg) -> Bool {
  match asm {
    Add(r0, r1, r2)
    | Sub(r0, r1, r2)
    | Xor(r0, r1, r2)
    | Or(r0, r1, r2)
    | And(r0, r1, r2)
    | Sll(r0, r1, r2)
    | Srl(r0, r1, r2)
    | Sra(r0, r1, r2)
    | Slt(r0, r1, r2)
    | Sltu(r0, r1, r2)
    | Mul(r0, r1, r2)
    | Mulw(r0, r1, r2)
    | Mulh(r0, r1, r2)
    | Mulhsu(r0, r1, r2)
    | Mulhu(r0, r1, r2)
    | Div(r0, r1, r2)
    | Divw(r0, r1, r2)
    | Divu(r0, r1, r2) | Rem(r0, r1, r2) | Remw(r0, r1, r2) | Remu(r0, r1, r2) =>
      if r0 == reg || r1 == reg || r2 == reg {
        true
      } else {
        false
      }
    Addi(r0, r1, _)
    | Xori(r0, r1, _)
    | Ori(r0, r1, _)
    | Andi(r0, r1, _)
    | Slli(r0, r1, _)
    | Srli(r0, r1, _)
    | Srai(r0, r1, _)
    | Slti(r0, r1, _)
    | Sltiu(r0, r1, _)
    | Neg(r0, r1)
    | Beq(r0, r1, _)
    | Bne(r0, r1, _)
    | Blt(r0, r1, _)
    | Bge(r0, r1, _)
    | Ble(r0, r1, _)
    | Bgt(r0, r1, _) | Bltu(r0, r1, _) | Bgeu(r0, r1, _) | Mv(r0, r1) =>
      if r0 == reg || r1 == reg {
        true
      } else {
        false
      }
    Lb(r0, { base: r1, offset: _ })
    | Lh(r0, { base: r1, offset: _ })
    | Lw(r0, { base: r1, offset: _ })
    | Ld(r0, { base: r1, offset: _ })
    | Lbu(r0, { base: r1, offset: _ })
    | Lhu(r0, { base: r1, offset: _ })
    | Lwu(r0, { base: r1, offset: _ })
    | Sb(r0, { base: r1, offset: _ })
    | Sh(r0, { base: r1, offset: _ })
    | Sw(r0, { base: r1, offset: _ }) | Sd(r0, { base: r1, offset: _ }) =>
      if r0 == reg || r1 == reg {
        true
      } else {
        false
      }
    La(r0, _) | Li(r0, _) | Jalr(r0) | Jr(r0) =>
      if r0 == reg {
        true
      } else {
        false
      }
    FmvDX(_, r1)
    | Fld(_, { base: r1, offset: _ })
    | Fsd(_, { base: r1, offset: _ }) | FcvtWD(r1, _) =>
      if r1 == reg {
        true
      } else {
        false
      }
    _ => false
  }
}

fn is_modify_freg(asm : @riscv.RvAsm, freg : @riscv.FReg) -> Bool {
  match asm {
    FaddD(fr0, fr1, fr2)
    | FsubD(fr0, fr1, fr2) | FmulD(fr0, fr1, fr2) | FdivD(fr0, fr1, fr2) =>
      if fr0 == freg || fr1 == freg || fr2 == freg {
        true
      } else {
        false
      }
    FnegD(fr0, fr1) | FmvD(fr0, fr1) =>
      if fr0 == freg || fr1 == freg {
        true
      } else {
        false
      }
    FmvDX(fr0, _) | Fld(fr0, _) | Fsd(fr0, _) | FcvtDW(fr0, _) =>
      if fr0 == freg {
        true
      } else {
        false
      }
    _ => false
  }
}
