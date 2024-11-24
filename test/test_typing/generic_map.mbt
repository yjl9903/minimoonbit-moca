fn map[T, R](n : Int, arr : Array[T], default: R, func : (T) -> R) -> Array[R] {
  let result = Array::make(n, default);
  fn auc(i : Int) -> Unit {
    if i + 1 <= n {
      result[i] = func(arr[i]);
      auc(i + 1)
    }
  };
  let _ = auc(0);
  result
};

fn even(n : Int) -> Bool {
  if n / 2 * 2 == n {
    true
  } else {
    false
  }
};

fn print(f : Bool) -> Int {
  if f {
    let _ = print_int(1);
    1
  } else {
    let _ = print_int(0);
    0
  }
};

fn main {
  let arr = Array::make(5, 0);
  arr[0] = 0;
  arr[1] = 1;
  arr[2] = 2;
  arr[3] = 3;
  arr[4] = 4;
  let arr = map(5, arr, true, even);
  let arr = map(5, arr, -1, print);
  ()
};
