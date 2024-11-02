fn wrapper() -> Array[(Unit) -> Int] {
  fn f1(x : Unit) -> Int {
    1
  };

  fn f2(x : Unit) -> Int {
    f1(()) + 1
  };

  fn f3(x : Unit) -> Int {
    f2(()) + 1
  };

  fn print(arr: Array[(Unit) -> Int]) -> (Unit) -> (Unit) -> Unit {
    let t = arr[1];
    arr[1] = arr[0];
    arr[0] = t;
    fn inner(x : Unit) -> (Unit) -> Unit {
      fn inner(x: Unit) -> Unit {
        let x = arr[1];
        let t = t(());
        let _ = print_int(x(()));
        let _ = print_int(t);
        ()
      };
      fn inner2(x: Unit) -> Unit {
        let x = arr[1];
        let t = t(());
        let _ = print_int(t);
        let _ = print_int(x(()));
        ()
      };
      if arr[2](()) == 1 {
        inner
      } else {
        inner2
      }
    };
    inner
  };

  let id = 2;
  let arr = Array::make(3, f1);
  arr[0] = f1;
  arr[1] = f2;
  arr[2] = f3;
  let _ = print(arr)(())(());
  arr
};

fn main {
  let arr = wrapper();
  let _ = print_int(arr[2](()));
  ()
};
