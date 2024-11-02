struct LinearAllocator {
  liveness : LivenessState
  method : MachineMethod
}

fn LinearAllocator::new(method : MachineMethod) -> LinearAllocator {
  let liveness = LivenessState::analyze(method)
  { liveness, method }
}

fn LinearAllocator::allocate_registor(self : LinearAllocator) -> Unit {

}
