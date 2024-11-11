fn AssemblyFunction::optimize_tail_call(
  self : AssemblyFunction,
  saved_reg : Array[Reg],
  saved_freg : Array[FReg]
) -> Unit {
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
}

fn AssemblyFunction::optimize_leaf(self : AssemblyFunction) -> Bool {
  let invokes = self.machine.body.stmts.filter(
    fn {
      s =>
        match s.stmt {
          Definition(_, InvokeDirect(_) | InvokeClosure(_) | Malloc(_)) => true
          _ => false
        }
    },
  )
  invokes.length() == 0
}
