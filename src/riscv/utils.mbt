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
