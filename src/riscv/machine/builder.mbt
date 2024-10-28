pub fn build_machine_ir(world : @ssa.World) -> MachineWorld {
  let machine = { methods: [] }
  machine.methods.push(create_machine_method(world.main_method))
  world.methods
  .values()
  .each(fn { m => machine.methods.push(create_machine_method(m)) })
  machine
}

fn create_machine_method(method : @ssa.Method) -> MachineMethod {
  let machine = {
    id: method.slot,
    name: method.name,
    ty: method.ty,
    this: method.this.map(fn { v => MachineVar::from_ssa(v) }),
    params: method.params.map(fn { p => MachineVar::from_ssa(p) }),
    local_vars: method.local_vars.map(fn { p => MachineVar::from_ssa(p) }),
    body: { stmts: [], blocks: [] },
    is_closure: method.is_closure,
    free_vars: method.formal_free_vars,
  }
  let builder = Builder::new(machine)
  builder.build(method)
  machine
}

fn MachineVar::from_ssa(var : @ssa.Var) -> MachineVar {
  {
    id: var.id,
    name: var.name,
    ty: var.ty,
    size: var.size,
    offset: -1,
    is_this: var.is_this,
    is_param: var.is_param,
    is_global: var.is_global,
    is_mut: var.is_mut,
    is_phi: false,
    incoming_vars: [],
    outcoming_var: None,
  }
}

struct Builder {
  method : MachineMethod
  vars : Map[Int, MachineVar]
}

fn Builder::new(method : MachineMethod) -> Builder {
  let vars = Map::new()
  match method.this {
    Some(this) => vars.set(this.id, this)
    None => ()
  }
  method.params.each(fn { p => vars.set(p.id, p) })
  method.local_vars.each(fn { v => vars.set(v.id, v) })
  Builder::{ method, vars }
}

fn Builder::get_var(self : Builder, var : @ssa.Var) -> MachineVar {
  if var.is_global {
    @util.die("todo")
  } else {
    match self.vars.get(var.id) {
      Some(v) => v
      None => @util.die("unreachable")
    }
  }
}

fn Builder::build(self : Builder, method : @ssa.Method) -> Unit {
  // 1. Build phi vars
  method.body.stmts.each(
    fn {
      stmt =>
        match stmt.stmt {
          Definition(Some(lhs), Phi(vars)) => {
            let lhs = self.get_var(lhs)
            lhs.is_phi = true
            lhs.incoming_vars.push_iter(
              vars
              .iter()
              .map(
                fn {
                  v => {
                    let incoming = self.get_var(v)
                    match incoming.outcoming_var {
                      Some(_) => @util.die("phi var could not be merged twice")
                      None => incoming.outcoming_var = Some(lhs)
                    }
                    incoming
                  }
                },
              ),
            )
          }
          _ => ()
        }
    },
  )
  // 2. Build stmts
  let body = self.method.body
  let stmts_map = Map::new()
  method.body.stmts.each(
    fn {
      ssa_stmt => {
        let machine = self
          .build_stmt(ssa_stmt)
          .map(fn { stmt => Stmt::new(body.stmts.length(), stmt, ssa_stmt) })
        stmts_map.set(ssa_stmt.slot, machine)
        body.stmts.push_iter(machine.iter())
      }
    },
  )
  // 3. Build blocks
  method.body.blocks.each(
    fn {
      blk => {
        let machine_blk = { label: blk.label, stmts: [] }
        body.blocks.push(machine_blk)
        blk.stmts.each(
          fn {
            stmt =>
              machine_blk.stmts.push_iter(
                stmts_map.get(stmt.slot).unwrap().iter(),
              )
          },
        )
      }
    },
  )
}

fn Builder::build_stmt(self : Builder, stmt : @ssa.Stmt) -> Array[StmtKind] {
  match stmt.stmt {
    Definition(_, _) => @util.die("todo")
    PutArray(_) => @util.die("todo")
    IfGoto(_) => @util.die("todo")
    Goto(_) => @util.die("todo")
    Break(_) => @util.die("todo")
    Continue(_) => @util.die("todo")
    Nop => [Nop]
    Return(v) => [Return(v.map(fn { v => self.get_var(v) }))]
  }
}
