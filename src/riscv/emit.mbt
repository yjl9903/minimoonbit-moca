pub fn emit(world : @ssa.World) -> AssemblyProgram {
  // 1. Build machine ir
  let machine = build_machine_ir(world)
  // 2. Optimizing todo
  // 3. Generate final asm
  let functions = machine.methods.map(
    fn { method => create_asm_func(machine, method) },
  )
  let prog = { functions, }
  functions.each(fn { func => func.emit_method_body() })
  prog
}

pub struct AssemblyProgram {
  functions : Array[AssemblyFunction]
}

pub struct AssemblyFunction {
  name : String
  export : Bool
  body : Array[RvAsm]
  machine : MachineMethod
}

pub fn emit_asm(self : AssemblyFunction, asm : RvAsm) -> Unit {
  self.body.push(asm)
}

fn create_asm_func(
  world : MachineWorld,
  method : MachineMethod
) -> AssemblyFunction {
  let asm_func = {
    name: method.name,
    export: method.is_main,
    body: [],
    machine: method,
  }
  asm_func.calc_stack_size()
  asm_func
}

fn AssemblyFunction::calc_stack_size(self : AssemblyFunction) -> Unit {
  self.machine.stack_vars.clear()

  // 1.1. Params in regs
  let mut gp = 0
  let mut fp = 0
  let stack_params = []
  for var in self.machine.params {
    if var.is_this {
      continue
    }
    if var.is_float() {
      if fp < freg_arg_list.length() {
        var.param_offset = Some(FReg(freg_arg_list[fp]))
        fp += 1
      } else {
        stack_params.push(var)
      }
      ()
    } else {
      if gp < reg_arg_list.length() {
        var.param_offset = Some(Reg(reg_arg_list[gp]))
        gp += 1
      } else {
        stack_params.push(var)
      }
      ()
    }
  }
  // 1.2. %this param in reg
  match self.machine.this {
    Some(var) =>
      if gp < reg_arg_list.length() {
        var.param_offset = Some(Reg(reg_arg_list[gp]))
        gp += 1
      } else {
        stack_params.push(var)
      }
    None => ()
  }
  // 1.3. Calculate stack offset
  let mut re_offset = 16
  stack_params.rev_each(
    fn {
      var => {
        var.param_offset = Some(Offset(re_offset))
        re_offset += var.size
      }
    },
  )

  // 2.1. Local variables
  let mut offset = 0
  for _, var in self.machine.local_vars {
    // Var is not merged by a phi node
    if var.outcoming_var.is_empty() {
      var.offset = -offset
      offset = offset + var.size
      self.machine.stack_vars.set(var.id, var)
    }
  }
  // 2.2. Phi vars
  for _, var in self.machine.local_vars {
    // Var is not merged by a phi node
    match var.outcoming_var {
      Some(outcomming) => var.offset = outcomming.offset
      None => ()
    }
  }
  self.machine.stack_size = offset
}

fn AssemblyFunction::emit_method_body(self : AssemblyFunction) -> Unit {
  // ============= sp - 16
  // / --- ra ---/
  // ------------- sp - 8
  // / --- fp ---/
  // ------------- sp

  // 1. Prologue
  self.emit_asm(Addi(Sp, Sp, -16))
  self.emit_asm(Sd(Ra, MemAccess::new(Sp, 8)))
  self.emit_asm(Sd(Fp, MemAccess::new(Sp, 0)))
  self.emit_asm(Mv(Fp, Sp))

  // 1.1. Calc stack size
  self.emit_asm(Addi(Sp, Sp, -self.machine.stack_size))

  // 1.2. TODO: save reg

  // 1.3. TEMP: store the params
  for var in self.machine.params {
    match var.param_offset {
      Some(Reg(r)) => self.emit_asm(Sw(r, MemAccess::new(Fp, var.offset)))
      Some(FReg(r)) => self.emit_asm(Fsd(r, MemAccess::new(Fp, var.offset)))
      Some(Offset(offset)) =>
        if var.is_float() {
          self.emit_asm(Fld(Ft0, MemAccess::new(Fp, offset)))
          self.emit_asm(Fsd(Ft0, MemAccess::new(Fp, var.offset)))
        } else {
          self.emit_asm(Lw(T0, MemAccess::new(Fp, offset)))
          self.emit_asm(Sw(T0, MemAccess::new(Fp, var.offset)))
        }
      None => @util.die("")
    }
  }

  // 2. Build stmts
  for block in self.machine.body.blocks {
    self.emit_asm(Label(self.create_label(block.label)))
    for stmt in block.stmts {
      self.emit_method_stmt(stmt)
    }
  }
}

fn AssemblyFunction::emit_method_stmt(
  self : AssemblyFunction,
  stmt : Stmt
) -> Unit {
  match stmt.stmt {
    Definition(None, rvalue) =>
      self.emit_method_rvalue(rvalue, fn { _ => () }, fn { _ => () })
    Definition(Some(def), rvalue) => {
      let mut kind = None
      self.emit_method_rvalue(
        rvalue,
        fn {
          reg => {
            kind = Some(PrimKind::Int)
            self.emit_asm(Sw(reg, MemAccess::new(Fp, def.offset)))
          }
        },
        fn {
          freg => {
            kind = Some(PrimKind::Double)
            self.emit_asm(Fsd(freg, MemAccess::new(Fp, def.offset)))
          }
        },
      )
      match (def.is_float(), kind) {
        (true, Some(Double)) => ()
        (false, Some(Int)) => ()
        _ => @util.die("unreachable")
      }
    }
    Store((recv, offset), expr, kind) => {
      self.emit_asm(Lw(T0, MemAccess::new(Fp, recv.offset)))
      match kind {
        Double => {
          self.emit_asm(Fld(Ft0, MemAccess::new(Fp, expr.offset)))
          self.emit_asm(Fsd(Ft0, MemAccess::new(T0, offset)))
        }
        Int => {
          self.emit_asm(Lw(T0, MemAccess::new(Fp, expr.offset)))
          self.emit_asm(Sw(T0, MemAccess::new(T0, offset)))
        }
      }
    }
    StoreAddress((recv, offset), label) => {
      self.emit_asm(Lw(T0, MemAccess::new(Fp, recv.offset)))
      self.emit_asm(La(T1, label))
      self.emit_asm(Sw(T1, MemAccess::new(T0, offset)))
    }
    IfGoto(cond, _true_target, false_target) => {
      match cond {
        Eq(lhs, rhs, Int)
        | Ne(lhs, rhs, Int)
        | Lt(lhs, rhs, Int)
        | Le(lhs, rhs, Int) | Gt(lhs, rhs, Int) | Ge(lhs, rhs, Int) => {
          self.emit_asm(Lw(T0, MemAccess::new(Fp, lhs.offset)))
          self.emit_asm(Lw(T1, MemAccess::new(Fp, rhs.offset)))
        }
        Eq(lhs, rhs, Double)
        | Ne(lhs, rhs, Double)
        | Lt(lhs, rhs, Double)
        | Le(lhs, rhs, Double) | Gt(lhs, rhs, Double) | Ge(lhs, rhs, Double) => {
          self.emit_asm(Fld(Ft0, MemAccess::new(Fp, lhs.offset)))
          self.emit_asm(Fld(Ft1, MemAccess::new(Fp, rhs.offset)))
        }
      }
      match cond {
        Eq(_, _, Int) =>
          self.emit_asm(Bne(T0, T1, self.create_label(false_target.unwrap())))
        Eq(_, _, Double) => @util.die("todo")
        Le(_, _, Int) =>
          self.emit_asm(Bgt(T0, T1, self.create_label(false_target.unwrap())))
        Le(_, _, Double) => @util.die("todo")
        _ => @util.die("todo")
      }
    }
    Goto(label) => self.emit_asm(J(self.create_label(label)))
    Nop => ()
    Return(var) => {
      match var {
        Some(var) =>
          if var.is_float() {
            self.emit_asm(Fsd(Fa0, MemAccess::new(Fp, var.offset)))
          } else {
            self.emit_asm(Sw(A0, MemAccess::new(Fp, var.offset)))
          }
        None => ()
      }
      // Epilogue
      // self.emit_asm(Label(self.create_return_label()))
      // TODO: restore reg
      self.emit_asm(Mv(Sp, Fp))
      self.emit_asm(Ld(Fp, MemAccess::new(Sp, 0)))
      self.emit_asm(Ld(Ra, MemAccess::new(Sp, 8)))
      self.emit_asm(Addi(Sp, Sp, 16))
      if self.machine.is_main {
        self.emit_asm(Li(A0, "0"))
        self.emit_asm(Li(A7, "93"))
        self.emit_asm(Ecall)
      } else {
        self.emit_asm(Ret)
      }
    }
  }
}

fn AssemblyFunction::emit_method_rvalue(
  self : AssemblyFunction,
  rvalue : RValue,
  contg : (Reg) -> Unit,
  contf : (FReg) -> Unit
) -> Unit {
  match rvalue {
    Int(x) => {
      self.emit_asm(Li(T0, x.to_string()))
      contg(T0)
    }
    Double(x) =>
      // TODO: load imm double x
      contf(Ft0)
    Neg(expr, Int) => {
      self.emit_asm(Lw(T0, MemAccess::new(Fp, expr.offset)))
      self.emit_asm(Sub(T0, Zero, T0))
      contg(T0)
    }
    Neg(expr, Double) => {
      self.emit_asm(Fld(Ft0, MemAccess::new(Fp, expr.offset)))
      self.emit_asm(FnegD(Ft0, Ft0))
      contf(Ft0)
    }
    Prim(lhs, rhs, op, Int) => {
      self.emit_asm(Lw(T0, MemAccess::new(Fp, lhs.offset)))
      self.emit_asm(Lw(T1, MemAccess::new(Fp, rhs.offset)))
      self.emit_asm(
        match op {
          Add => Add(T0, T0, T1)
          Sub => Sub(T0, T0, T1)
          Mul => Mul(T0, T0, T1)
          Div => Div(T0, T0, T1)
        },
      )
      contg(T0)
    }
    Prim(lhs, rhs, op, Double) => {
      self.emit_asm(Fld(Ft0, MemAccess::new(Fp, lhs.offset)))
      self.emit_asm(Fld(Ft1, MemAccess::new(Fp, rhs.offset)))
      self.emit_asm(
        match op {
          Add => FaddD(Ft0, Ft0, Ft1)
          Sub => FsubD(Ft0, Ft0, Ft1)
          Mul => FmulD(Ft0, Ft0, Ft1)
          Div => FdivD(Ft0, Ft0, Ft1)
        },
      )
      contf(Ft0)
    }
    Var(var, Int) => {
      self.emit_asm(Lw(T0, MemAccess::new(Fp, var.offset)))
      contg(T0)
    }
    Var(var, Double) => {
      self.emit_asm(Fld(Ft0, MemAccess::new(Fp, var.offset)))
      contf(Ft0)
    }
    Load((recv, offset), Int) => {
      self.emit_asm(Lw(T0, MemAccess::new(Fp, recv.offset)))
      self.emit_asm(Lw(T0, MemAccess::new(T0, offset)))
      contg(T0)
    }
    Load((recv, offset), Double) => {
      self.emit_asm(Lw(T0, MemAccess::new(Fp, recv.offset)))
      self.emit_asm(Fld(Ft0, MemAccess::new(T0, offset)))
      contf(Ft0)
    }

    // Invoke
    InvokeClosure(_) => @util.die("todo")
    InvokeDirect(_) => @util.die("todo")
    Malloc(_) => @util.die("todo")

    // Phi
    Phi(_) => ()
  }
}
