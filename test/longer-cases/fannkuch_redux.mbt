fn gen_perm(i : Int, n : Int, arr : Array[Int]) -> Unit {
  if i + 1 <= n {
    arr[i] = i;
    gen_perm(i + 1, n, arr)
  }
};

fn fannkuch(n : Int) -> Int {
  let perm1 = Array::make(n, 0);
  let _ = gen_perm(0, n, perm1);
  let perm = Array::make(n, 0);
  let count = Array::make(n, 0);

  let r = Array::make(1, n);
  let flips = Array::make(1, 0);
  let nperm = Array::make(1, 0);
  let checksum = Array::make(1, 0);

  fn loop() -> Int {
    if 1 <= r[0] {
      fn loop1(r : Int) -> Int {
        if r == 1 {
          r
        } else {
          count[r - 1] = r;
          loop1(r - 1)
        }
      };

      r[0] = loop1(r[0]);

      fn loop2(i : Int) -> Int {
        if i + 1 <= n {
          perm[i] = perm1[i];
          loop2(i + 1)
        } else {
          i
        }
      };

      let i = loop2(0);

      fn loop3(f : Int, k : Int) -> Int {
        if k == 0 {
          f
        } else {
          fn loop4(i : Int) {
            if 2 * i + 1 <= k {
              let t = perm[i];
              perm[i] = perm[k - i];
              perm[k - i] = t;
              loop4(i + 1)
            } else {
              ()
            }
          };
          let _ = loop4(0);
          loop3(f + 1, perm[0])
        }
      };

      let f = loop3(0, perm[0]);
      let _ = if flips[0] + 1 <= f {
        flips[0] = f;
        ()
      };
      let _ = if nperm[0] == nperm[0] / 2 * 2 {
        checksum[0] = checksum[0] + f;
        ()
      } else {
        checksum[0] = checksum[0] - f;
        ()
      };

      fn loop4() -> (Bool, Int) {
        if r[0] == n {
          let _ = print_int(checksum[0]);
          let _ = print_endline();
          (true, flips[0])
        } else {
          let p0 = perm1[0];

          fn loop5(i : Int) {
            if i + 1 <= r[0] {
              let j = i + 1;
              perm1[i] = perm1[j];
              loop5(j)
            }
          };

          let _ = loop5(0);
          perm1[r[0]] = p0;
          count[r[0]] = count[r[0]] - 1;

          if 1 <= count[r[0]] {
            (false, 0)
          } else {
            r[0] = r[0] + 1;
            loop4()
          }
        }
      };

      let (flag, ans) = loop4();

      if flag {
        ans
      } else {
        nperm[0] = nperm[0] + 1;
        loop()
      }
    } else {
      flips[0]
    }
  };

  loop()
};

fn main {
  let n = 7;
  let ans = fannkuch(n);
  let _ = print_int(ans);
  ()
};