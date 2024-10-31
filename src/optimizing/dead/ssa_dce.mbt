pub fn remove_ssa_dead_code(method : @ssa.Method) -> Unit {
  // 1. remove unit
  remove_unit_variables(method)

  // 2. DCE
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
