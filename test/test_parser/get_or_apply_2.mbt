fn main {
  let arr = Array::make(10, 0);
  fn __receiver_0(it) {
    it + 1
  };
  let arr = map(arr, __receiver_0);
  // // ---
  ()
};