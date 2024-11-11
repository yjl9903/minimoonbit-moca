pub fn transform_global_common_sub_expr(method : @riscv.MachineMethod) -> Unit {
  @shared.debug("Global common sub expr: \{method.name}")

  // 1. Collect concerned stmts
  let all_stmts = Map::new()
  let def_ids = Map::new()
  let kill_ids = Map::new()
  method.body.stmts.each(
    fn {
      stmt =>
        match get_stmt_key(stmt) {
          Some((key, def, value)) => {
            let id = match all_stmts.get(key) {
              Some((_, id)) => id
              None => {
                let id = all_stmts.size()
                all_stmts.set(key, (value, id))
                id
              }
            }
            def_ids.set(stmt.slot, (def, id))
          }
          _ => ()
        }
    },
  )
  method.body.stmts.each(
    fn {
      stmt => {
        let killed = @hashset.new()
        match stmt.stmt {
          Definition(def, _) =>
            match def {
              Some(def) =>
                all_stmts
                .values()
                .each(
                  fn {
                    (rvalue, id) =>
                      if is_def_kill_stmt(def, rvalue) {
                        killed.insert(id)
                      }
                  },
                )
              None => ()
            }
          // match rvalue {
          //   // Closure can not be modified
          //   InvokeDirect(_, args, _) | InvokeClosure(_, args, _) =>
          //     args.each(
          //       fn {
          //         arg =>
          //           if @closure.is_ptr_like(arg.ty) {
          //             all_stmts
          //             .values()
          //             .each(
          //               fn {
          //                 (rvalue, id) =>
          //                   if is_def_kill_stmt(arg, rvalue) {
          //                     killed.insert(id)
          //                   }
          //               },
          //             )
          //           }
          //       },
          //     )
          //   _ => ()
          // }
          // Store((recv, offset), _, _, _) => @util.die("todo")
          _ => ()
        }
        kill_ids.set(stmt.slot, killed)
      }
    },
  )

  // 2. Analysis
  let graph = method.body.build_stmts_graph()
  graph.add_edge(-1, 0) // -1 = start node
  let start_out = {
    let set = @hashmap.new()
    all_stmts.each(fn { _, v => set.set(v.1, CommonExp::NAC) })
    set
  }
  let available_out = method.body.stmts.map(
    fn {
      _ => {
        let set = @hashmap.new()
        all_stmts.each(fn { _, v => set.set(v.1, CommonExp::Undef) })
        set
      }
    },
  )
  fn merge(
    lhs : @hashmap.T[Int, CommonExp],
    rhs : @hashmap.T[Int, CommonExp]
  ) -> @hashmap.T[Int, CommonExp] {
    if lhs.is_empty() {
      @hashmap.from_iter(rhs.iter())
    } else {
      let set = @hashmap.new()
      all_stmts
      .values()
      .each(
        fn {
          v => {
            let lhs = lhs.get(v.1).unwrap()
            let rhs = rhs.get(v.1).unwrap()
            set.set(
              v.1,
              match (lhs, rhs) {
                (NAC, _) | (_, NAC) => NAC
                (Undef, a) | (a, Undef) => a
                (Def(a), Def(_)) => Def(a)
              },
            )
          }
        },
      )
      set
    }
  }

  let work_list = @queue.new()
  method.body.stmts.each(
    fn {
      stmt =>
        if graph.get_preds(stmt.slot).count() > 0 {
          work_list.push(stmt.slot)
        }
    },
  )
  while not(work_list.is_empty()) {
    let slot = work_list.pop().unwrap()
    let available_in = graph
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
        init=@hashmap.new(),
      )
    let killed = kill_ids.get(slot).or(@hashset.new())
    killed.each(fn { k => available_in.set(k, NAC) })
    match def_ids.get(slot) {
      Some((def, expr_id)) => available_in.set(expr_id, Def(def))
      None => ()
    }
    let mut changed = false
    all_stmts
    .values()
    .each(
      fn {
        (_, id) => {
          let old = available_out[slot].get(id).unwrap()
          let new = available_in.get(id).unwrap()
          if old != new {
            changed = true
            available_out[slot].set(id, new)
          }
        }
      },
    )
    if changed {
      graph.get_succs(slot).each(fn { v => work_list.push(v) })
    }
  }

  // 3. Replace common expr
  method.body.stmts.each(
    fn {
      stmt => {
        match def_ids.get(stmt.slot) {
          Some((def, id)) => {
            let available_in = graph
              .get_preds(stmt.slot)
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
                init=@hashmap.new(),
              )
            match available_in.get(id) {
              Some(Def(t)) => {
                @shared.debug("Optimize \{def} = \{t}, \{def.width}")
                let _ = stmt.update(
                  @riscv.StmtKind::Definition(Some(def), Var(t, def.width)),
                )
                ()
              }
              _ => ()
            }
          }
          None => ()
        }
        ()
      }
    },
  )
}

fn get_stmt_key(
  stmt : @riscv.Stmt
) -> (String, @riscv.MachineVar, @riscv.RValue)? {
  match stmt.stmt {
    Definition(Some(def), Neg(expr, width) as rvalue) =>
      Some(("N(\{get_var_key(expr)},\{width})", def, rvalue))
    Definition(Some(def), Prim(lhs, rhs, op, width) as rvalue) =>
      Some(
        ("P(\{get_var_key(lhs)}\{op}\{get_var_key(rhs)},\{width})", def, rvalue),
      )
    // Definition(Some(_), Load((recv, offset), width, _) as rvalue) =>
    //   Some(("L(\{recv.memory_id()},\{offset},\{width})", rvalue))
    _ => None
  }
}

fn get_var_key(var : @riscv.MachineVar) -> String {
  match var.const_value {
    Some(Int(x)) => "I_" + x.to_string()
    Some(Double(x)) => "D_" + x.to_string()
    _ => var.memory_id().to_string()
  }
}

fn is_def_kill_stmt(def : @riscv.MachineVar, rvalue : @riscv.RValue) -> Bool {
  match rvalue {
    Neg(expr, _) => def.memory_id() == expr.memory_id()
    Prim(lhs, rhs, _, _) =>
      def.memory_id() == lhs.memory_id() || def.memory_id() == rhs.memory_id()
    // Load((recv, offset), _, _) => def.memory_id() == recv.memory_id()
    _ => false
  }
}

enum CommonExp {
  Undef
  Def(@riscv.MachineVar)
  NAC
} derive(Show)

fn CommonExp::op_equal(self : CommonExp, other : CommonExp) -> Bool {
  match (self, other) {
    (Undef, Undef) => true
    (Def(v1), Def(v2)) => v1.memory_id() == v2.memory_id()
    (NAC, NAC) => true
    _ => false
  }
}
