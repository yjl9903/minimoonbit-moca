fn main {
  let a = match 1 {
    1 => {10}
    2 => {4}
    _ => {0}
  };
  let b = read_int();
  let c =  match b {
    1 => {10}
    2 => {4}
    _ => {0}
  };
  let _ = print_int(c);
  ()
};