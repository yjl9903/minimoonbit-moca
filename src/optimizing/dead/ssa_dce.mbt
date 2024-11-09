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
              }
            None => ()
          }
          stmt.uses.each(
            fn {
              use =>
                if use.is_global {
                  use_globals[use.id] = use_globals.get_or_default(use.id, 0) +
                    1
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
                if defs == 1 && uses == 0 {
                  stmt.update(Nop)
                  removed.insert(def.id)
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
