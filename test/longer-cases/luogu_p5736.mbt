
// logic

fn or(a: Bool, b: Bool) -> Bool {
  if (a) {
    true
  } else {
    if (b) {
      true
    } else {
      false
    }
  }
};

// arith

fn mod(x: Int, y: Int) -> Int {
  x - x / y * y
};

// array

fn copy(src: Array[Int], dst: Array[Int], n: Int) -> Unit {
  fn copy_iter(i: Int) -> Unit {
    if (i <= n - 1) {
      dst[i] = src[i];
      copy_iter(i + 1)
    } else {
      ()
    }
  };
  copy_iter(0)
};

// stream

fn to_stream(a: Array[Int], n: Int) -> (Unit) -> (Bool, Int) {
  let (b, cur) = (Array::make(n, 0), Array::make(1, -1));
  let _ = copy(a, b, n);
  fn func(_) -> (Bool, Int) {
    cur[0] = cur[0] + 1;
    if (cur[0] <= n - 1) {
      (true, b[cur[0]])
    } else {
      (false, -1)
    }
  };
  func
};

fn range(from: Int, to: Int) -> (Unit) -> (Bool, Int) {
  let cur = Array::make(1, from);
  fn func(u) -> (Bool, Int) {
    let val = cur[0];
    if to <= val {
      (false, 0)
    } else {
      cur[0] = val + 1;
      (true, val)
    }
  };
  func
};

fn filter(stream: (Unit) -> (Bool, Int), checker: (Int) -> Bool) -> (Unit) -> (Bool, Int) {
  fn func(_) -> (Bool, Int) {
    let (state, val) = stream(());
    if (state) {
      if (checker(val)) {
        (state, val)
      } else {
        func(())
      }
    } else {
      (state, val)
    }
  };
  func
};

fn count(stream: (Unit) -> (Bool, Int)) -> (Unit) -> Int {
  fn func(_) -> Int {
    let (state, val) = stream(());
    if (state) {
      func(()) + 1
    } else {
      0
    }
  };
  func
};

fn print(stream: (Unit) -> (Bool, Int)) -> (Unit) -> Unit {
  fn func(_) -> Unit {
    let (state, val) = stream(());
    if (state) {
      let _ = print_int(val);
      let _ = print_char(32);
      func(())
    } else {
      print_char(10)
    }
  };
  func
};

fn is_prime(num: Int) -> Bool {
  if (num == 1) {
    false
  } else {
    fn mod_check(p: Int) -> (Int) -> Bool {
      let P = p;
      fn temp(x: Int) {
        mod(P, x) == 0
      };
      temp
    };

    let all_number = range(2, truncate(sqrt(float_of_int(num))) + 1);
    let factor = filter(all_number, mod_check(num));

    // let print()

    if (count(factor)(()) <= 0) {
      true
    } else {
      false
    }
  }
};

fn main {
  
  let a = range(1, 50);
  let prime_a = filter(a, is_prime);
  let _ = print(prime_a)(());

  ()
};
