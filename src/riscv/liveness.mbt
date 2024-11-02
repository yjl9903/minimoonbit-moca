struct LivenessState {
  live_in : Array[@hashset.T[Int]]
  live_out : Array[@hashset.T[Int]]
}

fn LivenessState::analyze(method : MachineMethod) -> LivenessState {
  let stmts = method.body.stmts
  let liveness = {
    live_in: stmts.map(fn { _ => @hashset.new() }),
    live_out: stmts.map(fn { _ => @hashset.new() }),
  }
  liveness
}
