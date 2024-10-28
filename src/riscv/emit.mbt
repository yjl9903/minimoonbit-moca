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
  // Save ra and fp
  self.emit_asm(Addi(Sp, Sp, -16))
  self.emit_asm(Sd(Ra, MemAccess::new(Sp, 8)))
  self.emit_asm(Sd(Fp, MemAccess::new(Sp, 0)))
  self.emit_asm(Mv(Fp, Sp))
  // TODO: save reg

  // 1. Calc stack size
  self.emit_asm(Addi(Sp, Sp, -self.machine.stack_size))

  // 2. TEMP: store the params
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

  // 3. Build stmts
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
    Definition(None, rvalue) => self.emit_method_rvalue(rvalue)
    Definition(Some(def), rvalue) => self.emit_method_rvalue(rvalue)
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
    IfGoto(_) => @util.die("")
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
      // TODO: restore things
      self.emit_asm(Ret)
    }
  }
}

fn AssemblyFunction::emit_method_rvalue(
  self : AssemblyFunction,
  rvalue : RValue
) -> Unit {

}

fn AssemblyFunction::create_label(
  self : AssemblyFunction,
  label : Int
) -> String {
  "__\{self.name}__B\{label}"
}
