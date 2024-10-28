pub fn emit(world : @ssa.World) -> AssemblyProgram {
  // 1. Build machine ir
  let machine = @machine.build_machine_ir(world)
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
}

pub fn emit_asm(self : AssemblyFunction, asm : RvAsm) -> Unit {
  self.body.push(asm)
}

fn emit_method(
  world : MachineWorld,
  method : MachineMethod
) -> AssemblyFunction {
  let asm_func = { name: method.name, export: method.is_main, body: [] }
  asm_func.emit_method_body()
  asm_func
}

fn emit_method_body(self : AssemblyFunction) -> Unit {

}
