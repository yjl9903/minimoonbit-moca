fn print_none() -> Unit {
  ()
};

fn main {
  let arr = Array::make(1, print_none);
  let _ = arr[0]();
  ()
};