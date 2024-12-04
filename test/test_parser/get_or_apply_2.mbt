fn main {
  let arr = Array::make(10, 0);
  let arr = map(arr) { it => {
    let f = it + 1;
    f + 2
  }};

  let arr = map(arr) { (lhs,rhs) => {
    lhs + rhs 
  }};
  // // ---
  ()
};