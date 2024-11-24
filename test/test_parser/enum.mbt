
enum Option{
  Some(Int)
  None
};

enum Color{
  Red
  Yellow
  Blue
};

enum Expr {
  Var(String)
  Number(Int)
  Float(Double)
  Add(Expr,Expr)
  Sub(Expr,Expr)
  Mul(Expr,Expr)
  DIV(Expr,Expr)
};

let y : Option = Option::Some(1);

fn main {
  let z = match y {
    Option::Some(f) => {f}
    _ => {0}
  };
  let s : Expr = Expr::Add(Expr::Number(1),Expr::Number(2));
  let r = match s {
    Expr::Var(var) => {f}
    Expr::Number(number) => {number}
    Expr::Float(float) => {float}
    Expr::Add(_,_) => { Expr::Var(1)}
  };
  ()
};