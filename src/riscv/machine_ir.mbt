pub struct MachineWorld {
  globals : Map[Int, (String, MachineVar)]
  doubles : Map[Double, String]
  methods : Array[MachineMethod]
  ssa : @ssa.World
}

let cached_world : Ref[MachineWorld?] = { val: None }

pub fn get_world() -> MachineWorld {
  cached_world.val.unwrap()
}

pub struct MachineMethod {
  id : Int
  name : String
  label : String
  ty : Type
  is_main : Bool

  // vars
  this : MachineVar?
  params : Array[MachineVar] // including this, params
  local_vars : Array[MachineVar] // including this, params, local_vars

  // info
  stack_vars : Map[Int, MachineVar]
  mut stack_size : Int

  // body
  body : IR

  // closure
  is_closure : Bool
  free_vars : Array[@ssa.FreeVar]

  // ssa
  ssa_method : @ssa.Method?
}

pub enum ConstValue {
  Int(Int)
  Double(Double)
}

pub enum ParamOffset {
  Reg(Reg)
  FReg(FReg)
  Offset(Int)
}

pub struct MachineVar {
  id : Int
  name : String?
  ty : Type
  size : Int
  width : Width

  // Offset
  mut offset : Int
  mut param_offset : ParamOffset?

  // Flags
  mut is_live : Bool
  is_this : Bool // this
  is_param : Bool // param
  is_global : Bool // from global
  is_mut : Bool // is mutable, may be updated from loop
  const_value : ConstValue? // const value

  // phi
  mut is_phi : Bool // phi node
  mut outcoming_var : MachineVar?
  incoming_vars : Array[MachineVar]
}

pub fn MachineVar::to_string(self : MachineVar) -> String {
  let name = self.name.or("")
  name + "_" + self.id.to_string()
}

pub fn MachineVar::output(self : MachineVar, logger : Logger) -> Unit {
  logger.write_string(self.to_string())
}

pub fn MachineVar::memory_id(self : MachineVar) -> Int {
  self.outcoming_var.map(fn { v => v.id }).or(self.id)
}

pub enum Condition {
  Eq(MachineVar, MachineVar, Width)
  Ne(MachineVar, MachineVar, Width)
  Lt(MachineVar, MachineVar, Width)
  Le(MachineVar, MachineVar, Width)
  Gt(MachineVar, MachineVar, Width)
  Ge(MachineVar, MachineVar, Width)
} derive(Show)

pub enum RValue {
  Int(Int)
  Neg(MachineVar, Width)
  Prim(MachineVar, MachineVar, PrimOp, Width)
  Var(MachineVar, Width)
  Load((MachineVar, Int), Width, Int) // load _, _(_) / sanitizer error code
  LoadLabel(String)
  InvokeClosure(MachineVar, Array[MachineVar], Width)
  InvokeDirect(String, Array[MachineVar], Width)
  Malloc(Int)
  Phi(Array[MachineVar])
} derive(Show)

pub enum StmtKind {
  Definition(MachineVar?, RValue)
  Store((MachineVar, Int), MachineVar, Width, Int) // store _(_), _ / sanitizer error code
  Sanitizer(MachineVar, Int)
  IfGoto(Condition, Int?, Int?)
  Goto(Int)
  Comment(String)
  Nop
  Return(MachineVar?)
}

pub struct Stmt {
  slot : Int
  mut stmt : StmtKind
  mut def : MachineVar?
  mut uses : Array[MachineVar]

  // ssa
  ssa : @ssa.Stmt
}

pub fn Stmt::new(slot : Int, stmt : StmtKind, ssa : @ssa.Stmt) -> Stmt {
  let stmt = { slot, stmt, def: None, uses: [], ssa }
  stmt.update_def_uses()
  stmt
}

pub fn Stmt::update(self : Stmt, stmt : StmtKind) -> Stmt {
  self.stmt = stmt
  self.update_def_uses()
  self
}

fn Stmt::update_def_uses(self : Stmt) -> Unit {
  self.def = None
  match self.stmt {
    Definition(def, rvalue) => {
      self.def = def
      let uses = match rvalue {
        Int(_) => []
        Neg(v, _) => [v]
        Prim(lhs, rhs, _, _) => [lhs, rhs]
        Var(v, _) => [v]
        Load((recv, _), _, _) => [recv]
        LoadLabel(_) => []
        InvokeClosure(callee, args, _) => [callee, ..args]
        InvokeDirect(_, args, _) => [..args]
        Malloc(_) => []
        Phi(els) => [..els]
      }
      self.uses = uses
    }
    Store((recv, _), value, _, _) => self.uses = [recv, value]
    Sanitizer(v, _) => self.uses = [v]
    IfGoto(cond, _, _) =>
      match cond {
        Eq(lhs, rhs, _)
        | Ne(lhs, rhs, _)
        | Lt(lhs, rhs, _) | Le(lhs, rhs, _) | Gt(lhs, rhs, _) | Ge(lhs, rhs, _) =>
          self.uses = [lhs, rhs]
      }
    Goto(_) | Comment(_) | Nop => self.uses = []
    Return(Some(v)) => self.uses = [v]
    Return(None) => self.uses = []
  }
}

pub struct IR {
  stmts : Array[Stmt]
  blocks : Array[Block]
}

pub struct Block {
  label : Int
  stmts : Array[Stmt]
  // mut succ : BlockEdge?
}

pub fn IR::get_next_stmts(self : IR, i : Int) -> Array[Int] {
  let stmt = self.stmts[i]
  match stmt.stmt {
    IfGoto(_, true_branch, false_branch) => {
      let next = []
      match true_branch {
        Some(t) => next.push(self.blocks[t].stmts[0].slot)
        None => ()
      }
      match false_branch {
        Some(t) => next.push(self.blocks[t].stmts[0].slot)
        None => ()
      }
      next
    }
    Goto(next) => [self.blocks[next].stmts[0].slot]
    Return(_) => []
    _ => if i + 1 < self.stmts.length() { [i + 1] } else { [] }
  }
}
