fn get_bin_op_value(lhs : Int, rhs : Int, op : @types.Op) -> Int {
  match op {
    Add => lhs + rhs
    Sub => lhs - rhs
    Mul => lhs * rhs
    Div => lhs / rhs
  }
}
