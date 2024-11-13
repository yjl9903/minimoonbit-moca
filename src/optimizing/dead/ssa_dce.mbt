pub fn remove_ssa_dead_code(world : @ssa.World) -> Unit {
  // 1. Remove global dead
  remove_dead_global_variables(world)
  // 2. Remove method dead
  remove_ssa_method_dead_code(world.main_method)
  world.methods
  .values()
  .each(fn { method => remove_ssa_method_dead_code(method) })
}

fn remove_dead_global_variables(world : @ssa.World) -> Unit {
  let def_globals : @hashmap.T[Int, Int] = @hashmap.new()
  let use_globals : @hashmap.T[Int, Int] = @hashmap.new()
  let def_globals_from : @hashmap.T[Int, @hashset.T[String]] = @hashmap.new()
  let use_globals_from : @hashmap.T[Int, @hashset.T[String]] = @hashmap.new()
  let removed = @hashset.new()

  // 1. Collect global vars def / use
  fn collect(method : @ssa.Method) {
    method.body.stmts.each(
      fn {
        stmt => {
          match stmt.def {
            Some(def) =>
              if def.is_global {
                def_globals[def.id] = def_globals.get_or_default(def.id, 0) + 1
                let def_globals_from = match def_globals_from.get(def.id) {
                  Some(def_globals_from) => def_globals_from
                  None => {
                    let set = @hashset.new()
                    def_globals_from.set(def.id, set)
                    set
                  }
                }
                def_globals_from.insert(method.name)
              }
            None => ()
          }
          stmt.uses.each(
            fn {
              use =>
                if use.is_global {
                  use_globals[use.id] = use_globals.get_or_default(use.id, 0) +
                    1
                  let use_globals_from = match use_globals_from.get(use.id) {
                    Some(use_globals_from) => use_globals_from
                    None => {
                      let set = @hashset.new()
                      use_globals_from.set(use.id, set)
                      set
                    }
                  }
                  use_globals_from.insert(method.name)
                }
            },
          )
        }
      },
    )
  }

  fn cleanup(method : @ssa.Method) {
    method.body.stmts.each(
      fn {
        stmt =>
          match stmt.stmt {
            Definition(Some(def), _) => {
              if stmt.has_side_effects() {
                return
              }
              if def.is_global {
                let defs = def_globals[def.id].or(1)
                let uses = use_globals[def.id].or(0)
                let defs_from = def_globals_from[def.id].or(@hashset.new())
                let uses_from = use_globals_from[def.id].or(@hashset.new())
                if defs == 1 && uses == 0 {
                  stmt.update(Nop)
                  removed.insert(def.id)
                } else if defs_from.size() == 1 &&
                  uses_from.size() <= 1 &&
                  not(def.is_const()) {
                  let def_from = defs_from.iter().to_array()[0]
                  let use_from = uses_from.iter().to_array().get(0).or(def_from)
                  if def_from == use_from {
                    // Prune def from global
                    def.is_global = false
                    let idx = world.global
                      .search_by(fn { g => g.id == def.id })
                      .or(-1)
                    if idx != -1 {
                      let _ = world.global.remove(idx)
                      ()
                    }
                    method.local_vars.push(def)
                  }
                }
              }
            }
            _ => ()
          }
      },
    )
  }

  // 1. Collect global vars def / use
  collect(world.main_method)
  world.methods.values().each(fn { method => collect(method) })

  // 2. Cleanup
  cleanup(world.main_method)
  world.methods.values().each(fn { method => cleanup(method) })

  // 3. Remove global def
  let global = world.global.filter(
    fn { var => if removed.contains(var.id) { false } else { true } },
  )
  world.global.clear()
  world.global.push_iter(global.iter())
}

pub fn remove_ssa_method_dead_code(method : @ssa.Method) -> Unit {
  // 1. remove unit
  remove_unit_variables(method)

  // 2. DCE
  remove_dead_variables(method)
}

fn remove_dead_variables(method : @ssa.Method) -> Unit {
  while true {
    let mut removed = false
    let used : @hashset.T[Int] = @hashset.new()
    method.body.stmts.each(
      fn {
        stmt =>
          stmt.uses.each(
            fn {
              v => if not(v.is_const() || v.is_global) { used.insert(v.id) }
            },
          )
      },
    )
    method.body.stmts.each(
      fn {
        stmt => {
          if stmt.has_side_effects() {
            return
          }
          match stmt.def {
            Some(v) =>
              if not(v.is_const() || v.is_global) && not(used.contains(v.id)) {
                removed = true
                stmt.update(Nop)
              }
            None => ()
          }
        }
      },
    )
    if not(removed) {
      break
    }
  }

  // Clear local vars
  let used : @hashset.T[Int] = @hashset.new()
  method.body.stmts.each(
    fn {
      stmt => {
        match stmt.def {
          Some(v) => used.insert(v.id)
          None => ()
        }
        stmt.uses.each(
          fn { v => if not(v.is_const() || v.is_global) { used.insert(v.id) } },
        )
      }
    },
  )
  let local_vars = method.local_vars.filter(
    fn {
      v => {
        if v.is_const() || v.is_mut || v.is_param || v.is_this {
          return true
        }
        used.contains(v.id)
      }
    },
  )
  if method.local_vars.length() != local_vars.length() {
    method.local_vars.clear()
    method.local_vars.push_iter(local_vars.iter())
  }
}

fn remove_unit_variables(method : @ssa.Method) -> Unit {
  method.body.stmts.each(
    fn {
      stmt =>
        match stmt.stmt {
          Definition(Some(def), _) =>
            if not(stmt.has_side_effects()) && def.ty == Unit {
              stmt.update(Definition(Some(def), Unit))
            }
          _ => ()
        }
    },
  )
}
