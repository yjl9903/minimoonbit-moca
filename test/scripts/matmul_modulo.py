import itertools
import os
import re
import subprocess
import random
import numpy as np
source = """

let state: Array[Int] = Array::make(1, 0);

fn random(state: Int) -> Int {
  state * %d + %d
};

fn modulo(x: Int, y: Int) -> Int {
  let q = x / y;
  x - q * y
};

fn matrix(m: Int,n : Int) -> (Int, Int, Array[Array[Int]]){
  let dummy = Array::make(0, 0);
  let res = Array::make(m,dummy);
  fn gen_arr(m: Int, n: Int) -> Unit {
    fn init_arr(i: Int) -> Unit {
      if 0 <= i {
        res[i] = Array::make(n, 0);
        fn fill(j) {
          if 0 <= j {
            let new_state = modulo(random(state[0]),10000);
            state[0] = new_state;
            res[i][j] = new_state;
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
    ()
  };
  let _ = gen_arr(m,n);
  (m,n,res)
};


fn zero_matrix(m: Int,n : Int) -> Array[Array[Int]] {
   let dummy = Array::make(0, 0);
  let res = Array::make(m,dummy);
  fn gen_arr(m: Int, n: Int) -> Unit {
    fn init_arr(i: Int) -> Unit {
      if 0 <= i {
        res[i] = Array::make(n, 0);
        init_arr(i - 1)
      } else {
        ()
      }
    };
    let _ = init_arr(m - 1);
    ()
  };
  let _ = gen_arr(m,n);
  res
};
fn mat_mul(A : (Int, Int, Array[Array[Int]]), B : (Int, Int, Array[Array[Int]])) -> (Int, Int, Array[Array[Int]]){
  let (m,n,a) = A;
  let (n,l,b) = B;
  let c = zero_matrix(m,l);
    fn loop1(i: Int) -> Unit {
    if 0 <= i {
      fn loop2(j: Int) -> Unit {
        if 0 <= j {
          c[i][j] = 0;
          fn loop3(k: Int) -> Unit {
            if 0 <= k {
              c[i][j] = c[i][j] + a[i][k] * b[k][j];
              c[i][j] = modulo(c[i][j],10000);
              loop3(k - 1)
            } else {
              ()
            }
          };
          let _ = loop3(n - 1);
          loop2(j - 1)
        } else {
          ()
        }
      };
      let _ = loop2(l - 1);
      loop1(i - 1)
    } else {
      ()
    }
  };
  let _ = loop1(m - 1);
  (m,l,c)
};

fn print_mat(X : (Int, Int, Array[Array[Int]])) -> Unit {
  let (m,n,mat) = X;
  let _ = print_int(m);
  let _ = print_char(32);
  let _  = print_int(n);
  let _ = print_endline();
  fn print_row(i : Int) -> Unit {
    if i + 1 <= m {
      fn print_col(j : Int) -> Unit {
        if j + 1 <= n {
          let _ = print_int(mat[i][j]);
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
  let m = 5;
  let n = 5;
  let k = 5;
  let A = matrix(m,n);
  let B = matrix(n,k);
  let C = mat_mul(A,B);
  let _ = print_mat(A);
  let _ = print_mat(B);
  let _ = print_mat(C);
  ()
};
"""

output_file_path = "test/scripts/temp/matmul_modulo.mbt"

command = ["./run_riscv.sh", output_file_path]

MOD = 10000

cnt = 0

while True:
  x = random.randint(100,10000)
  y = random.randint(100,10000)
  modified_code = source % (x,y)
  if not os.path.exists('./test/scripts/temp'):
      os.mkdir('./test/scripts/temp')

  with open(output_file_path, "w") as file:
      file.write(modified_code)

  try:
      result = subprocess.run(command, check=True, capture_output=True, text=True)
  except subprocess.CalledProcessError as e:
      print(e.stderr)
      
  output = result.stdout

  list = re.split(r'[ \n]+', output)
  print(list)
  # 将行解析成矩阵
  matrix1 = []
  matrix2 = []
  matrix3 = []
  idx = 0
  n = int(list[idx])
  idx += 1
  m = int(list[idx])
  idx += 1
  for i in range(n * m):
      x = int(list[idx])
      matrix1.append(x)
      idx += 1
  matrix1 = np.array(matrix1)
  matrix1 = matrix1.reshape(n,m)

  n = int(list[idx])
  idx += 1
  m = int(list[idx])
  idx += 1
  for i in range(n * m):
      x = int(list[idx])
      matrix2.append(x)
      idx += 1
  matrix2 = np.array(matrix2)
  matrix2 = matrix2.reshape(n,m)

  n = int(list[idx])
  idx += 1
  m = int(list[idx])
  idx += 1
  for i in range(n * m):
      x = int(list[idx])
      matrix3.append(x)
      idx += 1
  matrix3 = np.array(matrix3)
  matrix3 = matrix3.reshape(n,m)
  # res = np.dot(matrix1, matrix2) % MOD
  flag = 0
  if np.array_equal(np.dot(matrix1, matrix2) % MOD, matrix3) is False:
    print("The first two matrices do not multiply to give the third matrix.")
    flag = 1
  else:
    cnt += 1
    print("x : %d ,y : %d , cnt : %d" % (x,y,cnt))
  if flag : 
     print(modified_code)
     break
  