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
  let invokes = self.machine.body.stmts.filter(fn { s => s.is_invoke() })
  invokes.length() == 0
}

fn LinearAllocator::optimize_invoke_load_store(
  self : LinearAllocator,
  funcs : Array[AssemblyFunction]
) -> Unit {
  // For each block, do local analysis
  self.method.body.blocks.each(
    fn {
      block => {
        // 1. analyze local liveness info
        let liveness = Map::from_array(
          block.stmts.map(fn { stmt => (stmt.slot, Map::new()) }),
        )
        for i = block.stmts.length() - 1; i >= 0; i = i - 1 {
          let after_liveness = if i == block.stmts.length() - 1 {
            Map::new()
          } else {
            liveness[block.stmts[i + 1].slot].unwrap()
          }
          let after_liveness = Map::from_iter(after_liveness.iter())
          let stmt = block.stmts[i]
          match stmt.def {
            Some(def) => after_liveness.remove(def.memory_id())
            None => ()
          }
          stmt.uses.each(fn { use => after_liveness.set(use.memory_id(), use) })
          liveness.set(stmt.slot, after_liveness)
        }
        // 2.
        let mut prev_invoke_id = -1
        for i = 0; i < block.stmts.length(); i = i + 1 {
          let stmt = block.stmts[i]
          let slot = stmt.slot
          if stmt.is_invoke() {
            if prev_invoke_id == -1 {
              prev_invoke_id = i
            } else {
              let prev_stmt = block.stmts[prev_invoke_id]

              // reg
              let load_store_reg = {
                // Get prev and cur load / store reg
                let prev_load_reg = self.get_saved_reg_before(
                  prev_stmt.def,
                  prev_stmt.slot,
                )
                let cur_store_reg = self.get_saved_reg_before(
                  stmt.def,
                  stmt.slot,
                )
                // intersect prev_load_reg and cur_store_reg
                let load_store_reg = prev_load_reg.filter(
                  fn {
                    info =>
                      not(
                        cur_store_reg
                        .search_by(
                          fn {
                            info2 => info.0.memory_id() == info2.0.memory_id()
                          },
                        )
                        .is_empty(),
                      )
                  },
                )
                let lived = @hashset.from_iter(
                  load_store_reg.iter().map(fn { info => info.0.memory_id() }),
                )
                // Mark def / use var as dirty
                for j = prev_invoke_id + 1; j <= i; j = j + 1 {
                  if j < i {
                    match block.stmts[j].def {
                      Some(def) => lived.remove(def.memory_id())
                      None => ()
                    }
                  }
                  block.stmts[j].uses.each(
                    fn { use => lived.remove(use.memory_id()) },
                  )
                }
                load_store_reg.filter(
                  fn { info => lived.contains(info.0.memory_id()) },
                )
              }
              let load_store_freg = {
                // Get prev and cur load / store reg
                let prev_load_freg = self.get_saved_freg_before(
                  prev_stmt.def,
                  prev_stmt.slot,
                )
                let cur_store_freg = self.get_saved_freg_before(
                  stmt.def,
                  stmt.slot,
                )
                // intersect prev_load_reg and cur_store_reg
                let load_store_freg = prev_load_freg.filter(
                  fn {
                    info =>
                      not(
                        cur_store_freg
                        .search_by(
                          fn {
                            info2 => info.0.memory_id() == info2.0.memory_id()
                          },
                        )
                        .is_empty(),
                      )
                  },
                )
                let lived = @hashset.from_iter(
                  load_store_freg.iter().map(fn { info => info.0.memory_id() }),
                )
                // Mark def / use var as dirty
                for j = prev_invoke_id + 1; j <= i; j = j + 1 {
                  if j < i {
                    match block.stmts[j].def {
                      Some(def) => lived.remove(def.memory_id())
                      None => ()
                    }
                  }
                  block.stmts[j].uses.each(
                    fn { use => lived.remove(use.memory_id()) },
                  )
                }
                load_store_freg.filter(
                  fn { info => lived.contains(info.0.memory_id()) },
                )
              }

              // Unused load-store reg store
              load_store_reg.each(
                fn {
                  info => {
                    @shared.debug(
                      "Skip load / store \{prev_stmt.slot} -> \{slot} : \{info.0}",
                    )
                    self.results[prev_invoke_id].skip_load_vars.insert(
                      info.0.memory_id(),
                    )
                    self.results[slot].skip_store_vars.insert(
                      info.0.memory_id(),
                    )
                  }
                },
              )
              load_store_freg.each(
                fn {
                  info => {
                    @shared.debug(
                      "Skip load / store \{prev_stmt.slot} -> \{slot} : \{info.0}",
                    )
                    self.results[prev_invoke_id].skip_load_vars.insert(
                      info.0.memory_id(),
                    )
                    self.results[slot].skip_store_vars.insert(
                      info.0.memory_id(),
                    )
                  }
                },
              )

              // update prev invoke
              prev_invoke_id = i
            }
          }
        }
      }
    },
  )

  // Analyze leaf call, reg load / store
  self.method.body.stmts.each(
    fn {
      stmt =>
        match stmt.stmt {
          Definition(def, InvokeDirect(label, _, _)) => {
            let used = match funcs.filter(fn { m => m.name == label }) {
              [callee] =>
                if callee.is_leaf {
                  callee.allocator.collect_used_reg()
                } else {
                  None
                }
              _ => None
            }
            match used {
              Some((used_reg, used_freg)) => {
                let result = self.results[stmt.slot]
                let saved_reg = self.get_saved_reg_before(def, stmt.slot)
                let saved_freg = self.get_saved_freg_before(def, stmt.slot)
                saved_reg.each(
                  fn {
                    info => {
                      let used = used_reg.search_by(fn { r => info.1 == r })
                      if used.is_empty() {
                        result.skip_store_vars.insert(info.0.memory_id())
                        result.skip_load_vars.insert(info.0.memory_id())
                      }
                    }
                  },
                )
                saved_freg.each(
                  fn {
                    info => {
                      let used = used_freg.search_by(fn { r => info.1 == r })
                      if used.is_empty() {
                        result.skip_store_vars.insert(info.0.memory_id())
                        result.skip_load_vars.insert(info.0.memory_id())
                      }
                    }
                  },
                )
              }
              None => ()
            }
          }
          _ => ()
        }
    },
  )
}

fn LinearAllocator::get_saved_reg_before(
  self : LinearAllocator,
  def : MachineVar?,
  slot : Int
) -> Array[(MachineVar, Reg)] {
  let ans = []
  let def_id = def.map(fn { d => d.memory_id() }).or(-1)
  let result = self.results[slot]
  for vid, reg in result.reg_map_after {
    if def_id != vid &&
      not(self.is_spilled_by_id(vid)) &&
      reg_caller_saved_list.contains(reg) {
      let var = self.get_global_allocated_int_var(vid)
      if var.const_value.is_empty() {
        ans.push((var, reg))
      }
    }
  }
  ans
}

fn LinearAllocator::get_saved_freg_before(
  self : LinearAllocator,
  def : MachineVar?,
  slot : Int
) -> Array[(MachineVar, FReg)] {
  let ans = []
  let def_id = def.map(fn { d => d.memory_id() }).or(-1)
  let result = self.results[slot]
  for vid, freg in result.freg_map_after {
    if def_id != vid &&
      not(self.is_spilled_by_id(vid)) &&
      freg_caller_saved_list.contains(freg) {
      let var = self.get_global_allocated_float_var(vid)
      if var.const_value.is_empty() {
        ans.push((var, freg))
      }
    }
  }
  ans
}
