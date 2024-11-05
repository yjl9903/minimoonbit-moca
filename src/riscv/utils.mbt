fn align_to(value : Int, base : Int) -> Int {
  (value + base - 1) / base * base
}

fn assert_die(flag : Bool, ~message : String? = None) -> Unit {
  if not(flag) {
    match message {
      Some(m) => @util.die(m)
      None => @util.die("riscv assertion error")
    }
  }
}

fn is_power_of_two(value : Int) -> Int? {
  if value <= 0 {
    None
  } else {
    let mut cnt = 0
    let mut x = value
    while x % 2 == 0 {
      x /= 2
      cnt += 1
    }
    if x == 1 {
      Some(cnt)
    } else {
      None
    }
  }
}

test "is_power_of_two" {
  assert_eq!(is_power_of_two(1), Some(0))
  assert_eq!(is_power_of_two(2), Some(1))
  assert_eq!(is_power_of_two(3), None)
  assert_eq!(is_power_of_two(4), Some(2))
  assert_eq!(is_power_of_two(8), Some(3))
  assert_eq!(is_power_of_two(16), Some(4))
}

fn eval_int_bin_op(lhs : Int, op : PrimOp, rhs : Int) -> Int? {
  match op {
    Add => Some(lhs + rhs)
    Sub => Some(lhs - rhs)
    Mul => Some(lhs * rhs)
    Div => if rhs == 0 { None } else { Some(lhs / rhs) }
  }
}

// fn eval_int64_bin_op(lhs : Int, op : PrimOp, rhs : Int) -> Int64? {
//   let lhs = lhs.to_int64()
//   let rhs = rhs.to_int64()
//   match op {
//     Add => Some(lhs + rhs)
//     Sub => Some(lhs - rhs)
//     Mul => Some(lhs * rhs)
//     Div => if rhs == 0 { None } else { Some(lhs / rhs) }
//   }
// }
