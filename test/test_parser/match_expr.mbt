
fn main {
  let a = match 1 {
    () => {1}
    (1,2,3) => {2}
    2 => {10}
    3 => {4}
    true => {1}
    false => {2}
    (1,2,3) => {6}
    Op::None => {4}
    Option::Some(1) => {100}
  };
  ()
};