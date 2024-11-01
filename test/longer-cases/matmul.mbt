fn matmul(l: Int, m: Int, n: Int, a: Array[Array[Double]], b: Array[Array[Double]], c: Array[Array[Double]]) -> Unit {
  fn loop1(i: Int) -> Unit {
    if 0 <= i {
      fn loop2(j: Int) -> Unit {
        if 0 <= j {
          fn loop3(k: Int) -> Unit {
            if 0 <= k {
              c[i][j] = c[i][j] + a[i][k] * b[k][j];
              loop3(k - 1)
            } else {
              ()
            }
          };
          let _ = loop3(m - 1);
          loop2(j - 1)
        } else {
          ()
        }
      };
      let _ = loop2(n - 1);
      loop1(i - 1)
    } else {
      ()
    }
  };
  loop1(l - 1)
};

fn random(state: Int) -> Int {
  state * 74 + 47
};

fn modulo(x: Int, y: Int) -> Int {
  let q = x / y;
  x - q * y
};

fn print_mat(m : Int, n : Int, mat : Array[Array[Double]]) -> Unit {
  // let _ = print_int(m);
  // let _ = print_char(32);
  // let _ = print_int(n);
  fn print_row(i : Int) -> Unit {
    if i + 1 <= m {
      fn print_col(j : Int) -> Unit {
        if j + 1 <= n {
          let _ = print_int(truncate(mat[i][j]));
          let _ = print_char(32);
          print_col(j + 1)
        }
      };
      let _ = print_col(0);
      let _ = print_char(10);
      print_row(i + 1)
    }
  };
  print_row(0)
};

fn main {
  let state = Array::make(1, 9999);
  let dummy = Array::make(0, 0.0);

  fn gen_arr(m: Int, n: Int) -> Array[Array[Double]] {
    let mat = Array::make(m, dummy);
    fn init_arr(i: Int) -> Unit {
      if 0 <= i {
        mat[i] = Array::make(n, 0.0);
        fn fill(j) {
          if 0 <= j {
            let new_state = random(state[0]);
            state[0] = new_state;
            let res = modulo(new_state, 999);
            mat[i][j] = float_of_int(res);
            let _ = print_int(res);
            let _ = print_endline();
            fill(j - 1)
          } else {
            ()
          }
        };
        let _ = fill(n - 1);
        init_arr(i - 1)
      } else {
        ()
      }
    };
    let _ = init_arr(m - 1);
    mat
  };

  let a = gen_arr(2, 3);
  let b = gen_arr(3, 2);
  let c = gen_arr(2, 2);
  let _ = matmul(2,3,2,a,b,c);
  let _ = print_mat(2, 3, a);
  let _ = print_mat(3, 2, b);
  let _ = print_mat(2, 2, c);
  // a[0][0] = 1.0; a[0][1] = 2.0; a[0][2] = 3.0;
  // a[1][0] = 4.0; a[1][1] = 5.0; a[1][2] = 6.0;
  // b[0][0] = 7.0; b[0][1] = 8.0;
  // b[1][0] = 9.0; b[1][1] = 10.0;
  // b[2][0] = 11.0; b[2][1] = 12.0;
  // let _ = print_int(truncate(c[0][0]));
  // let _ = print_endline();
  // let _ = print_int(truncate(c[0][1]));
  // let _ = print_endline();
  // let _ = print_int(truncate(c[1][0]));
  // let _ = print_endline();
  // let _ = print_int(truncate(c[1][1]));
  ()
};