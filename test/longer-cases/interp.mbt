fn deltas(n : Int, x : Array[Double]) -> Array[Double] {
  let delta = Array::make(n - 1, x[0]);
  fn loop(i : Int) {
    if i <= n {
      delta[i - 1] = x[i] - x[i - 1];
      loop(i + 1)
    }
  };
  let _ = loop(1);
  delta
};

fn slopes(n : Int, dx : Array[Double], dy : Array[Double]) -> Array[Double] {
  let slope = Array::make(n, dx[0]);
  fn loop(i : Int) {
    if i + 1 <= n {
      slope[i] = dy[i] / dx[i];
      loop(i + 1)
    }
  };
  let _ = loop(0);
  slope
};

fn intercepts(n : Int, x : Array[Double], y : Array[Double], slopes : Array[Double]) -> Array[Double] {
  let ans = Array::make(n, x[0]);
  fn loop(i : Int) {
    if i + 1 <= n {
      ans[i] = y[i] - x[i] * slopes[i];
      loop(i + 1)
    }
  };
  let _ = loop(0);
  ans
};

fn prev_index(n : Int, x : Array[Double], xp : Double) -> Int {
  fn loop(i : Int) {
    if i + 1 <= n {
      if xp <= x[i] {
        if i == 0 {
          0
        } else {
          i - 1
        }
      } else {
        loop(i + 1)
      }
    } else {
      n - 1
    }
  };
  loop(0)
};

fn select_outside_point(x_limits : (Double, Double), y_limits : (Double, Double), xp : Double, default : Double, mode : Int) -> Double {
  let (x_limits_0, x_limits_1) = x_limits;
  let (y_limits_0, y_limits_1) = y_limits;
  if xp <= x_limits_0 {
    if mode == 0 {
      default
    } else {
      y_limits_0
    }
  } else {
    if x_limits_1 <= xp {
      if mode == 0 {
        default
      } else {
        y_limits_1
      }
    } else {
      default
    }
  }
};

fn interp(n : Int, x : Array[Double], y: Array[Double], xp: Double) -> Double {
  let dx = deltas(n, x);
  let dy = deltas(n, y);
  let m = slopes(n - 1, dx, dy);
  let c = intercepts(n - 1, x, y, m);
  let i = prev_index(n - 1, x, xp);
  let point = m[i] * xp + c[i];
  //let _ = print_int(i);
  //let _ = print_endline();
  //let _ = print_int(truncate(m[i]));
  //let _ = print_char(32);
  //let _ = print_int(truncate(c[i]));
  //let _ = print_char(32);
  //let _ = print_int(truncate(point));
  //let _ = print_endline();
  let x_limits = (x[0], x[n - 1]);
  let y_limits = (y[0], y[n - 1]);
  select_outside_point(x_limits, y_limits, xp, point, 0)
};

// 0 1 2 3 4.5 -> x
// 1 1 1 1.5
// 0 2 5 3 2   -> y
// 2 3 -2 -1   
// 2 3 -2 -3/2 -> m
// y - x * m
// 0 -1 9 5    -> c
//     .
// -2 * 2.5 + 9 = 4

fn main {
  let n = 5;
  let xx = Array::make(n, 1.0);
  xx[0] = 0.0;
  xx[1] = 1.0;
  xx[2] = 2.0;
  xx[3] = 3.0;
  xx[4] = 4.5;
  let yy = Array::make(n, 1.0);
  yy[0] = 0.0;
  yy[1] = 2.0;
  yy[2] = 5.0;
  yy[3] = 3.0;
  yy[4] = 2.0;
  // Predict
  let _ = print_int(truncate(interp(n, xx, yy, 2.5)));
  let _ = print_endline();
  let _ = print_int(truncate(interp(n, xx, yy, -1.0)));
  let _ = print_endline();
  let _ = print_int(truncate(interp(n, xx, yy, 7.5)));
  let _ = print_endline();
  ()
};