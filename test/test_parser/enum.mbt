
enum Option{
  Some(Int)
  None
};

let y : Option = Option::Some(1);

fn main {
  let z = match y {
    Option::Some(f) => f
    _ => 0
  };
  ()
};