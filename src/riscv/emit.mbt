pub fn emit(world : @ssa.World) -> AssemblyProgram {
  // 1. Build machine ir
  let machine = build_machine_ir(world)
  // 2. Optimizing todo
  // 3. Generate final asm
  let functions = machine.methods.map(
    fn { method => create_asm_func(machine, method) },
  )
  let prog = { functions, world: machine }
  functions.each(fn { func => func.emit_method_body() })
  prog
}

pub struct AssemblyProgram {
  functions : Array[AssemblyFunction]
  world : MachineWorld
}

pub struct AssemblyFunction {
  name : String
  label : String
  export : Bool
  body : Array[RvAsm]
  machine : MachineMethod
  world : MachineWorld
}

pub fn emit_asm(self : AssemblyFunction, asm : RvAsm) -> Unit {
  self.body.push(asm)
}

pub fn emit_comment(self : AssemblyFunction, comment : String) -> Unit {
  self.body.push(Comment(comment))
}

pub fn emit_sanitizer(self : AssemblyFunction, reg : Reg, code : Int) -> Unit {
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

fn create_asm_func(
  world : MachineWorld,
  method : MachineMethod
) -> AssemblyFunction {
  let asm_func = {
    name: method.name,
    label: method.label,
    export: method.is_main,
    body: [],
    machine: method,
    world,
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
    if var.width.is_float() {
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
  stack_params.each(
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
    // Not a const value
    if not(var.const_value.is_empty()) || not(var.is_live) {
      continue
    }
    offset = offset + var.size
    var.offset = -offset
    self.machine.stack_vars.set(var.id, var)
  }
  // 2.2. Phi vars
  for _, var in self.machine.local_vars {
    // Var is not merged by a phi node
    match var.outcoming_var {
      Some(outcomming) => var.offset = outcomming.offset
      None => ()
    }
  }
  self.machine.stack_size = align_to(offset, 16)
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
        match var.width {
          Int => {
            self.emit_asm(Lw(T0, MemAccess::new(Fp, offset)))
            self.emit_asm(Sw(T0, MemAccess::new(Fp, var.offset)))
          }
          Double => {
            self.emit_asm(Fld(Ft0, MemAccess::new(Fp, offset)))
            self.emit_asm(Fsd(Ft0, MemAccess::new(Fp, var.offset)))
          }
          Ptr => {
            self.emit_asm(Ld(T0, MemAccess::new(Fp, offset)))
            self.emit_asm(Sd(T0, MemAccess::new(Fp, var.offset)))
          }
        }
      None => @util.die("unreachable")
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
    Definition(_, Phi(_)) => ()
    Definition(None, rvalue) =>
      self.emit_method_rvalue(rvalue, fn { _ => () }, fn { _ => () })
    Definition(Some(def), rvalue) =>
      self.emit_method_rvalue(
        rvalue,
        fn {
          reg =>
            match def.width {
              Int => self.emit_asm(Sw(reg, MemAccess::new(Fp, def.offset)))
              Double => @util.die("should be int")
              Ptr => self.emit_asm(Sd(reg, MemAccess::new(Fp, def.offset)))
            }
        },
        fn { freg => self.emit_asm(Fsd(freg, MemAccess::new(Fp, def.offset))) },
      )
    Store((recv, offset), expr, width, code) => {
      self.emit_comment("--- Store \{offset}(\{recv.id}) \{expr.id} ---")
      self.emit_get_int_var(T0, recv)
      self.emit_sanitizer(T0, code + 3)
      match width {
        Int => {
          self.emit_get_int_var(T1, expr)
          self.emit_sanitizer(T0, code)
          self.emit_asm(Sw(T1, MemAccess::new(T0, offset)))
        }
        Double => {
          self.emit_get_float_var(Ft0, expr)
          self.emit_sanitizer(T0, code + 1)
          self.emit_asm(Fsd(Ft0, MemAccess::new(T0, offset)))
        }
        Ptr => {
          self.emit_get_int_var(T1, expr)
          self.emit_sanitizer(T0, code + 2)
          self.emit_asm(Sd(T1, MemAccess::new(T0, offset)))
        }
      }
      self.emit_comment("--- Store end ---")
    }
    Sanitizer(var, code) => {
      self.emit_get_int_var(T0, var)
      self.emit_sanitizer(T0, code)
    }
    IfGoto(cond, _true_target, false_target) => {
      match cond {
        Eq(lhs, rhs, Int)
        | Ne(lhs, rhs, Int)
        | Lt(lhs, rhs, Int)
        | Le(lhs, rhs, Int) | Gt(lhs, rhs, Int) | Ge(lhs, rhs, Int) => {
          self.emit_get_int_var(T0, lhs)
          self.emit_get_int_var(T1, rhs)
        }
        Eq(lhs, rhs, Double)
        | Ne(lhs, rhs, Double)
        | Lt(lhs, rhs, Double)
        | Le(lhs, rhs, Double) | Gt(lhs, rhs, Double) | Ge(lhs, rhs, Double) => {
          self.emit_get_float_var(Ft0, lhs)
          self.emit_get_float_var(Ft1, rhs)
        }
        Eq(lhs, rhs, Ptr)
        | Ne(lhs, rhs, Ptr)
        | Lt(lhs, rhs, Ptr)
        | Le(lhs, rhs, Ptr) | Gt(lhs, rhs, Ptr) | Ge(lhs, rhs, Ptr) => {
          self.emit_get_int_var(T0, lhs)
          self.emit_get_int_var(T1, rhs)
        }
      }
      match cond {
        Eq(_, _, Int | Ptr) =>
          self.emit_asm(Bne(T0, T1, self.create_label(false_target.unwrap())))
        Eq(_, _, Double) => {
          self.emit_asm(FeqD(T0, Ft0, Ft1))
          self.emit_asm(Beq(T0, Zero, self.create_label(false_target.unwrap())))
        }
        Le(_, _, Int | Ptr) =>
          self.emit_asm(Bgt(T0, T1, self.create_label(false_target.unwrap())))
        Le(_, _, Double) => {
          self.emit_asm(FleD(T0, Ft0, Ft1))
          self.emit_asm(Beq(T0, Zero, self.create_label(false_target.unwrap())))
        }
        _ => @util.die("todo")
      }
    }
    Goto(label) => self.emit_asm(J(self.create_label(label)))
    Comment(comment) => self.emit_asm(Comment(comment))
    Nop => ()
    Return(var) => {
      self.emit_comment("--- Return \{self.name} ---")
      match var {
        Some(var) =>
          if var.width.is_float() {
            self.emit_get_float_var(Fa0, var)
          } else {
            self.emit_get_int_var(A0, var)
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
    Int(x) =>
      if x == 0 {
        contg(Zero)
      } else {
        self.emit_asm(Li(T0, x.to_string()))
        contg(T0)
      }
    Neg(expr, Int) => {
      self.emit_get_int_var(T0, expr)
      self.emit_asm(Sub(T0, Zero, T0))
      contg(T0)
    }
    Neg(expr, Double) => {
      self.emit_get_float_var(Ft0, expr)
      self.emit_asm(FnegD(Ft0, Ft0))
      contf(Ft0)
    }
    Neg(_, Ptr) => @util.die("unreachable")
    Prim(lhs, rhs, op, Int) => {
      self.emit_get_int_var(T0, lhs)
      self.emit_get_int_var(T1, rhs)
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
      self.emit_get_float_var(Ft0, lhs)
      self.emit_get_float_var(Ft1, rhs)
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
    Prim(_, _, _, Ptr) => @util.die("unreachable")
    Var(var, Int) | Var(var, Ptr) => {
      self.emit_get_int_var(T0, var)
      contg(T0)
    }
    Var(var, Double) => {
      self.emit_get_float_var(Ft0, var)
      contf(Ft0)
    }

    // Load
    Load((recv, offset), Int) => {
      self.emit_get_int_var(T0, recv)
      self.emit_sanitizer(T0, 203)
      self.emit_asm(Lw(T0, MemAccess::new(T0, offset)))
      contg(T0)
    }
    Load((recv, offset), Double) => {
      self.emit_get_int_var(T0, recv)
      self.emit_sanitizer(T0, 204)
      self.emit_asm(Fld(Ft0, MemAccess::new(T0, offset)))
      contf(Ft0)
    }
    Load((recv, offset), Ptr) => {
      self.emit_get_int_var(T0, recv)
      self.emit_sanitizer(T0, 205)
      self.emit_asm(Ld(T0, MemAccess::new(T0, offset)))
      contg(T0)
    }
    LoadLabel(label) => {
      self.emit_asm(La(T0, label))
      // clear high 32 bits
      self.emit_asm(Slli(T0, T0, 32))
      self.emit_asm(Srli(T0, T0, 32))
      // ----------
      contg(T0)
    }

    // Invoke
    InvokeClosure(callee, args, width) => {
      self.emit_comment("--- invoke_closure \{callee.id} ---")
      let new_args = []
      new_args.push_iter(args.iter())
      new_args.push(callee)
      let stack_size = self.emit_invoke_args(new_args)
      self.emit_get_int_var(T5, callee)
      self.emit_sanitizer(T5, 205)
      self.emit_asm(Lw(T5, MemAccess::new(T5, 0)))
      self.emit_asm(Jalr(T5))
      if stack_size != 0 {
        self.emit_asm(Addi(Sp, Sp, stack_size))
      }
      self.emit_comment("--- invoke_closure \{callee.id} ---")
      match width {
        Int | Ptr => contg(A0)
        Double => contf(Fa0)
      }
    }
    InvokeDirect(label, args, width) => {
      self.emit_comment("--- invoke_direct \{label} ---")
      let stack_size = self.emit_invoke_args(args)
      self.emit_asm(Call(label))
      if stack_size != 0 {
        self.emit_asm(Addi(Sp, Sp, stack_size))
      }
      self.emit_comment("--- invoke_direct \{label} ---")
      match width {
        Int | Ptr => contg(A0)
        Double => contf(Fa0)
      }
    }
    Malloc(size) => {
      self.emit_comment("--- malloc \{size} ---")
      self.emit_asm(Li(A0, size.to_string()))
      self.emit_asm(Call("minimbt_malloc"))
      self.emit_sanitizer(A0, 142)
      self.emit_sanitizer(A0, 143)
      self.emit_sanitizer(A0, 144)
      self.emit_sanitizer(A0, 145)
      self.emit_comment("--- malloc \{size} ---")
      contg(A0)
    }

    // Phi
    Phi(_) => ()
  }
}

fn AssemblyFunction::emit_get_int_var(
  self : AssemblyFunction,
  reg : Reg,
  var : MachineVar
) -> Unit {
  match var.const_value {
    Some(Int(x)) =>
      if x == 0 {
        self.emit_asm(Mv(reg, Zero))
      } else {
        self.emit_asm(Li(reg, x.to_string()))
      }
    Some(Double(_)) => @util.die("should be Int")
    None =>
      match var.width {
        Int => self.emit_asm(Lw(reg, MemAccess::new(Fp, var.offset)))
        Ptr => self.emit_asm(Ld(reg, MemAccess::new(Fp, var.offset)))
        Double => @util.die("should be Int")
      }
  }
}

fn AssemblyFunction::emit_get_float_var(
  self : AssemblyFunction,
  reg : FReg,
  var : MachineVar
) -> Unit {
  match var.const_value {
    Some(Int(_)) => @util.die("should be Double")
    Some(Double(x)) => {
      let label = add_double_const(self.world, x)
      self.emit_asm(La(T0, label))
      self.emit_asm(Fld(reg, MemAccess::new(T0, 0)))
    }
    None => self.emit_asm(Fld(reg, MemAccess::new(Fp, var.offset)))
  }
}

fn AssemblyFunction::emit_invoke_args(
  self : AssemblyFunction,
  args : Array[MachineVar]
) -> Int {
  let mut gp = 0
  let mut fp = 0
  let mut offset = 0
  let stack = []
  for i = 0; i < args.length(); i = i + 1 {
    let arg = args[i]
    if arg.width.is_float() {
      if fp < freg_arg_list.length() {
        fp += 1
      } else {
        offset += arg.size
        stack.push(arg)
      }
      ()
    } else {
      if gp < reg_arg_list.length() {
        gp += 1
      } else {
        offset += arg.size
        stack.push(arg)
      }
      ()
    }
  }

  // 1. Pass by stack in reverse
  let stack_size = if offset != 0 {
    let stack_size = align_to(offset, 16)
    self.emit_asm(Addi(Sp, Sp, -stack_size))
    stack_size
  } else {
    0
  }
  stack.each(
    fn {
      arg => {
        match arg.width {
          Int => {
            self.emit_get_int_var(T0, arg)
            self.emit_asm(Sw(T0, MemAccess::new(Sp, offset)))
          }
          Double => {
            self.emit_get_float_var(Ft0, arg)
            self.emit_asm(Fsd(Ft0, MemAccess::new(Sp, offset)))
          }
          Ptr => {
            self.emit_get_int_var(T0, arg)
            self.emit_asm(Sd(T0, MemAccess::new(Sp, offset)))
          }
        }
        offset += arg.size
      }
    },
  )

  // 2. Pass by reg
  gp = 0
  fp = 0
  for i = 0; i < args.length(); i = i + 1 {
    let arg = args[i]
    if arg.width.is_float() {
      if fp < freg_arg_list.length() {
        let freg = freg_arg_list[fp]
        self.emit_get_float_var(freg, arg)
        fp += 1
      } else {
        ()
      }
      ()
    } else {
      if gp < reg_arg_list.length() {
        let reg = reg_arg_list[gp]
        self.emit_get_int_var(reg, arg)
        gp += 1
      } else {
        ()
      }
      ()
    }
  }
  stack_size
}
