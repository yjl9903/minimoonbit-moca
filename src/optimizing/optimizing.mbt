pub struct Manager {
  ast_passes : Array[AstOptPass]
  knf_passes : Array[KnfOptPass]
  closure_passes : Array[ClosureOptPass]
  ssa_passes : Array[SsaOptPass]
  machine_passes : Array[MachineOptPass]
  asm_passes : Array[AssemblyOptPass]
}

pub fn Manager::new() -> Manager {
  {
    ast_passes: [],
    knf_passes: [],
    closure_passes: [],
    ssa_passes: [],
    machine_passes: [],
    asm_passes: [],
  }
}

pub fn Manager::add_opt_pass(self : Manager, pass : Pass) -> Manager {
  match pass {
    Ast(p) => self.ast_passes.push(p)
    Knf(p) => self.knf_passes.push(p)
    Closure(p) => self.closure_passes.push(p)
    Ssa(p) => self.ssa_passes.push(p)
    Machine(p) => self.machine_passes.push(p)
    Assembly(p) => self.asm_passes.push(p)
  }
  self
}

pub fn Manager::add_opt_passes(self : Manager, passes : Array[Pass]) -> Manager {
  passes.each(
    fn {
      p => {
        let _ = self.add_opt_pass(p)
        ()
      }
    },
  )
  self
}

pub fn Manager::optimize_ast(
  self : Manager,
  ast : @types.Syntax
) -> @types.Syntax {
  let result = self.ast_passes.fold(
    init=ast,
    fn { ast, pass => pass.optimize(ast) },
  )
  result
}

pub fn Manager::optimize_knf(self : Manager, knf : @knf.Knf) -> @knf.Knf {
  self.knf_passes.fold(init=knf, fn { knf, pass => pass.optimize(knf) })
}

pub fn Manager::optimize_closure_ir(
  _self : Manager,
  _prog : @closure.Program
) -> @closure.Program {
  abort("")
}

pub fn Manager::optimize_ssa_ir(self : Manager, world : @ssa.World) -> Unit {
  self.ssa_passes.each(
    fn {
      pass => {
        pass.optimize_world(world)
        pass.optimize(world.main_method)
        world.methods.values().each(fn { m => pass.optimize(m) })
      }
    },
  )
}

pub fn Manager::optimize_machine_ir(
  self : Manager,
  world : @riscv.MachineWorld
) -> Unit {
  self.machine_passes.each(
    fn { pass => world.methods.each(fn { m => pass.optimize(m) }) },
  )
}

pub fn Manager::optimize_assembly(
  self : Manager,
  world : @riscv.AssemblyProgram
) -> Unit {
  self.asm_passes.each(
    fn { pass => world.functions.each(fn { m => pass.optimize(m) }) },
  )
}
