fn main {
  let arr = Array::make(10, 0);
  let arr = map(arr) { it => {it + 1}};
  ()
};