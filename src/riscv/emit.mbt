pub fn emit(world : MachineWorld) -> AssemblyProgram {
  let functions = world.methods.map(
    fn { method => create_asm_func(world, method) },
  )
  let prog = { functions, world }
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
  allocator : LinearAllocator
}

pub fn emit_asm(self : AssemblyFunction, asm : RvAsm) -> Unit {
  self.body.push(asm)
}

pub fn emit_comment(self : AssemblyFunction, comment : String) -> Unit {
  self.body.push(Comment(comment))
}

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
    allocator: LinearAllocator::new(method),
  }
  asm_func.allocator.allocate_registor()
  asm_func.allocator.allocate_stack_vars()
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
    if not(var.is_stack) || not(var.is_live) {
      continue
    }
    offset = offset + var.size
    if var.width == Ptr || var.width == Double {
      offset = align_to(offset, 8)
    }
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

  // 1.2. Save reg
  let (saved_reg, saved_freg) = self.allocator.collect_saved_reg()
  if not(self.machine.is_main) &&
    (saved_reg.length() > 0 || saved_freg.length() > 0) {
    let mut i = 0
    for reg in saved_reg {
      i += 8
      self.emit_asm(Sd(reg, MemAccess::new(Sp, -i)))
    }
    for freg in saved_freg {
      i += 8
      self.emit_asm(Fsd(freg, MemAccess::new(Sp, -i)))
    }
    i = align_to(i, 16)
    self.emit_asm(Addi(Sp, Sp, -i))
  }

  // 1.3. store the spilled params
  for var in self.machine.params {
    if self.allocator.is_spilled(var) {
      match var.param_offset {
        Some(Reg(r)) =>
          match var.width {
            Int => self.emit_asm(Sw(r, MemAccess::new(Fp, var.offset)))
            Double => @util.die("unreachable")
            Ptr => self.emit_asm(Sd(r, MemAccess::new(Fp, var.offset)))
          }
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
  }

  // 2.0. Prepare tail call
  if not(self.machine.is_main) &&
    saved_reg.length() == 0 &&
    saved_freg.length() == 0 &&
    enable_tail_call {
    let stmts = self.machine.body.stmts
    let mut i = 0
    while i < stmts.length() {
      let mut j = i + 1
      while j < stmts.length() {
        let cont = match stmts[j].stmt {
          Nop => true
          Comment(_) => true
          _ => false
        }
        if cont {
          j = j + 1
        } else {
          break
        }
      }
      if j < stmts.length() {
        match (stmts[i].stmt, stmts[j].stmt) {
          (Definition(def, InvokeClosure(_)), Return(ret)) =>
            // def == return
            if def.map(fn { v => v.memory_id() }) ==
              ret.map(fn { v => v.memory_id() }) ||
              ret.is_empty() {
              self.machine.tail_calls.insert(stmts[i].slot)
              stmts[j].stmt = Nop
            }
          (Definition(def, InvokeDirect(label, _, _)), Return(ret)) =>
            // def == return
            if def.map(fn { v => v.memory_id() }) ==
              ret.map(fn { v => v.memory_id() }) ||
              ret.is_empty() {
              match @ssa.get_world().externals.get(label) {
                // externals, skip
                Some(_) => ()
                // Our method
                None => {
                  self.machine.tail_calls.insert(stmts[i].slot)
                  stmts[j].stmt = Nop
                }
              }
            }
          _ => ()
        }
      }
      i = j
    }
  }

  // 2. Build stmts
  for block in self.machine.body.blocks {
    if self.machine.body.blocks.length() > 1 {
      self.emit_asm(Label(self.create_label(block.label)))
    }
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
      match rvalue {
        InvokeClosure(callee, args, width) =>
          self.emit_invoke_closure(stmt.slot, None, callee, args, width)
        InvokeDirect(label, args, width) =>
          self.emit_invoke_direct(stmt.slot, None, label, args, width)
        _ => ()
      }
    Definition(Some(def), rvalue) => {
      let store_spilled = self.emit_stmt_rvalue(stmt.slot, def, rvalue)
      if not(store_spilled) && self.allocator.is_spilled(def) {
        match def.width {
          Int => self.emit_asm(Sw(T0, MemAccess::new(Fp, def.offset)))
          Double => self.emit_asm(Fsd(Ft0, MemAccess::new(Fp, def.offset)))
          Ptr => self.emit_asm(Sd(T0, MemAccess::new(Fp, def.offset)))
        }
      }
    }
    Store((recv, offset), expr, width, code) => {
      self.emit_comment("--- Store \{offset}(\{recv.id}) \{expr.id} ---")
      let recv_reg = self.emit_get_int_var(recv, fallback=T0)
      self.emit_sanitizer(recv_reg, code)
      match width {
        Int => {
          let expr_reg = self.emit_get_int_var(expr, fallback=T1)
          // self.emit_sanitizer(expr_reg, code)
          self.emit_asm(Sw(expr_reg, MemAccess::new(recv_reg, offset)))
        }
        Double => {
          let expr_reg = self.emit_get_float_var(expr, fallback=Ft0)
          // self.emit_sanitizer(expr_reg, code)
          self.emit_asm(Fsd(expr_reg, MemAccess::new(recv_reg, offset)))
        }
        Ptr => {
          let expr_reg = self.emit_get_int_var(expr, fallback=T1)
          // self.emit_sanitizer(expr_reg, code)
          self.emit_asm(Sd(expr_reg, MemAccess::new(recv_reg, offset)))
        }
      }
      self.emit_comment("--- Store end ---")
    }
    Sanitizer(var, code) =>
      if enable_sanitizer {
        let reg = self.emit_get_int_var(var, fallback=T0)
        self.emit_sanitizer(reg, code)
      }
    IfGoto(cond, _true_target, false_target) =>
      match cond {
        Eq(lhs, rhs, Int | Ptr)
        | Ne(lhs, rhs, Int | Ptr)
        | Lt(lhs, rhs, Int | Ptr)
        | Le(lhs, rhs, Int | Ptr)
        | Gt(lhs, rhs, Int | Ptr) | Ge(lhs, rhs, Int | Ptr) => {
          let lhs = self.emit_get_int_var(lhs, fallback=T0)
          let rhs = self.emit_get_int_var(rhs, fallback=T1)
          match cond {
            Eq(_, _, Int | Ptr) =>
              self.emit_asm(
                Bne(lhs, rhs, self.create_label(false_target.unwrap())),
              )
            Le(_, _, Int | Ptr) =>
              self.emit_asm(
                Bgt(lhs, rhs, self.create_label(false_target.unwrap())),
              )
            _ => @util.die("todo")
          }
        }
        Eq(lhs, rhs, Double)
        | Ne(lhs, rhs, Double)
        | Lt(lhs, rhs, Double)
        | Le(lhs, rhs, Double) | Gt(lhs, rhs, Double) | Ge(lhs, rhs, Double) => {
          let lhs = self.emit_get_float_var(lhs, fallback=Ft0)
          let rhs = self.emit_get_float_var(rhs, fallback=Ft1)
          match cond {
            Eq(_, _, Double) => {
              self.emit_asm(FeqD(T0, lhs, rhs))
              self.emit_asm(
                Beq(T0, Zero, self.create_label(false_target.unwrap())),
              )
            }
            Le(_, _, Double) => {
              self.emit_asm(FleD(T0, lhs, rhs))
              self.emit_asm(
                Beq(T0, Zero, self.create_label(false_target.unwrap())),
              )
            }
            _ => @util.die("todo")
          }
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
            let freg = self.emit_get_float_var(var, fallback=Ft0)
            self.emit_asm(FmvD(Fa0, freg)) // return fa0
          } else {
            let reg = self.emit_get_int_var(var, fallback=T0)
            self.emit_asm(Mv(A0, reg)) // return a0
          }
        None => ()
      }
      // Epilogue
      // self.emit_asm(Label(self.create_return_label()))
      let (saved_reg, saved_freg) = self.allocator.collect_saved_reg()
      if not(self.machine.is_main) &&
        (saved_reg.length() > 0 || saved_freg.length() > 0) {
        let stack_size = 8 * (saved_reg.length() + saved_freg.length())
        let stack_size = align_to(stack_size, 16)
        self.emit_asm(Addi(Sp, Sp, stack_size))
        let mut i = 0
        for reg in saved_reg {
          i += 8
          self.emit_asm(Ld(reg, MemAccess::new(Sp, -i)))
        }
        for freg in saved_freg {
          i += 8
          self.emit_asm(Fld(freg, MemAccess::new(Sp, -i)))
        }
      }

      // return
      if self.machine.is_main {
        self.emit_asm(Li(A0, "0"))
        self.emit_asm(Li(A7, "93"))
        self.emit_asm(Ecall)
      } else {
        self.emit_asm(Mv(Sp, Fp))
        self.emit_asm(Ld(Fp, MemAccess::new(Sp, 0)))
        self.emit_asm(Ld(Ra, MemAccess::new(Sp, 8)))
        self.emit_asm(Addi(Sp, Sp, 16))
        self.emit_asm(Ret)
      }
    }
  }
}

fn AssemblyFunction::emit_stmt_rvalue(
  self : AssemblyFunction,
  stmt_slot : Int,
  def : MachineVar,
  rvalue : RValue
) -> Bool {
  match rvalue {
    Int(x) =>
      if x == 0 {
        if self.allocator.is_spilled(def) {
          self.emit_asm(Sw(Zero, MemAccess::new(Fp, def.offset)))
        } else {
          let def = self.allocator.get_global_allocated_reg(def)
          self.emit_asm(Mv(def, Zero))
        }
        true
      } else {
        if self.allocator.is_spilled(def) {
          self.emit_asm(Li(T0, x.to_string()))
          self.emit_asm(Sw(T0, MemAccess::new(Fp, def.offset)))
        } else {
          let def = self.allocator.get_global_allocated_reg(def)
          self.emit_asm(Li(def, x.to_string()))
        }
        true
      }
    Neg(expr, Int) => {
      let def_reg = self.allocator.get_global_allocated_reg(def)
      let optimized = match expr.const_value {
        Some(Int(x)) =>
          if -2048 <= -x && -x < 2048 {
            Some(Li(def_reg, (-x).to_string()))
          } else {
            None
          }
        _ => None
      }
      match optimized {
        Some(opt) => self.emit_asm(opt)
        None => {
          let reg = self.emit_get_int_var(expr, fallback=T0)
          self.emit_asm(Sub(def_reg, Zero, reg))
        }
      }
      false
    }
    Neg(expr, Double) => {
      let def = self.allocator.get_global_allocated_freg(def)
      let freg = self.emit_get_float_var(expr, fallback=Ft0)
      self.emit_asm(FnegD(def, freg))
      false
    }
    Neg(_, Ptr) => @util.die("unreachable")
    Prim(lhs, rhs, op, Int) => {
      let def = self.allocator.get_global_allocated_reg(def)
      let optimized = match (lhs.const_value, rhs.const_value) {
        (Some(Int(x)), Some(Int(y))) =>
          match eval_int_bin_op(x, op, y) {
            Some(val) => Some(Li(def, val.to_string()))
            None => None
          }
        (_, Some(Int(x))) =>
          if op == Add && -2048 <= x && x < 2048 {
            let r1 = self.emit_get_int_var(lhs, fallback=T0)
            Some(Addi(def, r1, x))
          } else if op == Mul {
            match is_power_of_two(x) {
              Some(log) => {
                let r1 = self.emit_get_int_var(lhs, fallback=T0)
                if log == 0 {
                  Some(Mv(def, r1))
                } else {
                  Some(Slli(def, r1, log))
                }
              }
              None => None
            }
          } else {
            None
          }
        (Some(Int(x)), _) =>
          if op == Add && -2048 <= x && x < 2048 {
            let r2 = self.emit_get_int_var(rhs, fallback=T1)
            Some(Addi(def, r2, x))
          } else {
            None
          }
        _ => None
      }
      self.emit_asm(
        match optimized {
          Some(opt) => opt
          None => {
            let r1 = self.emit_get_int_var(lhs, fallback=T0)
            let r2 = self.emit_get_int_var(rhs, fallback=T1)
            match op {
              Add => Add(def, r1, r2)
              Sub => Sub(def, r1, r2)
              Mul => Mulw(def, r1, r2)
              Div => Divw(def, r1, r2)
            }
          }
        },
      )
      false
    }
    Prim(lhs, rhs, op, Ptr) => {
      let def = self.allocator.get_global_allocated_reg(def)
      let optimized = match (lhs.const_value, rhs.const_value) {
        (Some(Int(x)), Some(Int(y))) =>
          if op == Add && -2048 <= x + y && x + y < 2048 {
            Some(Li(def, (x + y).to_string()))
          } else {
            None
          }
        (_, Some(Int(x))) =>
          if op == Add && -2048 <= x && x < 2048 {
            let r1 = self.emit_get_int_var(lhs, fallback=T0)
            Some(Addi(def, r1, x))
          } else if op == Mul {
            match is_power_of_two(x) {
              Some(log) => {
                let r1 = self.emit_get_int_var(lhs, fallback=T0)
                if log == 0 {
                  Some(Mv(def, r1))
                } else {
                  Some(Slli(def, r1, log))
                }
              }
              None => None
            }
          } else {
            None
          }
        (Some(Int(x)), _) =>
          if op == Add && -2048 <= x && x < 2048 {
            let r2 = self.emit_get_int_var(rhs, fallback=T1)
            Some(Addi(def, r2, x))
          } else if op == Mul {
            match is_power_of_two(x) {
              Some(log) => {
                let r2 = self.emit_get_int_var(rhs, fallback=T1)
                if log == 0 {
                  Some(Mv(def, r2))
                } else {
                  Some(Slli(def, r2, log))
                }
              }
              None => None
            }
          } else {
            None
          }
        _ => None
      }
      self.emit_asm(
        match optimized {
          Some(opt) => opt
          None => {
            let r1 = self.emit_get_int_var(lhs, fallback=T0)
            let r2 = self.emit_get_int_var(rhs, fallback=T1)
            match op {
              Add => Add(def, r1, r2)
              Sub => Sub(def, r1, r2)
              Mul => Mul(def, r1, r2)
              Div => Div(def, r2, r2)
            }
          }
        },
      )
      false
    }
    Prim(lhs, rhs, op, Double) => {
      let def = self.allocator.get_global_allocated_freg(def)
      let r1 = self.emit_get_float_var(lhs, fallback=Ft0)
      let r2 = self.emit_get_float_var(rhs, fallback=Ft1)
      self.emit_asm(
        match op {
          Add => FaddD(def, r1, r2)
          Sub => FsubD(def, r1, r2)
          Mul => FmulD(def, r1, r2)
          Div => FdivD(def, r1, r2)
        },
      )
      false
    }
    Var(var, Int) | Var(var, Ptr) => {
      if self.allocator.is_spilled(def) {
        let reg = self.emit_get_int_var(var, fallback=T0)
        self.emit_asm(Sw(reg, MemAccess::new(Fp, def.offset)))
      } else {
        let def = self.allocator.get_global_allocated_reg(def)
        let reg = self.emit_get_int_var(var, fallback=T0)
        self.emit_asm(Mv(def, reg))
      }
      true
    }
    Var(var, Double) => {
      if self.allocator.is_spilled(def) {
        let freg = self.emit_get_float_var(var, fallback=Ft0)
        self.emit_asm(Fsd(freg, MemAccess::new(Fp, def.offset)))
      } else {
        let def = self.allocator.get_global_allocated_freg(def)
        let freg = self.emit_get_float_var(var, fallback=Ft0)
        self.emit_asm(FmvD(def, freg))
      }
      true
    }

    // Load
    Load((recv, offset), Int, code) => {
      let def = self.allocator.get_global_allocated_reg(def)
      let reg = self.emit_get_int_var(recv, fallback=T0)
      self.emit_sanitizer(reg, code)
      self.emit_asm(Lw(def, MemAccess::new(reg, offset)))
      false
    }
    Load((recv, offset), Double, code) => {
      let def = self.allocator.get_global_allocated_freg(def)
      let reg = self.emit_get_int_var(recv, fallback=T0)
      self.emit_sanitizer(reg, code)
      self.emit_asm(Fld(def, MemAccess::new(reg, offset)))
      false
    }
    Load((recv, offset), Ptr, code) => {
      let def = self.allocator.get_global_allocated_reg(def)
      let reg = self.emit_get_int_var(recv, fallback=T0)
      self.emit_sanitizer(reg, code)
      self.emit_asm(Ld(def, MemAccess::new(reg, offset)))
      false
    }
    LoadLabel(label) => {
      let def = self.allocator.get_global_allocated_reg(def)
      self.emit_asm(La(def, label))
      false
    }

    // Invoke
    InvokeClosure(callee, args, width) => {
      self.emit_invoke_closure(stmt_slot, Some(def), callee, args, width)
      true
    }
    InvokeDirect(label, args, width) => {
      self.emit_invoke_direct(stmt_slot, Some(def), label, args, width)
      true
    }
    Malloc(size) => {
      self.emit_invoke_malloc(stmt_slot, def, size)
      true
    }

    // Phi
    Phi(_) => true
  }
}

fn AssemblyFunction::emit_get_int_var(
  self : AssemblyFunction,
  var : MachineVar,
  ~fallback : Reg,
  ~force : Reg? = None,
  ~loc : SourceLoc = _
) -> Reg {
  match var.const_value {
    Some(Int(x)) =>
      if x == 0 {
        match force {
          Some(force) => {
            self.emit_asm(Mv(force, Zero))
            force
          }
          None => Zero
        }
      } else {
        match force {
          Some(force) => {
            self.emit_asm(Li(force, x.to_string()))
            force
          }
          None => {
            self.emit_asm(Li(fallback, x.to_string()))
            fallback
          }
        }
      }
    Some(Double(_)) => @util.die("should be Int")
    None =>
      match var.width {
        Int =>
          if self.allocator.is_spilled(var) {
            self.emit_asm(Lw(fallback, MemAccess::new(Fp, var.offset, ~loc)))
            fallback
          } else {
            let reg = self.allocator.get_global_allocated_reg(var)
            match force {
              Some(force) => {
                self.emit_asm(Mv(force, reg))
                force
              }
              None => reg
            }
          }
        Ptr =>
          if self.allocator.is_spilled(var) {
            self.emit_asm(Ld(fallback, MemAccess::new(Fp, var.offset)))
            fallback
          } else {
            let reg = self.allocator.get_global_allocated_reg(var)
            match force {
              Some(force) => {
                self.emit_asm(Mv(force, reg))
                force
              }
              None => reg
            }
          }
        Double => @util.die("should be Int")
      }
  }
}

fn AssemblyFunction::emit_get_float_var(
  self : AssemblyFunction,
  var : MachineVar,
  ~fallback : FReg,
  ~force : FReg? = None
) -> FReg {
  match var.const_value {
    Some(Int(_)) => @util.die("should be Double")
    Some(Double(x)) => {
      let label = add_double_const(self.world, x)
      match force {
        Some(force) => {
          self.emit_asm(La(T0, label))
          self.emit_asm(Fld(force, MemAccess::new(T0, 0)))
          force
        }
        None => {
          let fallback = self.allocator.get_global_allocated_freg(var)
          self.emit_asm(La(T0, label))
          self.emit_asm(Fld(fallback, MemAccess::new(T0, 0)))
          fallback
        }
      }
    }
    None =>
      if self.allocator.is_spilled(var) {
        self.emit_asm(Fld(fallback, MemAccess::new(Fp, var.offset)))
        fallback
      } else {
        let freg = self.allocator.get_global_allocated_freg(var)
        match force {
          Some(force) => {
            self.emit_asm(FmvD(force, freg))
            force
          }
          None => freg
        }
      }
  }
}

fn AssemblyFunction::emit_invoke_closure(
  self : AssemblyFunction,
  stmt_slot : Int,
  def : MachineVar?,
  callee : MachineVar,
  args : Array[MachineVar],
  width : Width
) -> Unit {
  self.emit_comment("--- invoke_closure \{callee.id} ---")
  self.emit_invoke_save_register(stmt_slot, def, args)
  let new_args = []
  new_args.push_iter(args.iter())
  new_args.push(callee)
  let (stack_size, callee_reg) = self.emit_invoke_args(
    stmt_slot,
    new_args,
    callee=Some(callee),
  )
  match callee_reg {
    // Pass this by reg
    Some(callee_reg) => {
      self.emit_sanitizer(callee_reg, 105)
      self.emit_asm(Ld(T6, MemAccess::new(callee_reg, 0)))
      self.emit_sanitizer(T6, 106)
    }
    // Load this var
    None => {
      let _ = self.emit_get_int_var(callee, fallback=T6, force=Some(T6))
      self.emit_sanitizer(T6, 105)
      self.emit_asm(Ld(T6, MemAccess::new(T6, 0)))
      self.emit_sanitizer(T6, 106)
    }
  }
  if stack_size == 0 && self.machine.tail_calls.contains(stmt_slot) {
    self.emit_asm(Addi(Sp, Sp, self.machine.stack_size))
    self.emit_asm(Addi(T6, T6, 8)) // Skip save ra, fp
    self.emit_asm(Jalr(T6))
    self.emit_comment("--- invoke_closure tail \{callee.id} ---")
  } else {
    self.emit_asm(Jalr(T6))
    if stack_size != 0 {
      self.emit_asm(Addi(Sp, Sp, stack_size))
    }
    match def {
      Some(def) =>
        if self.allocator.is_spilled(def) {
          match width {
            Int => self.emit_asm(Sw(A0, MemAccess::new(Fp, def.offset))) // return fa0
            Double => self.emit_asm(Fsd(Fa0, MemAccess::new(Fp, def.offset))) // return fa0
            Ptr => self.emit_asm(Sd(A0, MemAccess::new(Fp, def.offset))) // return fa0
          }
        } else {
          if width.is_float() {
            let def_freg = self.allocator.get_global_allocated_freg(def)
            self.emit_asm(FmvD(def_freg, Fa0)) // return fa0
          } else {
            let def_reg = self.allocator.get_global_allocated_reg(def)
            self.emit_asm(Mv(def_reg, A0)) // return a0
          }
          ()
        }
      None => ()
    }
    self.emit_invoke_restore_register(stmt_slot, def)
    self.emit_comment("--- invoke_closure \{callee.id} ---")
  }
}

fn AssemblyFunction::emit_invoke_direct(
  self : AssemblyFunction,
  stmt_slot : Int,
  def : MachineVar?,
  label : String,
  args : Array[MachineVar],
  width : Width
) -> Unit {
  self.emit_comment("--- invoke_direct \{label} ---")
  self.emit_invoke_save_register(stmt_slot, def, args)
  let (stack_size, _) = self.emit_invoke_args(stmt_slot, args)
  if stack_size == 0 && self.machine.tail_calls.contains(stmt_slot) {
    self.emit_asm(Addi(Sp, Sp, self.machine.stack_size))
    self.emit_asm(La(T6, label))
    self.emit_asm(Addi(T6, T6, 8)) // Skip save ra, fp
    self.emit_asm(Jalr(T6))
    self.emit_comment("--- invoke_direct tail \{label} ---")
  } else {
    self.emit_asm(Call(label))
    if stack_size != 0 {
      self.emit_asm(Addi(Sp, Sp, stack_size))
    }
    match def {
      Some(def) =>
        if self.allocator.is_spilled(def) {
          match width {
            Int => self.emit_asm(Sw(A0, MemAccess::new(Fp, def.offset))) // return fa0
            Double => self.emit_asm(Fsd(Fa0, MemAccess::new(Fp, def.offset))) // return fa0
            Ptr => self.emit_asm(Sd(A0, MemAccess::new(Fp, def.offset))) // return fa0
          }
        } else {
          if width.is_float() {
            let def_freg = self.allocator.get_global_allocated_freg(def)
            self.emit_asm(FmvD(def_freg, Fa0)) // return fa0
          } else {
            let def_reg = self.allocator.get_global_allocated_reg(def)
            self.emit_asm(Mv(def_reg, A0)) // return a0
          }
          ()
        }
      None => ()
    }
    self.emit_invoke_restore_register(stmt_slot, def)
    self.emit_comment("--- invoke_direct \{label} ---")
  }
}

fn AssemblyFunction::emit_invoke_malloc(
  self : AssemblyFunction,
  stmt_slot : Int,
  def : MachineVar,
  size : Int
) -> Unit {
  self.emit_comment("--- malloc \{size} ---")
  self.emit_invoke_save_register(stmt_slot, Some(def), [])
  self.emit_asm(Li(A0, size.to_string()))
  self.emit_asm(Call("minimbt_malloc"))
  self.emit_sanitizer(A0, 142)
  if self.allocator.is_spilled(def) {
    self.emit_asm(Sd(A0, MemAccess::new(Fp, def.offset)))
  } else {
    let def_reg = self.allocator.get_global_allocated_reg(def)
    self.emit_asm(Mv(def_reg, A0))
  }
  self.emit_invoke_restore_register(stmt_slot, Some(def))
  self.emit_comment("--- malloc \{size} ---")
}

fn AssemblyFunction::emit_invoke_save_register(
  self : AssemblyFunction,
  slot : Int,
  def : MachineVar?,
  _args : Array[MachineVar]
) -> Unit {
  let def_id = def.map(fn { d => d.memory_id() }).or(-1)
  let result = self.allocator.results[slot]
  for vid, reg in result.reg_map_after {
    if vid != def_id &&
      not(self.allocator.is_spilled_by_id(vid)) &&
      reg_caller_saved_list.contains(reg) {
      let var = self.allocator.get_global_allocated_int_var(vid)
      if var.const_value.is_empty() {
        match var.width {
          Int => self.emit_asm(Sw(reg, MemAccess::new(Fp, var.offset)))
          Double => @util.die("unreachable")
          Ptr => self.emit_asm(Sd(reg, MemAccess::new(Fp, var.offset)))
        }
      }
    }
  }
  for vid, freg in result.freg_map_after {
    if vid != def_id &&
      not(self.allocator.is_spilled_by_id(vid)) &&
      freg_caller_saved_list.contains(freg) {
      let var = self.allocator.get_global_allocated_float_var(vid)
      if var.const_value.is_empty() {
        self.emit_asm(Fsd(freg, MemAccess::new(Fp, var.offset)))
      }
    }
  }
}

fn AssemblyFunction::emit_invoke_restore_register(
  self : AssemblyFunction,
  slot : Int,
  def : MachineVar?
) -> Unit {
  let def_id = def.map(fn { d => d.memory_id() }).or(-1)
  let result = self.allocator.results[slot]
  for vid, reg in result.reg_map_after {
    if vid != def_id &&
      not(self.allocator.is_spilled_by_id(vid)) &&
      reg_caller_saved_list.contains(reg) {
      let var = self.allocator.get_global_allocated_int_var(vid)
      if var.const_value.is_empty() {
        match var.width {
          Int => self.emit_asm(Lw(reg, MemAccess::new(Fp, var.offset)))
          Double => @util.die("unreachable")
          Ptr => self.emit_asm(Ld(reg, MemAccess::new(Fp, var.offset)))
        }
      }
    }
  }
  for vid, freg in result.freg_map_after {
    if vid != def_id &&
      not(self.allocator.is_spilled_by_id(vid)) &&
      freg_caller_saved_list.contains(freg) {
      let var = self.allocator.get_global_allocated_float_var(vid)
      if var.const_value.is_empty() {
        self.emit_asm(Fld(freg, MemAccess::new(Fp, var.offset)))
      }
    }
  }
}

fn AssemblyFunction::emit_invoke_args(
  self : AssemblyFunction,
  slot : Int,
  args : Array[MachineVar],
  ~callee : MachineVar? = None
) -> (Int, Reg?) {
  let callee_id = callee.map(fn { c => c.memory_id() }).or(-1)

  // Map
  let reg_arg = Map::new()
  let freg_arg = Map::new()

  // Calc stack
  let mut gp = 0
  let mut fp = 0
  let mut offset = 0
  let mut this_reg = None
  let stack = []
  for i = 0; i < args.length(); i = i + 1 {
    let arg = args[i]
    if arg.width.is_float() {
      if fp < freg_arg_list.length() {
        freg_arg.set(freg_arg_list[fp], arg)
        fp += 1
      } else {
        offset += arg.size
        stack.push(arg)
      }
      ()
    } else {
      if gp < reg_arg_list.length() {
        reg_arg.set(reg_arg_list[gp], arg)
        if callee_id == arg.memory_id() {
          this_reg = Some(reg_arg_list[gp])
        }
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
  offset = 0
  stack.each(
    fn {
      arg => {
        match arg.width {
          Int => {
            let reg = self.emit_get_int_var(arg, fallback=T0)
            self.emit_asm(Sw(reg, MemAccess::new(Sp, offset)))
          }
          Double => {
            let reg = self.emit_get_float_var(arg, fallback=Ft0)
            self.emit_asm(Fsd(reg, MemAccess::new(Sp, offset)))
          }
          Ptr => {
            let reg = self.emit_get_int_var(arg, fallback=T0)
            self.emit_asm(Sd(reg, MemAccess::new(Sp, offset)))
          }
        }
        offset += arg.size
      }
    },
  )

  // 2. Generate pass param by reg
  let allow_reg = reg_temp_list + reg_arg_rev_list
  let active_reg_var = self.allocator.get_invoke_reg_map(
    args,
    self.allocator.results[slot].reg_map_before,
  )
  let active_var_reg = Map::from_iter(
    active_reg_var.iter().map(fn { (reg, var) => (var.memory_id(), reg) }),
  )
  let allow_freg = freg_temp_list + freg_arg_rev_list
  let active_freg_var = self.allocator.get_invoke_reg_map(
    args,
    self.allocator.results[slot].freg_map_before,
  )
  let active_var_freg = Map::from_iter(
    active_freg_var.iter().map(fn { (reg, var) => (var.memory_id(), reg) }),
  )

  // 2.1. Move reg
  for item in reg_arg {
    let (reg, arg) = item // target reg <- arg
    // Check which var is the current reg
    match active_reg_var.get(reg) {
      Some(var) =>
        if var.memory_id() == arg.memory_id() {
          // Ok
          ()
        } else {
          // This reg is occupied by other var
          match args.search_by(fn { a => a.memory_id() == var.memory_id() }) {
            Some(_) =>
              // active var -> reg is another param, should move to other place
              // 1. find an empty reg
              match
                allow_reg.search_by(
                  fn { reg => active_reg_var.get(reg).is_empty() },
                ) {
                Some(temp) => {
                  let temp = allow_reg[temp]
                  self.emit_asm(Mv(temp, reg)) // move reg to a temp pos
                  active_reg_var.set(temp, var)
                  active_var_reg.set(var.memory_id(), temp)
                  match active_var_reg.get(arg.memory_id()) {
                    // arg is in the reg
                    Some(arg_reg) => {
                      active_reg_var.remove(arg_reg)
                      self.emit_asm(Mv(reg, arg_reg))
                    }
                    // arg is not in the reg
                    None => {
                      let _ = self.emit_get_int_var(
                        arg,
                        fallback=reg,
                        force=Some(reg),
                      )
                      ()
                    }
                  }
                  active_reg_var.set(reg, arg)
                  active_var_reg.set(arg.memory_id(), reg)
                }
                None => @util.die("unreachable")
              }
            None => {
              // var is not arg, overwrite it with arg
              match active_var_reg.get(arg.memory_id()) {
                // arg is in the reg
                Some(arg_reg) => {
                  active_reg_var.remove(arg_reg)
                  self.emit_asm(Mv(reg, arg_reg))
                }
                // arg is not in the reg
                None => {
                  let _ = self.emit_get_int_var(
                    arg,
                    fallback=reg,
                    force=Some(reg),
                  )
                  ()
                }
              }
              active_var_reg.set(arg.memory_id(), reg)
              active_reg_var.set(reg, arg)
            }
          }
        }
      None => {
        // No one use this reg
        match active_var_reg.get(arg.memory_id()) {
          // arg is in the reg
          Some(arg_reg) => {
            active_reg_var.remove(arg_reg)
            self.emit_asm(Mv(reg, arg_reg))
          }
          // arg is not in the reg
          None => {
            let _ = self.emit_get_int_var(arg, fallback=reg, force=Some(reg))
            ()
          }
        }
        active_var_reg.set(arg.memory_id(), reg)
        active_reg_var.set(reg, arg)
      }
    }
  }

  // 2.2. Move freg
  for item in freg_arg {
    let (freg, arg) = item // target reg <- arg
    // Check which var is the current reg
    match active_freg_var.get(freg) {
      Some(var) =>
        if var.memory_id() == arg.memory_id() {
          // Ok
          ()
        } else {
          // This reg is occupied by other var
          match args.search_by(fn { a => a.memory_id() == var.memory_id() }) {
            Some(_) =>
              // active var -> reg is another param, should move to other place
              // 1. find an empty reg
              match
                allow_freg.search_by(
                  fn { freg => active_freg_var.get(freg).is_empty() },
                ) {
                Some(temp) => {
                  let temp = allow_freg[temp]
                  self.emit_asm(FmvD(temp, freg)) // move reg to a temp pos
                  active_freg_var.set(temp, var)
                  active_var_freg.set(var.memory_id(), temp)
                  match active_var_freg.get(arg.memory_id()) {
                    // arg is in the reg
                    Some(arg_freg) => {
                      active_freg_var.remove(arg_freg)
                      self.emit_asm(FmvD(freg, arg_freg))
                    }
                    // arg is not in the reg
                    None => {
                      let _ = self.emit_get_float_var(
                        arg,
                        fallback=freg,
                        force=Some(freg),
                      )
                      ()
                    }
                  }
                  active_freg_var.set(freg, arg)
                  active_var_freg.set(arg.memory_id(), freg)
                }
                None => @util.die("unreachable")
              }
            None => {
              // var is not arg, overwrite it with arg
              match active_var_freg.get(arg.memory_id()) {
                // arg is in the reg
                Some(arg_freg) => {
                  active_freg_var.remove(arg_freg)
                  self.emit_asm(FmvD(freg, arg_freg))
                }
                // arg is not in the reg
                None => {
                  let _ = self.emit_get_float_var(
                    arg,
                    fallback=freg,
                    force=Some(freg),
                  )
                  ()
                }
              }
              active_var_freg.set(arg.memory_id(), freg)
              active_freg_var.set(freg, arg)
            }
          }
        }
      None => {
        // No one use this reg
        match active_var_freg.get(arg.memory_id()) {
          // arg is in the reg
          Some(arg_freg) => {
            active_freg_var.remove(arg_freg)
            self.emit_asm(FmvD(freg, arg_freg))
          }
          // arg is not in the reg
          None => {
            let _ = self.emit_get_float_var(
              arg,
              fallback=freg,
              force=Some(freg),
            )
            ()
          }
        }
        active_var_freg.set(arg.memory_id(), freg)
        active_freg_var.set(freg, arg)
      }
    }
  }

  //
  (stack_size, this_reg)
}

fn LinearAllocator::get_invoke_reg_map[TReg : Eq + Hash](
  self : LinearAllocator,
  args : Array[MachineVar],
  active_reg : Map[Int, TReg]
) -> Map[TReg, MachineVar] {
  let map = Map::new()
  for vid, reg in active_reg {
    // Only args should be kept
    match args.search_by(fn { a => a.memory_id() == vid }) {
      Some(_) => {
        let var = self.method.local_vars
          .search_by(fn { v => v.id == vid })
          .unwrap()
        let var = self.method.local_vars[var]
        map.set(reg, var)
      }
      None => ()
    }
  }
  map
}
