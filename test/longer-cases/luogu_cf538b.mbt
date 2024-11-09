
fn min(origin: (Int, Int), new: (Int, Int)) -> (Int, Int) {
  let (cost, last) = origin;
  let (n_cost, n_last) = new;
  if not(n_cost == -1) {
    if cost == -1 {
      new
    } else {
      if cost <= n_cost {
        origin
      } else {
        new
      }
    }
  } else {
    origin
  }
};

fn concat(stream1: (Unit) -> (Int, Int), stream2: (Unit) -> (Int, Int)) -> (Unit) -> (Int, Int) {
  fn next(_) -> (Int, Int) {
    let (exist, val) = stream1(());
    if exist == 0 {
      stream2(())
    } else {
      (exist, val)
    }
  };
  next
};

fn print(stream: (Unit) -> (Int, Int)) -> (Unit) -> Unit {
  fn func(_) -> Unit {
    let (state, val) = stream(());
    if (state == 1) {
      let _ = print_int(val);
      let _ = print_char(32);
      func(())
    } else {
      print_char(10)
    }
  };
  func
};

fn get_empty() -> (Unit) -> (Int, Int) {
  fn next(_) -> (Int, Int) {
    (0, 0)
  };
  next
};

fn get_num(x: Int) -> (Unit) -> (Int, Int) {
  let idx = Array::make(1, 0);
  fn next(_) -> (Int, Int) {
    if idx[0] == 0 {
      idx[0] = idx[0] + 1;
      (1, x)
    } else {
      (0, 0)
    }
  };
  next
};

fn gen_list(n: Int, cur: Int) -> (Unit) -> (Int, Int) {
  // let _ = print_int(cur);
  // let _ = print_char(10);
  if n + 1 <= cur {
    get_empty()
  } else {
    concat(get_num(cur), concat(gen_list(n, cur * 10), gen_list(n, cur * 10 + 1)))
  }
};

fn upd_dp_num(idx: Int, dp: Array[(Int, Int)], val: Int) -> Unit {
  if (0 <= idx - val) {
    // let _ = print_char(33);
    // let _ = print_int(idx);
    // let _ = print_char(32);
    // let _ = print_int(val);
    let (cost, _) = dp[idx - val];
    // let _ = print_char(32);
    // let _ = print_int(cost);
    // let _ = print_char(10);
    dp[idx] = min(dp[idx], (cost + 1, idx - val));
    ()
  }
};

fn upd_dp_nums(idx: Int, n: Int, dp: Array[(Int, Int)]) -> Unit {
  let list = gen_list(n, 1);
  fn next() {
    let (exist, val) = list(());
    // let _ = print_int(exist);
    // let _ = print_char(32);
    // let _ = print_int(val);
    // let _ = print_char(10);
    if exist == 1 {
      let _ = upd_dp_num(idx, dp, val);
      next()
    }
  };
  next()
};

fn solve(cur: Int, n: Int, dp: Array[(Int, Int)]) -> Unit {
  if cur <= n {
    let _ = upd_dp_nums(cur, n, dp);
    solve(cur + 1, n, dp)
  }
};

fn main {

  let n = 4399;
  let dp: Array[(Int, Int)] = Array::make(n + 1, (-1, -1));

  dp[0] = (0, -1);
  let _ = solve(1, n, dp);
  let (cost, _) = dp[n];
  let _ = print_int(cost);
  let _ = print_char(10);

  fn show(cur: Int) -> Unit {
    if 1 <= cur {
      let (_, pre) = dp[cur];
      let _ = print_int(cur - pre);
      let _ = print_char(32);
      let _ = show(pre);
      ()
    } else {
      print_char(10)
    }
  };
  let _ = show(n);

  ()
};
