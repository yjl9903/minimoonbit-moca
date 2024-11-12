pub fn transform_copy_propagation(method : @riscv.MachineMethod) -> Unit {
  @shared.debug("Copy propagation on machine ir: \{method.name}")

  // 1. Collect concerned stmts
  let all_copies = Map::new()
  let all_copies_id = Map::new()
  let def_ids = Map::new()
  let kill_ids = Map::new()
  method.body.stmts.each(
    fn {
      stmt =>
        match stmt.stmt {
          Definition(Some(lhs), Var(rhs, width)) => {
            let key = "\{lhs.memory_id()}=\{rhs.memory_id()}"
            let id = match all_copies.get(key) {
              Some((id, _, _, _)) => id
              None => {
                let id = all_copies.size()
                all_copies.set(key, (id, lhs, rhs, width))
                all_copies_id.set(id, (lhs, rhs, width))
                id
              }
            }
            def_ids.set(stmt.slot, id)
          }
          _ => ()
        }
    },
  )
  method.body.stmts.each(
    fn {
      stmt => {
        let killed = @hashset.new()
        match stmt.def {
          Some(def) =>
            all_copies
            .values()
            .each(
              fn {
                (id, lhs, rhs, _) =>
                  if def.memory_id() == lhs.memory_id() ||
                    def.memory_id() == rhs.memory_id() {
                    killed.insert(id)
                  }
              },
            )
          None => ()
        }
        kill_ids.set(stmt.slot, killed)
      }
    },
  )
  if all_copies.size() == 0 {
    return
  }

  // 2. Analysis
  let graph = method.body.build_stmts_graph()
  graph.add_edge(-1, 0) // -1 = start node
  let work_list = @queue.new()
  method.body.stmts.each(
    fn {
      stmt =>
        if graph.get_preds(stmt.slot).count() > 0 {
          work_list.push(stmt.slot)
        }
    },
  )
  let start_out = @hashset.new()
  let union = {
    let set = @hashset.new()
    all_copies.each(fn { _, v => set.insert(v.0) })
    set
  }
  let available_out = method.body.stmts.map(
    fn {
      _ => {
        let set = @hashset.new()
        all_copies.each(fn { _, v => set.insert(v.0) })
        set
      }
    },
  )
  fn merge(lhs : @hashset.T[Int], rhs : @hashset.T[Int]) -> @hashset.T[Int] {
    let set = @hashset.new()
    if lhs.size() <= rhs.size() {
      lhs.each(fn { id => if rhs.contains(id) { set.insert(id) } })
    } else {
      rhs.each(fn { id => if lhs.contains(id) { set.insert(id) } })
    }
    set
  }

  fn get_avaiable_in(slot : Int) -> @hashset.T[Int] {
    graph
    .get_preds(slot)
    .fold(
      fn {
        acc, pred =>
          merge(
            acc,
            if pred == -1 {
              start_out
            } else {
              available_out.get(pred).unwrap()
            },
          )
      },
      init=union,
    )
  }

  while not(work_list.is_empty()) {
    let slot = work_list.pop().unwrap()
    let available_in = get_avaiable_in(slot)
    let killed = kill_ids.get(slot).or(@hashset.new())
    killed.each(fn { k => available_in.remove(k) })
    match def_ids.get(slot) {
      Some(expr_id) => available_in.insert(expr_id)
      None => ()
    }
    let mut changed = false
    all_copies
    .values()
    .each(
      fn {
        (id, _, _, _) => {
          let old = available_out[slot].contains(id)
          let new = available_in.contains(id)
          if old && not(new) {
            changed = true
            available_out[slot].remove(id)
          } else if not(old) && new {
            changed = true
            available_out[slot].insert(id)
          }
        }
      },
    )
    if changed {
      graph.get_succs(slot).each(fn { v => work_list.push(v) })
    }
  }

  // 3. Replace
  let available_in = method.body.stmts.map(
    fn {
      stmt =>
        get_avaiable_in(stmt.slot)
        .iter()
        .map(fn { id => all_copies_id.get(id).unwrap() })
        .collect()
    },
  )
  // available_in.eachi(fn { i, av => println("\{i}: \{av}") })
  fn find_replace(slot : Int, var : @riscv.MachineVar) -> @riscv.MachineVar? {
    let available_in = available_in[slot].filter(
      fn {
        (lhs, _, _) =>
          if lhs.memory_id() == var.memory_id() {
            true
          } else {
            false
          }
      },
    )
    match available_in {
      [(_, rhs, _)] => {
        @shared.debug("L\{slot} \{var} -> \{rhs}")
        Some(rhs)
      }
      _ => None
    }
  }

  method.body.stmts.each(
    fn {
      stmt =>
        match stmt.stmt {
          Definition(_, Int(_)) => ()
          Definition(def, Neg(var, width)) => {
            let new_var = find_replace(stmt.slot, var).or(var)
            if new_var.memory_id() != var.memory_id() {
              let _ = stmt.update(Definition(def, Neg(new_var, width)))
              ()
            }
          }
          Definition(def, Prim(lhs, rhs, op, width)) => {
            let new_lhs = find_replace(stmt.slot, lhs).or(lhs)
            let new_rhs = find_replace(stmt.slot, rhs).or(rhs)
            if new_lhs.memory_id() != lhs.memory_id() &&
              new_rhs.memory_id() != rhs.memory_id() {
              let _ = stmt.update(Definition(def, Prim(lhs, rhs, op, width)))
              ()
            }
          }
          Definition(def, IntOfFloat(var)) => {
            let new_var = find_replace(stmt.slot, var).or(var)
            if new_var.memory_id() != var.memory_id() {
              let _ = stmt.update(Definition(def, IntOfFloat(new_var)))
              ()
            }
          }
          Definition(def, FloatOfInt(var)) => {
            let new_var = find_replace(stmt.slot, var).or(var)
            if new_var.memory_id() != var.memory_id() {
              let _ = stmt.update(Definition(def, FloatOfInt(new_var)))
              ()
            }
          }
          Definition(def, Var(var, width)) => {
            let new_var = find_replace(stmt.slot, var).or(var)
            if new_var.memory_id() != var.memory_id() {
              let _ = stmt.update(Definition(def, Var(new_var, width)))
              ()
            }
          }
          Definition(def, Load((recv, offset), width, code)) => {
            let new_recv = find_replace(stmt.slot, recv).or(recv)
            if new_recv.memory_id() != recv.memory_id() {
              let _ = stmt.update(
                Definition(def, Load((recv, offset), width, code)),
              )
              ()
            }
          }
          Definition(def, InvokeClosure(callee, args, width)) => {
            let new_callee = find_replace(stmt.slot, callee).or(callee)
            let (args, changed) = {
              let mut changed = false
              let args = args.map(
                fn {
                  arg => {
                    let new_arg = find_replace(stmt.slot, arg).or(arg)
                    if new_arg.memory_id() != arg.memory_id() {
                      changed = true
                    }
                    new_arg
                  }
                },
              )
              (args, changed)
            }
            if new_callee.memory_id() != callee.memory_id() || changed {
              let _ = stmt.update(
                Definition(def, InvokeClosure(new_callee, args, width)),
              )
              ()
            }
          }
          Definition(def, InvokeDirect(label, args, width)) => {
            let (args, changed) = {
              let mut changed = false
              let args = args.map(
                fn {
                  arg => {
                    let new_arg = find_replace(stmt.slot, arg).or(arg)
                    if new_arg.memory_id() != arg.memory_id() {
                      changed = true
                    }
                    new_arg
                  }
                },
              )
              (args, changed)
            }
            if changed {
              let _ = stmt.update(
                Definition(def, InvokeDirect(label, args, width)),
              )
              ()
            }
          }
          Definition(_, LoadLabel(_)) => ()
          Definition(_, Malloc(_)) => ()
          Definition(_, Phi(_)) => ()
          Store((recv, offset), expr, width, code) => {
            let new_recv = find_replace(stmt.slot, recv).or(recv)
            let new_expr = find_replace(stmt.slot, expr).or(expr)
            if new_recv.memory_id() != recv.memory_id() ||
              new_expr.memory_id() != expr.memory_id() {
              let _ = stmt.update(
                Store((new_recv, offset), new_expr, width, code),
              )
              ()
            }
          }
          IfGoto(cond, true_target, false_target) =>
            match cond {
              Eq(lhs, rhs, width) => {
                let new_lhs = find_replace(stmt.slot, lhs).or(lhs)
                let new_rhs = find_replace(stmt.slot, rhs).or(rhs)
                if new_lhs.memory_id() != lhs.memory_id() &&
                  new_rhs.memory_id() != rhs.memory_id() {
                  let _ = stmt.update(
                    IfGoto(
                      Eq(new_lhs, new_rhs, width),
                      true_target,
                      false_target,
                    ),
                  )
                  ()
                }
              }
              Ne(lhs, rhs, width) => {
                let new_lhs = find_replace(stmt.slot, lhs).or(lhs)
                let new_rhs = find_replace(stmt.slot, rhs).or(rhs)
                if new_lhs.memory_id() != lhs.memory_id() &&
                  new_rhs.memory_id() != rhs.memory_id() {
                  let _ = stmt.update(
                    IfGoto(
                      Ne(new_lhs, new_rhs, width),
                      true_target,
                      false_target,
                    ),
                  )
                  ()
                }
              }
              Lt(lhs, rhs, width) => {
                let new_lhs = find_replace(stmt.slot, lhs).or(lhs)
                let new_rhs = find_replace(stmt.slot, rhs).or(rhs)
                if new_lhs.memory_id() != lhs.memory_id() &&
                  new_rhs.memory_id() != rhs.memory_id() {
                  let _ = stmt.update(
                    IfGoto(
                      Lt(new_lhs, new_rhs, width),
                      true_target,
                      false_target,
                    ),
                  )
                  ()
                }
              }
              Le(lhs, rhs, width) => {
                let new_lhs = find_replace(stmt.slot, lhs).or(lhs)
                let new_rhs = find_replace(stmt.slot, rhs).or(rhs)
                if new_lhs.memory_id() != lhs.memory_id() &&
                  new_rhs.memory_id() != rhs.memory_id() {
                  let _ = stmt.update(
                    IfGoto(
                      Le(new_lhs, new_rhs, width),
                      true_target,
                      false_target,
                    ),
                  )
                  ()
                }
              }
              Gt(lhs, rhs, width) => {
                let new_lhs = find_replace(stmt.slot, lhs).or(lhs)
                let new_rhs = find_replace(stmt.slot, rhs).or(rhs)
                if new_lhs.memory_id() != lhs.memory_id() &&
                  new_rhs.memory_id() != rhs.memory_id() {
                  let _ = stmt.update(
                    IfGoto(
                      Gt(new_lhs, new_rhs, width),
                      true_target,
                      false_target,
                    ),
                  )
                  ()
                }
              }
              Ge(lhs, rhs, width) => {
                let new_lhs = find_replace(stmt.slot, lhs).or(lhs)
                let new_rhs = find_replace(stmt.slot, rhs).or(rhs)
                if new_lhs.memory_id() != lhs.memory_id() &&
                  new_rhs.memory_id() != rhs.memory_id() {
                  let _ = stmt.update(
                    IfGoto(
                      Ge(new_lhs, new_rhs, width),
                      true_target,
                      false_target,
                    ),
                  )
                  ()
                }
              }
            }
          Sanitizer(var, code) => {
            let new_var = find_replace(stmt.slot, var).or(var)
            if new_var.memory_id() != var.memory_id() {
              let _ = stmt.update(Sanitizer(new_var, code))
              ()
            }
          }
          Return(Some(var)) => {
            let new_var = find_replace(stmt.slot, var).or(var)
            if new_var.memory_id() != var.memory_id() {
              let _ = stmt.update(Return(Some(new_var)))
              ()
            }
          }
          Nop | Comment(_) | Goto(_) | Return(None) => ()
        }
    },
  )
}
