

// ===== necessary include =====

// ' '
fn print_space() -> Unit {
  print_char(32)
};

// '\n'
fn println() -> Unit {
  print_char(10)
};

// '['
fn __print_colon() -> Unit {
  print_char(58)
};

// '['
fn __printlb() -> Unit {
  print_char(91)
};

// ']'
fn __printrb() -> Unit {
  print_char(93)
};

// ']'
fn __printrb() -> Unit {
  print_char(93)
};

// ','
fn __print_comma() -> Unit {
  print_char(44)
};

// ==========
// ==========


// ===== option function =====

fn print_C(x: Int) -> Unit {
  let _ = print_char(67);
  let _ = __print_colon();
  let _ = print_space();
  let _ = print_int(x);
  print_space()
};

fn print_R(x: Int) -> Unit {
  let _ = print_char(82);
  let _ = __print_colon();
  let _ = print_space();
  let _ = print_int(x);
  print_space()
};

fn print_a(x: Int) -> Unit {
  let _ = print_char(97);
  let _ = __print_colon();
  let _ = print_space();
  let _ = print_int(x);
  print_space()
};
fn print_b(x: Int) -> Unit {
  let _ = print_char(98);
  let _ = __print_colon();
  let _ = print_space();
  let _ = print_int(x);
  print_space()
};
fn print_c(x: Int) -> Unit {
  let _ = print_char(99);
  let _ = __print_colon();
  let _ = print_space();
  let _ = print_int(x);
  print_space()
};
fn print_d(x: Int) -> Unit {
  let _ = print_char(100);
  let _ = __print_colon();
  let _ = print_space();
  let _ = print_int(x);
  print_space()
};
fn print_e(x: Int) -> Unit {
  let _ = print_char(101);
  let _ = __print_colon();
  let _ = print_space();
  let _ = print_int(x);
  print_space()
};
fn print_i(x: Int) -> Unit {
  let _ = print_char(105);
  let _ = __print_colon();
  let _ = print_space();
  let _ = print_int(x);
  print_space()
};
fn print_j(x: Int) -> Unit {
  let _ = print_char(106);
  let _ = __print_colon();
  let _ = print_space();
  let _ = print_int(x);
  print_space()
};
fn print_k(x: Int) -> Unit {
  let _ = print_char(107);
  let _ = __print_colon();
  let _ = print_space();
  let _ = print_int(x);
  print_space()
};
fn print_l(x: Int) -> Unit {
  let _ = print_char(108);
  let _ = __print_colon();
  let _ = print_space();
  let _ = print_int(x);
  print_space()
};
fn print_m(x: Int) -> Unit {
  let _ = print_char(109);
  let _ = __print_colon();
  let _ = print_space();
  let _ = print_int(x);
  print_space()
};
fn print_n(x: Int) -> Unit {
  let _ = print_char(110);
  let _ = __print_colon();
  let _ = print_space();
  let _ = print_int(x);
  print_space()
};
fn print_r(x: Int) -> Unit {
  let _ = print_char(114);
  let _ = __print_colon();
  let _ = print_space();
  let _ = print_int(x);
  print_space()
};
fn print_s(x: Int) -> Unit {
  let _ = print_char(115);
  let _ = __print_colon();
  let _ = print_space();
  let _ = print_int(x);
  print_space()
};
fn print_t(x: Int) -> Unit {
  let _ = print_char(116);
  let _ = __print_colon();
  let _ = print_space();
  let _ = print_int(x);
  print_space()
};
fn print_u(x: Int) -> Unit {
  let _ = print_char(117);
  let _ = __print_colon();
  let _ = print_space();
  let _ = print_int(x);
  print_space()
};
fn print_v(x: Int) -> Unit {
  let _ = print_char(118);
  let _ = __print_colon();
  let _ = print_space();
  let _ = print_int(x);
  print_space()
};
fn print_w(x: Int) -> Unit {
  let _ = print_char(119);
  let _ = __print_colon();
  let _ = print_space();
  let _ = print_int(x);
  print_space()
};
fn print_x(x: Int) -> Unit {
  let _ = print_char(120);
  let _ = __print_colon();
  let _ = print_space();
  let _ = print_int(x);
  print_space()
};
fn print_y(x: Int) -> Unit {
  let _ = print_char(121);
  let _ = __print_colon();
  let _ = print_space();
  let _ = print_int(x);
  print_space()
};
fn print_z(x: Int) -> Unit {
  let _ = print_char(122);
  let _ = __print_colon();
  let _ = print_space();
  let _ = print_int(x);
  print_space()
};

fn print_array_1d(arr: Array[Int], n: Int) -> Unit {
  fn show(cur: Int) -> Unit {
    if cur <= n - 1 {
      let _ = if cur == n - 1 {
        let _ = print_int(arr[cur]);
        ()
      } else {
        let _ = print_int(arr[cur]);
        let _ = __print_comma();
        let _ = print_space();
        ()
      };
      show(cur + 1)
    }
  };
  let _ = __printlb();
  let _ = show(0);
  let _ = __printrb();
  ()
};

fn print_array_2d(arr: Array[Array[Int]], n: Int, m: Int) -> Unit {
  fn show(cur: Int) -> Unit {
    if cur <= n - 1 {
      let _ = if cur == n - 1 {
        let _ = print_array_1d(arr[cur], m);
        ()
      } else {
        let _ = print_array_1d(arr[cur], m);
        let _ = __print_comma();
        let _ = print_space();
        println()
      };
      show(cur + 1)
    }
  };
  let _ = __printlb();
  let _ = show(0);
  let _ = __printrb();
  ()
};

// ==========
// ==========

fn init {
  ()
};

let M: Int = 512;
let N: Int = 256;
let K: Int = 64;
let tile_m: Int = 64;
let tile_n: Int = 32;
let tile_k: Int = 16;
let thr_m: Int = 4;
let thr_n: Int = 8;

// modify here by problem size!!!
let sA: Array[Array[Array[Int]]] = Array::make(M / tile_m, Array::make(0, Array::make(0, 0)));
let sB: Array[Array[Array[Int]]] = Array::make(M / tile_m, Array::make(0, Array::make(0, 0)));
let sC: Array[Array[Array[Int]]] = Array::make(M / tile_m, Array::make(0, Array::make(0, 0)));

fn and(a: Bool, b: Bool) -> Bool {
  if (a) {
    if (b) {
      true
    } else {
      false
    }
  } else {
    false
  }
};

fn gen_mod(P: Int) -> (Int) -> Int {
  fn mod(x: Int) -> Int {
    x - x / P * P
  };
  mod
};
let mat_mod: (Int) -> Int = gen_mod(1997);

fn assert(b: Bool) -> Unit {
  if not(b) {
    print_char(33)
  }
};

fn get_A(arr: Array[Int], x: Int, y: Int) -> Int {
  let _ = assert(and(and(0 <= x, x <= M - 1), and(0 <= y, y <= K - 1)));
  arr[x * K + y]
};

fn get_sA(arr: Array[Int], idx: Int) -> Int {
  let _ = assert(and(0 <= idx, idx <= tile_m * tile_k - 1));
  arr[idx]
};

fn get_B(arr: Array[Int], x: Int, y: Int) -> Int {
  let _ = assert(and(and(0 <= x, x <= N - 1), and(0 <= y, y <= K - 1)));
  arr[x * K + y]
};

fn get_sB(arr: Array[Int], idx: Int) -> Int {
  let _ = assert(and(0 <= idx, idx <= tile_n * tile_k - 1));
  arr[idx]
};

fn get_C(arr: Array[Int], x: Int, y: Int) -> Int {
  let _ = assert(and(and(0 <= x, x <= M - 1), and(0 <= y, y <= N - 1)));
  arr[x * N + y]
};

fn set_A(arr: Array[Int], x: Int, y: Int, val: Int) -> Unit {
  let _ = assert(and(and(0 <= x, x <= M - 1), and(0 <= y, y <= K - 1)));
  arr[x * K + y] = val;
  ()
};

fn set_B(arr: Array[Int], x: Int, y: Int, val: Int) -> Unit {
  let _ = assert(and(and(0 <= x, x <= N - 1), and(0 <= y, y <= K - 1)));
  arr[x * K + y] = val;
  ()
};

fn set_C(arr: Array[Int], x: Int, y: Int, val: Int) -> Unit {
  let _ = assert(and(and(0 <= x, x <= M - 1), and(0 <= y, y <= N - 1)));
  arr[x * N + y] = val;
  ()
};

// problem tile: (2x4x8)
// block shape: (1x4x1)
fn gemm_load(A: Array[Int], B: Array[Int], C: Array[Int],
        bid_x: Int, bid_y: Int, tid_x: Int, tid_y: Int) -> (Unit) -> Int {
  let (bM, bN, bK): (Int, Int, Int) = (tile_m, tile_n, tile_k);
  let (ctaM, ctaN, _): (Int, Int, Int) = (thr_m, thr_n, 1);
  let (row_C, col_C) = (bid_x * bM, bid_y * bN);
  let sA = sA[bid_x][bid_y];
  let sB = sB[bid_x][bid_y];
  let sC = sC[bid_x][bid_y];
  let linear_tid = tid_x * thr_n + tid_y;

  let block_k: Array[Int] = Array::make(1, 0);
  fn micro_kernel(_) -> Int {
    if block_k[0] <= K - 1 {
      // load
      fn load_sA(idx: Int) -> Unit {
        if idx <= bM * bK - 1 {
          let (bias_x, bias_y): (Int, Int) = (idx / bK, idx - idx / bK * bK);
          sA[idx] = get_A(A, row_C + bias_x, block_k[0] + bias_y);
          // let _ = print_i(idx);
          // let _ = print_x(bias_x);
          // let _ = print_y(bias_y);
          // let _ = print_a(sA[idx]);
          // let _ = println();
          load_sA(idx + ctaM * ctaN)
        }
      };
      let _ = load_sA(linear_tid);
      fn load_sB(idx: Int) -> Unit {
        if idx <= bN * bK - 1 {
          let (bias_x, bias_y): (Int, Int) = (idx / bK, idx - idx / bK * bK);
          sB[idx] = get_B(B, col_C + bias_x, block_k[0] + bias_y);
          // let _ = print_i(idx);
          // let _ = print_b(sB[idx]);
          // let _ = println();
          load_sB(idx + ctaM * ctaN)
        }
      };
      let _ = load_sB(linear_tid);
      block_k[0] = block_k[0] + bK;
      1
    } else {
      0
    }
  };
  micro_kernel
};

fn gemm_compute(A: Array[Int], B: Array[Int], C: Array[Int],
        bid_x: Int, bid_y: Int, tid_x: Int, tid_y: Int) -> (Unit) -> Int {
  let (bM, bN, bK): (Int, Int, Int) = (tile_m, tile_n, tile_k);
  let (ctaM, ctaN, _): (Int, Int, Int) = (thr_m, thr_n, 1);
  let (row_C, col_C) = (bid_x * bM, bid_y * bN);
  let sA = sA[bid_x][bid_y];
  let sB = sB[bid_x][bid_y];
  let sC = sC[bid_x][bid_y];
  let linear_tid = tid_x * thr_n + tid_y;

  let block_k: Array[Int] = Array::make(1, 0);
  fn micro_kernel(_) -> Int {
    if block_k[0] <= K - 1 {
      // compute
      // M
      fn comp_M(r: Int) -> Unit {
        if r <= bM - 1 {
          fn comp_N(c: Int) -> Unit {
            if c <= bN - 1 {
              fn comp_k(k_iter: Int) -> Unit {
                if k_iter <= bK - 1 {
                  let val = sC[r * bN + c] + 
                                get_sA(sA, r * bK + k_iter) * get_sB(sB, c * bK + k_iter);
                  sC[r * bN + c] = mat_mod(val);
                  comp_k(k_iter + 1)
                }
              };
              let _ = comp_k(0);
              comp_N(c + ctaN)
            }
          };
          let _ = comp_N(tid_y);
          comp_M(r + ctaM)
        }
      };
      let _ = comp_M(tid_x);
      block_k[0] = block_k[0] + bK;
      1
    } else {
      0
    }
  };
  micro_kernel
};

fn gemm_store(A: Array[Int], B: Array[Int], C: Array[Int],
        bid_x: Int, bid_y: Int, tid_x: Int, tid_y: Int) -> (Unit) -> Int {
  let (bM, bN, bK): (Int, Int, Int) = (tile_m, tile_n, tile_k);
  let (ctaM, ctaN, _): (Int, Int, Int) = (thr_m, thr_n, 1);
  let (row_C, col_C) = (bid_x * bM, bid_y * bN);
  let sA = sA[bid_x][bid_y];
  let sB = sB[bid_x][bid_y];
  let sC = sC[bid_x][bid_y];
  let linear_tid = tid_x * thr_n + tid_y;

  // ===== debug =====
  // let _ = print_b(bid_x);
  // let _ = print_b(bid_y);
  // let _ = print_t(tid_x);
  // let _ = print_t(tid_y);
  // let _ = print_r(row_C);
  // let _ = print_c(col_C);
  // let _ = println();
  // ==========

  let block_k: Array[Int] = Array::make(1, 0);
  fn micro_kernel(_) -> Int {
    if block_k[0] <= K - 1 {
      // store
      // M
      fn comp_M(r: Int) -> Unit {
        if r <= bM - 1 {
          fn comp_N(c: Int) -> Unit {
            if c <= bN - 1 {
              let _ = set_C(C, row_C + r, col_C + c, sC[r * bN + c]);
              comp_N(c + ctaN)
            }
          };
          let _ = comp_N(tid_y);
          comp_M(r + ctaM)
        }
      };
      let _ = comp_M(tid_x);
      // store
      block_k[0] = block_k[0] + bK;
      1
    } else {
      0
    }
  };
  micro_kernel
};

fn main {
  let (m, n, k): (Int, Int, Int) = (M, N, K);
  let A: Array[Int] = Array::make(m * k, 0); // row-major
  let B: Array[Int] = Array::make(n * k, 0); // col-major
  let C: Array[Int] = Array::make(m * n, 0); // row-major

  let val: Array[Int] = Array::make(1, 0);
  fn fill(size: Int, arr: Array[Int]) -> Unit {
    fn next(cur: Int) {
      if cur <= size - 1 {
        arr[cur] = mat_mod(val[0]);
        val[0] = val[0] + 1;
        next(cur + 1)
      }
    };
    next(0)
  };
  let _ = fill(m * k, A);
  let _ = fill(n * k, B);

  let (grid_m, grid_n): (Int, Int) = (m / tile_m, n / tile_n);
  let (block_m, block_n): (Int, Int) = (thr_m, thr_n);

  // === sA array initialization ===
  fn smem_init_0(gm: Int) {
    if gm <= grid_m - 1 {
      // gird_n
      fn smem_init_1(gn: Int) {
        if gn <= grid_n - 1 {
          // block_m
          sA[gm][gn] = Array::make(tile_m * tile_k, 0);
          sB[gm][gn] = Array::make(tile_n * tile_k, 0);
          sC[gm][gn] = Array::make(tile_m * tile_n, 0);
          smem_init_1(gn + 1)
        }
      };
      sA[gm] = Array::make(grid_n, Array::make(0, 0));
      sB[gm] = Array::make(grid_n, Array::make(0, 0));
      sC[gm] = Array::make(grid_n, Array::make(0, 0));
      let _ = smem_init_1(0);
      smem_init_0(gm + 1)
    }
  };
  let _ = smem_init_0(0);

  // === Kernel emit ===
  fn emitter_wrap(f: (Array[Int], Array[Int], Array[Int], Int, Int, Int, Int) -> (Unit) -> Int) -> (Unit) -> Int {
    fn f_template(_) -> Int {
      0
    };
    let funcs = Array::make(grid_m * grid_n * block_m * block_n, f_template);
    let idx = Array::make(1, 0);
    // gird_m
    fn emit_0(gm: Int) -> Unit {
      if gm <= grid_m - 1 {
        // gird_n
        fn emit_1(gn: Int) {
          if gn <= grid_n - 1 {
            // block_m
            fn emit_2(bm: Int) {
              if bm <= block_m - 1 {
                // block_n
                fn emit_3(bn: Int) {
                  if bn <= block_n - 1 {
                    funcs[idx[0]] = f(A, B, C, gm, gn, bm, bn);
                    idx[0] = idx[0] + 1;
                    emit_3(bn + 1)
                  }
                };
                let _ = emit_3(0);
                emit_2(bm + 1)
              }
            };
            let _ = emit_2(0);
            emit_1(gn + 1)
          }
        };
        let _ = emit_1(0);
        let _ = emit_0(gm + 1);
        ()
      }
    };
    let _ = emit_0(0);

    let result = Array::make(1, 1);
    fn run(_) -> Int {
      fn run_all(cur: Int) -> Unit {
        if cur <= idx[0] - 1 {
          let ok = funcs[cur](());
          result[0] = if (ok == 0) {
            0
          } else {
            result[0]
          };
          run_all(cur + 1)
        }
      };
      let _ = run_all(0);
      // let _ = print_array_1d(C, M * N);
      result[0]
    };
    run
  };
  
  let load = emitter_wrap(gemm_load);
  let compute = emitter_wrap(gemm_compute);
  let store = emitter_wrap(gemm_store);

  fn work() -> Unit {
    if (load(()) == 1) {
      let _ = assert(and(compute(()) == 1, store(()) == 1));
      work()
    } else {
      ()
    }
  };
  let _ = work();

  let _ = print_array_1d(C, M * N);
  let _ = println();

  ()
};
