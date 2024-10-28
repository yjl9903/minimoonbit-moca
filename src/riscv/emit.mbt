pub fn emit(world : @ssa.World) -> AssemblyProgram {
  // 1. Build machine ir
  let machine = build_machine_ir(world)
  // 2. Optimizing todo
  // 3. Generate final asm
  let functions = machine.methods.map(
    fn { method => emit_method(machine, method) },
  )
  let prog = { functions, }
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

fn emit_method(
  world : MachineWorld,
  method : MachineMethod
) -> AssemblyFunction {
  let asm_func = {
    name: method.name,
    export: method.is_main,
    body: [],
    machine: method,
  }
  asm_func.emit_method_body()
  asm_func
}

fn calc_stack_size(self : AssemblyFunction) -> Unit {
  self.machine.stack_vars.clear()
  // let mut gp = 0
  // let mut fp = 0
  // for var in self.machine.params {

  // }
  let mut offset = 0
  for _, var in self.machine.local_vars {
    if var.outcoming_var.is_empty() {
      // Var is not merged by a phi node
      var.offset = -offset
      offset = offset + var.size
      self.machine.stack_vars.set(var.id, var)
    }
  }
  self.machine.stack_size = offset
}

fn emit_method_body(self : AssemblyFunction) -> Unit {
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
  self.calc_stack_size()
  self.emit_asm(Addi(Sp, Sp, -self.machine.stack_size))

  // 2. Build stmts
}
