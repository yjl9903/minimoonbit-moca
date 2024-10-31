enum ConstValue {
  Int(Int)
  Double(Double)
  NAC
} derive(Show, Eq, Hash)

pub fn mark_ssa_const_variable(method : @ssa.Method) -> Unit {
  @shared.debug("Const prop: \{method.name}")
  let consts = method.body.stmts.map(fn { _ => Map::new() })
  let return_consts = Map::new()
  fn get_consts(cur : (Int, Int)) {
    let stmt = method.body.blocks[cur.0].stmts[cur.1]
    consts[stmt.slot]
  }

  fn meet_const(prev : ConstValue?, next : ConstValue?) -> (Bool, ConstValue?) {
    match (prev, next) {
      (None, None) => (false, None)
      (None, _) => (true, next)
      (_, None) => (false, prev)
      (Some(Int(p)), Some(Int(n))) =>
        if p == n {
          (false, prev)
        } else {
          (true, Some(NAC))
        }
      (Some(Double(p)), Some(Double(n))) =>
        if p == n {
          (false, prev)
        } else {
          (true, Some(NAC))
        }
      (Some(NAC), _) => (false, Some(NAC))
      (_, _) => (true, Some(NAC))
    }
  }

  fn update_consts(
    consts : Map[Int, ConstValue],
    def : Int,
    const_value : ConstValue
  ) -> Bool {
    let prev = consts.get(def)
    let (ok, result) = meet_const(prev, Some(const_value))
    if ok {
      match result {
        Some(result) => {
          consts.set(def, result)
          true
        }
        None => false
      }
    } else {
      false
    }
  }

  fn eval_stmts(
    stmt : @ssa.Stmt,
    consts : Map[Int, ConstValue]
  ) -> (Int, ConstValue)? {
    fn get_int_const_value(var : @ssa.Var) -> Result[Int?, Unit] {
      if var.ty == Int {
        match var.const_value {
          Some(Int(x)) => Ok(Some(x)) // Int(x)
          Some(_) => Err(()) // NAC
          None =>
            match consts.get(var.id) {
              None => Ok(None) // UNDEF
              Some(Int(x)) => Ok(Some(x)) // Int(x)
              Some(Double(_)) => Err(()) // NAC
              Some(NAC) => Err(()) // NAC
            }
        }
      } else {
        Err(()) // NAC
      }
    }

    fn get_double_const_value(var : @ssa.Var) -> Result[Double?, Unit] {
      if var.ty == Double {
        match var.const_value {
          Some(Double(x)) => Ok(Some(x)) // Double(x)
          Some(_) => Err(()) // NAC
          None =>
            match consts.get(var.id) {
              None => Ok(None) // UNDEF
              Some(Double(x)) => Ok(Some(x)) // Double(x)
              Some(Int(_)) => Err(()) // NAC
              Some(NAC) => Err(()) // NAC
            }
        }
      } else {
        Err(()) // NAC
      }
    }

    match stmt.stmt {
      Definition(Some(def), rvalue) =>
        if def.ty == Int || def.ty == Double {
          match rvalue {
            Int(x) => Some((def.id, Int(x)))
            Double(x) => Some((def.id, Double(x)))
            Neg(var, Int) =>
              match get_int_const_value(var) {
                Ok(Some(x)) => Some((def.id, Int(-x)))
                Ok(None) => None
                Err(_) => Some((def.id, NAC))
              }
            Neg(var, Double) =>
              match get_double_const_value(var) {
                Ok(Some(x)) => Some((def.id, Double(-x)))
                Ok(None) => None
                Err(_) => Some((def.id, NAC))
              }
            Prim(lhs, rhs, op, Int) =>
              match get_int_const_value(lhs) {
                Ok(Some(lhs)) =>
                  match get_int_const_value(rhs) {
                    Ok(Some(rhs)) =>
                      eval_int_bin_op(lhs, rhs, op).map(
                        fn { cv => (def.id, Int(cv)) },
                      )
                    Ok(None) => None
                    Err(_) => Some((def.id, NAC))
                  }
                Ok(None) => None
                Err(_) => Some((def.id, NAC))
              }
            Prim(lhs, rhs, op, Double) =>
              match get_double_const_value(lhs) {
                Ok(Some(lhs)) =>
                  match get_double_const_value(rhs) {
                    Ok(Some(rhs)) =>
                      eval_double_bin_op(lhs, rhs, op).map(
                        fn { cv => (def.id, Double(cv)) },
                      )
                    Ok(None) => None
                    Err(_) => Some((def.id, NAC))
                  }
                Ok(None) => None
                Err(_) => Some((def.id, NAC))
              }
            Var(var) => consts.get(var.id).map(fn { cv => (def.id, cv) })
            Phi(vars) => {
              let mut val = None
              for i = 0; i < vars.length(); i = i + 1 {
                let (_, next) = meet_const(val, consts.get(vars[i].id))
                val = next
                if val == Some(NAC) {
                  break
                }
              }
              val.map(fn { val => (def.id, val) })
            }
            GetTuple(_) => Some((def.id, NAC))
            GetArray(_) => Some((def.id, NAC))
            GetClosure(_) => Some((def.id, NAC))
            InvokeClosure(_) => Some((def.id, NAC))
            InvokeDirect(_) => Some((def.id, NAC))
            _ => None
          }
        } else {
          None
        }
      _ => None
    }
  }

  // Initialize
  let work_list = @queue.new()
  method.body.blocks.each(
    fn { blk => blk.stmts.eachi(fn { i, _ => work_list.push((blk.label, i)) }) },
  )

  // Init params as NAC
  method.params.each(fn { var => consts[0].set(var.id, NAC) })

  // Work list solver
  while not(work_list.is_empty()) {
    let cur = work_list.pop().unwrap()
    let stmt = method.body.blocks[cur.0].stmts[cur.1]
    let cur_consts = consts[stmt.slot]
    // Eval stmts
    let result = eval_stmts(stmt, cur_consts)
    let may_def = result.map_or(-1, fn { d => d.0 })

    // Transform to next stmt
    let next_stmts = method.body.get_next_block_ids(cur.0, cur.1)
    if next_stmts.length() > 0 {
      next_stmts.each(
        fn {
          next => {
            let next_consts = get_consts(next)
            let mut changed = false
            for id, cv in cur_consts {
              if id != may_def && update_consts(next_consts, id, cv) {
                changed = true
              }
            }
            match result {
              Some(result) =>
                if update_consts(next_consts, result.0, result.1) {
                  changed = true
                }
              None => ()
            }
            if changed {
              work_list.push(next)
            }
          }
        },
      )
    } else {
      for id, cv in cur_consts {
        if id != may_def {
          let _ = update_consts(return_consts, id, cv)
          ()
        }
      }
      match result {
        Some(result) => {
          let _ = update_consts(return_consts, result.0, result.1)
          ()
        }
        None => ()
      }
      ()
    }
  }

  // Replace const def
  method.body.stmts.each(
    fn {
      stmt => {
        // invoke some function
        if stmt.has_side_effects() {
          return
        }
        match stmt.def {
          Some(def) => {
            // 1. should not optimize const var
            // 2. should be Int or Double
            // 3. should not be merged in phi
            if def.is_const() ||
              (def.ty != Int && def.ty != Double) ||
              not(def.outcoming.is_empty()) {
              return
            }
            let const_value = return_consts.get(def.id)
            match const_value {
              Some(Int(x)) => {
                @shared.debug("Optimize const value \{def} = (Int) \{x}")
                def.is_global = true
                def.const_value = Some(Int(x))
                @ssa.get_world().global.push(def)
                stmt.update(Definition(Some(def), Int(x)))
              }
              Some(Double(x)) => {
                @shared.debug("Optimize const value \{def} = (Double) \{x}")
                def.is_global = true
                def.const_value = Some(Double(x))
                @ssa.get_world().global.push(def)
                stmt.update(Definition(Some(def), Double(x)))
              }
              _ => ()
            }
          }
          None => ()
        }
      }
    },
  )
}

fn eval_int_bin_op(lhs : Int, rhs : Int, op : @ssa.PrimOp) -> Int? {
  match op {
    Add => Some(lhs + rhs)
    Sub => Some(lhs - rhs)
    Mul => Some(lhs * rhs)
    Div => if rhs != 0 { Some(lhs / rhs) } else { None }
  }
}

fn eval_double_bin_op(lhs : Double, rhs : Double, op : @ssa.PrimOp) -> Double? {
  match op {
    Add => Some(lhs + rhs)
    Sub => Some(lhs - rhs)
    Mul => Some(lhs * rhs)
    Div => if rhs != 0 { Some(lhs / rhs) } else { None }
  }
}
