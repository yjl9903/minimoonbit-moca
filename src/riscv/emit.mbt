pub fn emit(world : @ssa.World) -> AssemblyProgram {
  // 1. Build machine ir
  let machine = @machine.build_machine_ir(world)
  // 2. Optimizing todo
  // 3. Generate final asm
  let functions = machine.methods.map(
    fn { method => emit_function(machine, method) },
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

fn emit_function(
  world : MachineWorld,
  method : MachineMethod
) -> AssemblyFunction {
  @util.die("todo")
}
