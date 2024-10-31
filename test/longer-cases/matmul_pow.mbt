fn modulo(x: Int, y: Int) -> Int {
  let q = x / y;
  x - q * y
};

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

fn gen_arr(m: Int, n: Int,filled: Bool) -> Array[Array[Double]] {
  let state = Array::make(1, 9999);
  let dummy = Array::make(0, 0.0);
  let mat = Array::make(m, dummy);
  fn init_arr(i: Int) -> Unit {
    if 0 <= i {
      mat[i] = Array::make(n, 0.0);
      fn fill(j) {
        if 0 <= j {
          let new_state = random(state[0]);
          state[0] = new_state;
          let res = modulo(new_state, 10);
          mat[i][j] = float_of_int(res);
          fill(j - 1)
        } else {
          ()
        }
      };
      if filled {
        let _ = fill(n - 1);
        init_arr(i - 1)
      }
      else {
        init_arr(i - 1)
      }
    } else {
      ()
    }
  };
  let _ = init_arr(m - 1);
  mat
};

fn matmul_pow(n: Int,k: Int, a: Array[Array[Double]]) -> Array[Array[Double]] {
  let tmp = gen_arr(n,n,false);
  let res = gen_arr(n,n,false);
  fn one(i: Int) -> Unit{
    if 0 <= i{
      tmp[i][i] = 1.0;
      one(i - 1)
    }
    else{
      ()
    }
  };
  let _ = one(n - 1);
  if k == 0{
    tmp
  }
  else{
    if k == 1 {
      a
    }
    else {
      if modulo(k,2) == 0{
        let half = matmul_pow(n,k / 2, a);
        let _ = matmul(n,n,n,half,half,res);
        res
      }
      else {
        let half = matmul_pow(n,(k - 1) / 2, a);
        let tmp2 = gen_arr(n,n,false);
        let _ = matmul(n,n,n,half,half,tmp2);
        let _ = matmul(n,n,n,tmp2,a,res);
        res
      }
    }
  }
};


fn main {
  let a = gen_arr(2, 2,true);
  let b = gen_arr(2, 2,false);
  let c = gen_arr(2, 2,false);
  let _ = matmul(2,2,2,a,b,c);
  let d = matmul_pow(2,12,a);
  let _ = print_mat(2, 2, d);
  ()
};



