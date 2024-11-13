struct LinearAllocator {
  liveness : LivenessState
  method : MachineMethod
  results : Array[AllocationResult]
  allocated_reg : Map[Int, (MachineVar, Reg)] // var id -> reg
  allocated_freg : Map[Int, (MachineVar, FReg)] // var id -> freg
  spilled : @hashset.T[Int] // var id
}

struct AllocationResult {
  skip_store_vars : @hashset.T[Int]
  skip_load_vars : @hashset.T[Int]
  reg_map_before : Map[Int, Reg] // Before this inst, Var -> Reg
  freg_map_before : Map[Int, FReg] // Before this inst, Var -> FReg
  reg_map_after : Map[Int, Reg] // After this inst, Var -> Reg
  freg_map_after : Map[Int, FReg] // After this inst, Var -> FReg
}

fn LinearAllocator::new(
  method : MachineMethod,
  liveness : LivenessState
) -> LinearAllocator {
  {
    liveness,
    method,
    results: [],
    spilled: @hashset.new(),
    allocated_freg: Map::new(),
    allocated_reg: Map::new(),
  }
}

fn AllocationResult::new() -> AllocationResult {
  {
    skip_store_vars: @hashset.new(),
    skip_load_vars: @hashset.new(),
    reg_map_before: Map::new(),
    freg_map_before: Map::new(),
    reg_map_after: Map::new(),
    freg_map_after: Map::new(),
  }
}

// fn AllocationResult::fork(self : AllocationResult) -> AllocationResult {
//   {
//     store_regs_before: [],
//     store_fregs_before: [],
//     load_regs: [],
//     load_fregs: [],
//     reg_map: Map::from_iter(self.reg_map.iter()),
//     freg_map: Map::from_iter(self.freg_map.iter()),
//   }
// }

fn LinearAllocator::allocate_registor(
  self : LinearAllocator,
  ~callee_first : Bool = false
) -> Unit {
  let body = self.method.body
  let lifes_map = self.get_life_cycles()
  let lifes = lifes_map.values().to_array()
  lifes.sort_by(
    fn {
      lhs, rhs =>
        if lhs.from != rhs.from {
          lhs.from - rhs.from
        } else {
          lhs.to - rhs.to
        }
    },
  )
  // Sort is wrong
  lifes.sort_by(
    fn {
      lhs, rhs =>
        if lhs.from != rhs.from {
          lhs.from - rhs.from
        } else {
          rhs.to - rhs.from - (lhs.to - lhs.from)
        }
    },
  )
  // for i = 1; i < lifes.length(); i = i + 1 {
  //   if lifes[i - 1].from > lifes[i].from {
  //     @util.die("????")
  //   }
  // }
  // @shared.debug("Allocate \{self.method.name}:")
  // for life in lifes {
  //   @shared.debug("Life \{life.var.memory_id()}: [\{life.from}, \{life.to}]")
  // }
  let mut p = 0
  let (active_reg, active_freg) = self.allocate_initial_state(
    lifes_map,
    ~callee_first,
  )
  // Allocate params
  while p < lifes.length() && -1 == lifes[p].from {
    let var = lifes[p].var
    match var.param_offset {
      Some(Reg(_)) => ()
      Some(FReg(_)) => ()
      // params > 8, spill it
      _ => self.spilled.insert(var.memory_id())
    }
    p = p + 1
  }

  // Allocate body
  for i = 0; i < body.stmts.length(); i = i + 1 {
    // 1. Set allocation info before stmt
    let allocation = AllocationResult::new()
    for item in active_freg {
      let (freg, life) = item
      match life {
        Some(life) => allocation.freg_map_before.set(life.var.memory_id(), freg)
        None => ()
      }
    }
    for item in active_reg {
      let (reg, life) = item
      match life {
        Some(life) => allocation.reg_map_before.set(life.var.memory_id(), reg)
        None => ()
      }
    }
    self.results.push(allocation)

    // 2. Release outdated
    let uses = body.stmts[i].uses
    let released_reg = self
      .release_register(active_reg, i)
      .filter(
        fn {
          info => {
            let vid = info.1.var.memory_id()
            match uses.search_by(fn { use => use.memory_id() == vid }) {
              Some(_) => true
              None => false
            }
          }
        },
      )
    let released_freg = self
      .release_register(active_freg, i)
      .filter(
        fn {
          info => {
            let vid = info.1.var.memory_id()
            match uses.search_by(fn { use => use.memory_id() == vid }) {
              Some(_) => true
              None => false
            }
          }
        },
      )

    // 3. Allocate defined register
    while p < lifes.length() && i == lifes[p].from {
      let life = lifes[p]
      let var = lifes[p].var
      if var.width.is_float() {
        let idx = allocate_registor_or_spill(
          self, active_freg, life, released_freg,
        )
        // @shared.debug("allocate \{var.memory_id()} to \{active_freg[idx].0}")
        self.allocated_freg[var.memory_id()] = (var, active_freg[idx].0)
      } else {
        let idx = allocate_registor_or_spill(
          self, active_reg, life, released_reg,
        )
        // @shared.debug("allocate \{var.memory_id()} to \{active_reg[idx].0}")
        self.allocated_reg[var.memory_id()] = (var, active_reg[idx].0)
      }
      p = p + 1
    }

    // 4. Set allocation info after stmt
    for item in active_freg {
      let (freg, life) = item
      match life {
        Some(life) => allocation.freg_map_after.set(life.var.memory_id(), freg)
        None => ()
      }
    }
    for item in active_reg {
      let (reg, life) = item
      match life {
        Some(life) => allocation.reg_map_after.set(life.var.memory_id(), reg)
        None => ()
      }
    }
  }

  // Remove spilled var from result
  for i = 0; i < body.stmts.length(); i = i + 1 {
    let result = self.results[i]
    let removed = @hashset.new()
    result.reg_map_before.each(
      fn { vid, _ => if self.is_spilled_by_id(vid) { removed.insert(vid) } },
    )
    removed.each(fn { vid => result.reg_map_before.remove(vid) })
    let removed = @hashset.new()
    result.reg_map_after.each(
      fn { vid, _ => if self.is_spilled_by_id(vid) { removed.insert(vid) } },
    )
    removed.each(fn { vid => result.reg_map_after.remove(vid) })
  }
}

fn LinearAllocator::release_register[TReg](
  _self : LinearAllocator,
  active : Array[(TReg, LifeCycle?)],
  current : Int
) -> Array[(TReg, LifeCycle)] {
  let removed = []
  for idx, item in active {
    let (_, life) = item
    match life {
      Some(life) => if life.to <= current { removed.push(idx) }
      None => ()
    }
  }
  removed.map(
    fn {
      idx => {
        let origin = active[idx]
        active[idx] = (active[idx].0, None)
        (origin.0, origin.1.unwrap())
      }
    },
  )
}

fn LinearAllocator::allocate_registor_or_spill[TReg : Eq](
  self : LinearAllocator,
  active : Array[(TReg, LifeCycle?)],
  life : LifeCycle,
  released : Array[(TReg, LifeCycle)]
) -> Int {
  let mut found = None
  // 1. try released register
  for _, item in released {
    let (reg, _) = item
    let idx = active.search_by(
      fn { info => info.0 == reg && info.1.is_empty() },
    )
    match idx {
      Some(idx) => {
        found = Some(idx)
        break
      }
      None => ()
    }
  }
  // 2. try other register from left to right
  if found.is_empty() {
    for idx, item in active {
      let (_, v) = item
      match v {
        Some(_) => ()
        None => {
          found = Some(idx)
          break
        }
      }
    }
  }
  // 3. Found reg or spill
  match found {
    Some(idx) => {
      active[idx] = (active[idx].0, Some(life))
      idx
    }
    None => {
      // spill
      let mut spilled_idx = None
      let mut min_from = self.method.body.stmts.length() + 1
      active.eachi(
        fn {
          idx, (_, v) =>
            match v {
              Some(life) =>
                if life.from < min_from {
                  min_from = life.from
                  spilled_idx = Some(idx)
                }
              None => ()
            }
        },
      )
      match spilled_idx {
        Some(idx) => {
          let spilled = active[idx]
          let var = spilled.1.unwrap().var
          self.spilled.insert(var.memory_id())
          active[idx] = (active[idx].0, Some(life))
          idx
        }
        None => @util.die("unreachable")
      }
    }
  }
}

fn LinearAllocator::allocate_initial_state(
  self : LinearAllocator,
  lifes : Map[Int, LifeCycle],
  ~callee_first : Bool
) -> (Array[(Reg, LifeCycle?)], Array[(FReg, LifeCycle?)]) {
  let active_reg : Array[(Reg, LifeCycle?)] = {
    let reg_list = if callee_first {
      [..reg_callee_saved_list, ..reg_caller_saved_list]
    } else {
      [..reg_caller_saved_list, ..reg_callee_saved_list]
    }
    let mp = []
    for r in reg_list {
      if r == T0 || r == T1 {
        continue
      }
      mp.push((r, None))
    }
    mp
  }
  let active_freg : Array[(FReg, LifeCycle?)] = {
    let freg_list = if callee_first {
      [..freg_callee_saved_list, ..freg_caller_saved_list]
    } else {
      [..freg_caller_saved_list, ..freg_callee_saved_list]
    }
    let mp = []
    for r in freg_list {
      if r == Ft0 || r == Ft1 {
        continue
      }
      mp.push((r, None))
    }
    mp
  }

  // 1. Generate reg allocate
  let mut fp = 0
  let mut gp = 0
  for var in self.method.params {
    if var.is_this {
      continue
    }
    if var.width.is_float() {
      if fp < freg_arg_list.length() {
        var.param_offset = Some(FReg(freg_arg_list[fp]))
        fp += 1
      }
      ()
    } else {
      if gp < reg_arg_list.length() {
        var.param_offset = Some(Reg(reg_arg_list[gp]))
        gp += 1
      }
      ()
    }
  }
  // 2. %this param in reg
  match self.method.this {
    Some(var) =>
      if gp < reg_arg_list.length() {
        var.param_offset = Some(Reg(reg_arg_list[gp]))
        gp += 1
      }
    None => ()
  }
  // 3. init reg allocate
  self.method.params.each(
    fn {
      p =>
        match p.param_offset {
          Some(Reg(reg)) =>
            match lifes.get(p.memory_id()) {
              Some(life) => {
                let idx = active_reg.search_by(fn { a => a.0 == reg }).unwrap()
                active_reg[idx] = (reg, Some(life))
                self.allocated_reg[p.memory_id()] = (p, active_reg[idx].0)
              }
              None => ()
            }
          Some(FReg(freg)) =>
            match lifes.get(p.memory_id()) {
              Some(life) => {
                let idx = active_freg
                  .search_by(fn { a => a.0 == freg })
                  .unwrap()
                active_freg[idx] = (freg, Some(life))
                self.allocated_freg[p.memory_id()] = (p, active_freg[idx].0)
              }
              None => ()
            }
          _ => ()
        }
    },
  )
  (active_reg, active_freg)
}

struct LifeCycle {
  var : MachineVar
  from : Int
  to : Int
}

fn LifeCycle::new(var : MachineVar, from : Int, to : Int) -> LifeCycle {
  { var, from, to }
}

fn LinearAllocator::get_life_cycles(
  self : LinearAllocator
) -> Map[Int, LifeCycle] {
  let map = Map::new()
  let active = Map::new()
  let body = self.method.body
  for i = 0; i < self.method.params.length(); i = i + 1 {
    let param = self.method.params[i]
    active.set(param.memory_id(), (-1, param))
  }
  for i = 0; i < body.stmts.length(); i = i + 1 {
    match body.stmts[i].def {
      Some(def) =>
        if not(active.contains(def.memory_id())) {
          active.set(def.memory_id(), (i, def))
        }
      None => ()
    }
  }
  for i = body.stmts.length() - 1; i >= 0; i = i - 1 {
    let lived = []
    active.each(
      fn {
        vid, info =>
          if self.liveness.is_live_before(i, vid) {
            lived.push((vid, info))
          }
      },
    )
    for item in lived {
      let (vid, (from, var)) = item
      // Get lifecycle
      active.remove(vid)
      let life = LifeCycle::new(var, from, i)
      map.set(vid, life)
    }
  }
  map
}

fn LinearAllocator::allocate_stack_vars(self : LinearAllocator) -> Unit {
  let vars_map = Map::new()
  for var in self.method.local_vars {
    var.is_stack = false
    vars_map.set(var.id, var)
  }
  // Spilled var should have stack slot
  for vid in self.spilled {
    match vars_map.get(vid) {
      Some(var) => var.is_stack = true
      None => ()
    }
  }
  // Saved invoke var should have stack slot
  for i = 0; i < self.method.body.stmts.length(); i = i + 1 {
    let stmt = self.method.body.stmts[i]
    match stmt.stmt {
      Definition(def, InvokeClosure(_) | InvokeDirect(_) | Malloc(_) as rvalue) => {
        let def_id = def.map(fn { d => d.memory_id() }).or(-1)
        let result = self.results[i]
        for vid, reg in result.reg_map_after {
          if def_id != vid &&
            not(self.is_spilled_by_id(vid)) &&
            (
              not(result.skip_store_vars.contains(vid)) ||
              not(result.skip_load_vars.contains(vid))
            ) &&
            reg_caller_saved_list.contains(reg) {
            let var = self.get_global_allocated_int_var(vid)
            if var.const_value.is_empty() {
              match var.outcoming_var {
                Some(outcoming_var) => outcoming_var.is_stack = true
                None => var.is_stack = true
              }
            }
          }
        }
        for vid, freg in result.freg_map_after {
          if def_id != vid &&
            not(self.is_spilled_by_id(vid)) &&
            (
              not(result.skip_store_vars.contains(vid)) ||
              not(result.skip_load_vars.contains(vid))
            ) &&
            freg_caller_saved_list.contains(freg) {
            let var = self.get_global_allocated_float_var(vid)
            if var.const_value.is_empty() {
              match var.outcoming_var {
                Some(outcoming_var) => outcoming_var.is_stack = true
                None => var.is_stack = true
              }
            }
          }
        }
      }
      _ => ()
    }
  }
}

// --- Query ---

fn LinearAllocator::collect_saved_reg(
  self : LinearAllocator
) -> (Array[Reg], Array[FReg]) {
  let regs = @hashset.from_iter(
    self.allocated_reg
    .values()
    .map(fn { v => v.1 })
    .filter(fn { v => reg_callee_saved_list.contains(v) }),
  )
  let fregs = @hashset.from_iter(
    self.allocated_freg
    .values()
    .map(fn { v => v.1 })
    .filter(fn { v => freg_callee_saved_list.contains(v) }),
  )
  (regs.iter().to_array(), fregs.iter().to_array())
}

fn LinearAllocator::collect_used_reg(
  self : LinearAllocator
) -> (Array[Reg], Array[FReg])? {
  let regs = @hashset.from_iter(
    self.allocated_reg
    .values()
    .map(fn { v => v.1 })
    .filter(fn { v => reg_caller_saved_list.contains(v) }),
  )
  let fregs = @hashset.from_iter(
    self.allocated_freg
    .values()
    .map(fn { v => v.1 })
    .filter(fn { v => freg_caller_saved_list.contains(v) }),
  )
  Some((regs.iter().to_array(), fregs.iter().to_array()))
}

fn LinearAllocator::get_global_allocated_int_var(
  self : LinearAllocator,
  var : Int
) -> MachineVar {
  match self.allocated_reg.get(var) {
    Some(r) => r.0
    None => @util.die("shoulde allocate reg")
  }
}

fn LinearAllocator::get_global_allocated_float_var(
  self : LinearAllocator,
  var : Int
) -> MachineVar {
  match self.allocated_freg.get(var) {
    Some(r) => r.0
    None => @util.die("shoulde allocate reg")
  }
}

fn LinearAllocator::get_global_allocated_reg(
  self : LinearAllocator,
  var : MachineVar,
  ~loc : SourceLoc = _
) -> Reg {
  if var.width.is_float() {
    @util.die("shoulde not be Double")
  }
  if self.is_spilled(var) {
    match var.width {
      Int => T0
      Double => @util.die("unreachable")
      Ptr => T0
    }
  } else {
    match self.allocated_reg.get(var.memory_id()) {
      Some(r) => r.1
      None => @util.die("shoulde allocate reg \{var.name} \{var.id}", ~loc)
    }
  }
}

fn LinearAllocator::get_global_allocated_freg(
  self : LinearAllocator,
  var : MachineVar
) -> FReg {
  if not(var.width.is_float()) {
    @util.die("shoulde be Double")
  }
  if self.is_spilled(var) {
    Ft0
  } else {
    match self.allocated_freg.get(var.memory_id()) {
      Some(r) => r.1
      None => @util.die("shoulde allocate reg")
    }
  }
}

fn LinearAllocator::is_spilled(
  self : LinearAllocator,
  var : MachineVar
) -> Bool {
  self.spilled.contains(var.memory_id())
}

fn LinearAllocator::is_spilled_by_id(self : LinearAllocator, vid : Int) -> Bool {
  self.spilled.contains(vid)
}
