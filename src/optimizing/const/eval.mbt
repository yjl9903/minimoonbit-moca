fn get_bin_op_value_Int(lhs : Int, rhs : Int, op : @types.Op) -> Int {
  match op {
    Add => lhs + rhs
    Sub => lhs - rhs
    Mul => lhs * rhs
    Div => lhs / rhs
  }
}

fn get_bin_op_value_Double(
  lhs : Double,
  rhs : Double,
  op : @types.Op
) -> Double {
  match op {
    Add => lhs + rhs
    Sub => lhs - rhs
    Mul => lhs * rhs
    Div => lhs / rhs
  }
}
