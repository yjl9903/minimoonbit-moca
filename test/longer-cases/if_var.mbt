
fn print_bool(x: Bool) -> Unit {
  if (x) {
    print_char(84) // T
  } else {
    print_char(70) // F
  }
};

fn main {
  let x = 1;
  let _ = print_bool(true);
  let _ = print_bool(false);
  let _ = print_bool(1 <= 1);
  let _ = print_bool(1 <= 1);
  let _ = print_bool(2 <= 1);
  let _ = print_bool(2 <= 3);
  let _ = print_bool(1 == 1);
  let _ = print_bool(1 == 3);
  ()
};
