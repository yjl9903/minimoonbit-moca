pub enum PrimKind {
  Int
  Double
} derive(Show, Eq)

pub enum PrimOp {
  Add
  Sub
  Mul
  Div
} derive(Eq)

pub fn PrimOp::to_string(self : PrimOp) -> String {
  match self {
    Add => "+"
    Sub => "-"
    Mul => "*"
    Div => "/"
  }
}

pub fn PrimOp::output(self : PrimOp, logger : Logger) -> Unit {
  logger.write_string(self.to_string())
}

pub struct Var {
  id : Int
  name : String?
  ty : Type
  is_this : Bool // this
  is_param : Bool // param
  mut is_global : Bool // from global
  mut is_mut : Bool // is mutable, may be updated from loop
  mut const_value : RValue? // const

  // phi
  is_phi : Bool
  mut outcoming : Var?
}

pub fn Var::op_equal(self : Var, other : Var) -> Bool {
  self.id == other.id
}

pub fn Var::to_string(self : Var) -> String {
  if self.is_this {
    self.name.unwrap()
  } else {
    self.name.or("") + "_" + self.id.to_string()
  }
}

pub fn Var::output(self : Var, logger : Logger) -> Unit {
  logger.write_string(self.to_string())
}

pub fn Var::is_const(self : Var) -> Bool {
  match self.const_value {
    Some(Unit) => true
    Some(Int(_)) => true
    Some(Double(_)) => true
    _ => false
  }
}

pub struct FreeVar {
  id : Int
  name : String?
  slot : Int
  ty : Type
}

pub fn FreeVar::op_equal(self : FreeVar, other : FreeVar) -> Bool {
  self.id == other.id
}

pub fn FreeVar::to_string(self : FreeVar) -> String {
  self.name.or("") + "_" + self.id.to_string()
}

pub fn FreeVar::output(self : FreeVar, logger : Logger) -> Unit {
  logger.write_string(self.to_string())
}

pub enum RValue {
  Unit
  Int(Int)
  Double(Double)
  Neg(Var, PrimKind) // - _
  Prim(Var, Var, PrimOp, PrimKind) // _ + - * / _
  Var(Var) // _
  Tuple(Array[Var]) // (_0, _1, _2, ...)
  Closure(String, Array[(FreeVar, Var)]) // signature, free vars
  GetTuple(Var, Int) // _.0 / _.1 / _.2 / ...
  GetArray(Var, Var) // _ [ _ ]
  GetClosure(Var, FreeVar, Array[FreeVar]) // this->_
  InvokeClosure(Var, Array[Var]) // _ (_0, _1, ...)
  InvokeDirect(String, Array[Var])
  Phi(Array[Var]) // phi (_0, _1, ...)
} derive(Show)

pub enum Condition {
  Eq(Var, Var)
  Le(Var, Var)
} derive(Show)

pub enum StmtKind {
  Definition(Var?, RValue) // _ = _
  PutArray(Var, Var, Var) // _[_] = _
  // Condition, true branch block label, false branch block label, next block label
  IfGoto(Condition, Int?, Int?, Int?) // if _ { _ } else { _ }
  // Go to label
  Goto(Int) // goto _
  Break(Int, Int) // break _, then goto _
  Continue(Int) // continue _
  Nop // nop
  Return(Var?) // return _
}

pub struct Stmt {
  slot : Int
  mut stmt : StmtKind
  mut def : Var?
  mut uses : Array[Var]
}

pub fn Stmt::new(slot : Int, stmt : StmtKind) -> Stmt {
  let (def, uses) = get_def_uses(stmt)
  { slot, stmt, def, uses }
}

pub fn Stmt::has_side_effects(self : Stmt) -> Bool {
  match self.stmt {
    Definition(_, InvokeClosure(_) | InvokeDirect(_) | Phi(_)) => true
    Definition(_) => false
    _ => true
  }
}

pub fn Stmt::update(self : Stmt, stmt : StmtKind) -> Unit {
  let (def, uses) = get_def_uses(stmt)
  self.def = def
  self.uses = uses
  self.stmt = stmt
}

fn Stmt::get_def_uses(stmt : StmtKind) -> (Var?, Array[Var]) {
  fn get_rvalue_uses(rvalue : RValue) -> Array[Var] {
    match rvalue {
      Unit | Int(_) | Double(_) => []
      Neg(var, _) => [var]
      Prim(lhs, rhs, _, _) => [lhs, rhs]
      Var(var) => [var]
      Tuple(els) => [..els]
      Closure(_, fvs) => fvs.map(fn { fv => fv.1 })
      GetTuple(base, _) => [base]
      GetArray(recv, idx) => [recv, idx]
      GetClosure(recv, _, _) => [recv]
      InvokeClosure(recv, args) => [recv, ..args]
      InvokeDirect(_, args) => [..args]
      Phi(vs) => [..vs]
    }
  }

  match stmt {
    Definition(lhs, rvalue) => (lhs, get_rvalue_uses(rvalue))
    PutArray(recv, idx, value) => (None, [recv, idx, value])
    IfGoto(cond, _, _, _) =>
      match cond {
        Eq(lhs, rhs) | Le(lhs, rhs) => (None, [lhs, rhs])
      }
    Return(var) =>
      match var {
        Some(var) => (None, [var])
        None => (None, [])
      }
    _ => (None, [])
  }
}

pub fn IR::get_next_block_ids(
  self : IR,
  block_id : Int,
  stmt_id : Int
) -> Array[(Int, Int)] {
  let block = self.blocks[block_id]
  let stmt = block.stmts[stmt_id]
  match stmt.stmt {
    Definition(_) | PutArray(_) | Nop =>
      if stmt_id + 1 == block.stmts.length() {
        match block.succ {
          Some(Next(idx) | IfEnd(idx) | Continue(idx) | Break(idx)) =>
            [(idx.label, 0)]
          Some(While(loop_blk, _)) => [(loop_blk.label, 0)]
          Some(IfStart(_)) => @util.die("unreachable")
          None => []
        }
      } else {
        [(block_id, stmt_id + 1)]
      }
    IfGoto(_, true_target, false_target, _) =>
      [(true_target.unwrap(), 0), (false_target.unwrap(), 0)]
    Goto(idx) | Continue(idx) | Break(_, idx) => [(idx, 0)]
    Return(_) => []
  }
}

pub struct Method {
  name : String
  slot : Int
  ty : Type
  this : Var?
  params : Array[Var]
  local_vars : Array[Var]
  body : IR

  // closure
  is_closure : Bool
  local_free_vars : Array[Var]
  formal_free_vars : Array[FreeVar]
}

pub struct IR {
  stmts : Array[Stmt]
  blocks : Array[Block]
}

pub fn IR::labels(self : IR) -> Map[Int, Block] {
  Map::from_array(self.blocks.map(fn { b => (b.stmts[0].slot, b) }))
}

pub struct Block {
  label : Int
  stmts : Array[Stmt]
  mut succ : BlockEdge?
}

pub enum BlockEdge {
  Next(Block)
  IfStart(Block, Block, Block?)
  IfEnd(Block)
  While(Block, Block)
  Continue(Block)
  Break(Block)
}

fn Block::new(label : Int) -> Block {
  { label, stmts: [], succ: None }
}
