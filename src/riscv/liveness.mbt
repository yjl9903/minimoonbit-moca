struct LivenessState {
  live_in : Array[@hashset.T[Int]]
  live_out : Array[@hashset.T[Int]]
}

fn LivenessState::analyze(method : MachineMethod) -> LivenessState {
  // @shared.debug("liveness \{method.name}")
  let stmts = method.body.stmts
  let rev_stmts = stmts.iter2().to_array().rev()
  let liveness = {
    live_in: stmts.map(fn { _ => @hashset.new() }),
    live_out: stmts.map(fn { _ => @hashset.new() }),
  }
  let mut first_iter = true
  while true {
    let mut changed = false
    for stmt in rev_stmts {
      let (i, stmt) = stmt
      let live_out = liveness.live_out[i]
      let new_live_out = @hashset.new()
      let nexts = method.body.get_next_stmts(i)
      // OUT[i] = U_succ IN[succ]
      for next_id in nexts {
        let next_live_in = liveness.live_in[next_id]
        next_live_in.each(
          fn {
            v =>
              if not(live_out.contains(v)) {
                changed = true
                live_out.insert(v)
                new_live_out.insert(v)
              }
          },
        )
      }
      let live_in = liveness.live_in[i]
      let def_id = match stmt.def {
        Some(def) => def.memory_id()
        None => -1
      }
      // IN[i] = use(i) U (OUT[i] - def(i))
      for v in new_live_out {
        if v != def_id && not(live_in.contains(v)) {
          changed = true
          live_in.insert(v)
        }
      }
      if first_iter {
        for v in stmt.uses {
          if not(live_in.contains(v.memory_id())) {
            changed = true
            live_in.insert(v.memory_id())
          }
        }
      }
    }
    if not(changed) {
      break
    }
    first_iter = false
  }
  // for i = 0; i < stmts.length(); i = i + 1 {
  //   @shared.debug("  - out \{i} : \{liveness.live_out[i]}")
  // }
  liveness
}

fn LivenessState::is_live_before(
  self : LivenessState,
  i : Int,
  vid : Int
) -> Bool {
  self.live_in[i].contains(vid)
}

fn LivenessState::is_live_after(
  self : LivenessState,
  i : Int,
  vid : Int
) -> Bool {
  self.live_out[i].contains(vid)
}
