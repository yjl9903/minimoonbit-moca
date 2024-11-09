
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

fn power(x: Int, y: Int) -> Int {
  fn lp(n: Int) -> Int {
    if 1 <= n {
      let res = lp (n / 2);
      res * res * if mod(n, 2) == 1 {
        x
      } else {
        1
      }
    } else {
      1
    }
  };
  lp(y)
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

let dummy: Array[Int] = Array::make(0, 0);
fn gen_arr(m: Int, n: Int, v: Int) -> Array[Array[Int]] {
  let mat = Array::make(m, dummy);
  fn init_arr(i: Int) -> Unit {
    if 0 <= i {
      mat[i] = Array::make(n, v);
      init_arr(i - 1)
    } else {
      ()
    }
  };
  let _ = init_arr(m - 1);
  mat
};

fn print_array2d(m: Int, n: Int, res: Array[Array[Int]]) -> Unit {
  fn loop_i(i: Int) -> Unit {
    if (i <= m - 1) {
      fn loop_j(j: Int) -> Unit {
        if (j <= n - 1) {
          let _ = print_int(res[i][j]);
          let _ = print_char(32);
          loop_j(j + 1)
        } else {
          ()
        }
      };
      let _ = loop_j(0);
      let _ = print_char(10);
      loop_i(i + 1)
    } else {
      ()
    }
  };
  loop_i(0)
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

fn draw(base_x: Int, base_y: Int, n: Int, res: Array[Array[Int]]) -> Unit {
  if 1 <= n {
    fn loop_row(r: Int) -> Unit {
      if (r <= n / 2 - 1) {
        fn loop_col(c: Int) -> Unit {
          if (c <= n / 2 - 1) {
            res[base_x + r][base_y + c] = 0;
            loop_col(c + 1)
          }
        };
        let _ = loop_col(0);
        loop_row(r + 1)
      } else {
        ()
      }
    };
    let _ = loop_row(0);
    let _ = draw(base_x + n / 2, base_y, n / 2, res);
    let _ = draw(base_x, base_y + n / 2, n / 2, res);
    let _ = draw(base_x + n / 2, base_y + n / 2, n / 2, res);
    ()
  }
};

fn main {
  let n = 10;
  let N = power(2, n);
  let res = gen_arr(N, N, 1);

  let _ = draw(0, 0, N, res);

  let _ = print_array2d(N, N, res);

  ()
};
