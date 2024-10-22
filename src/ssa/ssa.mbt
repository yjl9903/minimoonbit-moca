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

typealias Type = @closure.LowType

pub struct Var {
  id : Int
  name : String?
  slot : Int
  ty : Type
  is_this : Bool // this
  is_param : Bool // param
  is_global : Bool // from global
  const_value : RValue? // const
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
  GetClosure(Var, FreeVar) // this->_
  InvokeClosure(Var, Array[Var]) // _ (_0, _1, ...)
  InvokeDirect(String, Array[Var])
  Phi(Array[Var]) // phi (_0, _1, ...)
}

pub enum Condition {
  Eq(Var, Var)
  Le(Var, Var)
}

pub enum StmtKind {
  Definition(Var?, RValue) // _ = _
  PutArray(Var, Var, Var) // _[_] = _
  // Condition, true branch block label, false branch block label
  IfGoto(Condition, Int?, Int?) // if _ { _ } else { _ }
  // Go to label
  Goto(Int) // goto _
  Nop // nop
  Return(Var) // return _
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

pub fn Stmt::update(self : Stmt, stmt : StmtKind) -> Unit {
  let (def, uses) = get_def_uses(stmt)
  self.def = def
  self.uses = uses
  self.stmt = stmt
}

fn Stmt::get_def_uses(stmt : StmtKind) -> (Var?, Array[Var]) {
  // TODO: get def use
  match stmt {
    Definition(lhs, _rvalue) => (lhs, [])
    _ => (None, [])
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

pub struct Block {
  label : Int
  stmts : Array[Stmt]
  succ : Array[Block]
}

fn Block::new(label : Int) -> Block {
  { label, stmts: [], succ: [] }
}

pub fn PrimOp::to_string(self : PrimOp) -> String {
  match self {
    Add => "+"
    Sub => "-"
    Mul => "*"
    Div => "/"
  }
}

pub fn RValue::to_string(self : RValue) -> String {
  match self {
    Unit => "Unit"
    Int(v) => "(Int) \{v}"
    Double(v) => "(Double) \{v}"
    Neg(v, kind) => "(\{kind}) -\{v.to_string()}"
    Prim(lhs, rhs, op, kind) => "(\{kind}) \{lhs} \{op} \{rhs}"
    Var(v) => v.to_string()
    Tuple(els) => {
      let els = els.map(fn { el => el.to_string() }).join(", ")
      "(\{els})"
    }
    Closure(label, free_vars) => {
      let bindings = free_vars
        .map(fn { (fv, var) => "\{fv.to_string()} = \{var.to_string()}" })
        .join(", ")
      "make_closure \"\{label}\" { \{bindings} } "
    }
    GetTuple(recv, idx) => "\{recv.to_string()}.\{idx.to_string()}"
    GetArray(recv, idx) => "\{recv.to_string()}[\{idx.to_string()}]"
    GetClosure(v, fv) => "get_closure \{v} -> \{fv.to_string()}"
    InvokeClosure(callee, args) => {
      let args = args.map(fn { el => el.to_string() }).join(", ")
      "invoke_closure \{callee} (\{args})"
    }
    InvokeDirect(label, args) => {
      let args = args.map(fn { el => el.to_string() }).join(", ")
      "invoke_direct \"\{label}\" (\{args})"
    }
    Phi(els) => {
      let els = els.map(fn { el => el.to_string() }).join(", ")
      "phi (\{els})"
    }
  }
}

pub fn StmtKind::to_string(self : StmtKind) -> String {
  match self {
    Definition(Some(lhs), rvalue) =>
      "\{lhs.to_string()} : \{lhs.ty.to_string()} = \{rvalue.to_string()}"
    Definition(None, rvalue) => rvalue.to_string()
    PutArray(_, _, _) => ""
    IfGoto(_, _, _) => ""
    Goto(t) => "goto \{t};"
    Nop => "nop;"
    Return(rvalue) => "return \{rvalue.to_string()}"
  }
}
