fn shiftl(x : Int, n : Int) -> Int {
  if n == 0 {
    x
  } else {
    shiftl(2 * x, n - 1)
  }
};

fn main {
  let w = 1000;
  let h = w;
  let iter = 50;
  let limit = 2.0;

  let bit_num = Array::make(1, 0);
  let byte_acc = Array::make(1, 0);

  fn loop1(y : Int) -> Unit {
    if y + 1 <= h {
      fn loop2(x : Int) -> Unit {
        if x + 1 <= w {
          let Zr = Array::make(1, 0.0);
          let Zi = Array::make(1, 0.0);
          let Tr = Array::make(1, 0.0);
          let Ti = Array::make(1, 0.0);
          let Cr = (2.0 * float_of_int(x) / float_of_int(w) - 1.5);
          let Ci = (2.0 * float_of_int(y) / float_of_int(h) - 1.0);

          fn loop3(i : Int) -> Unit {
            if i + 1 <= iter {
              if Tr[0] + Ti[0] <= limit * limit {
                Zi[0] = 2.0 * Zr[0] * Zi[0] + Ci;
                Zr[0] = Tr[0] - Ti[0] + Cr;
                Tr[0] = Zr[0] * Zr[0];
                Ti[0] = Zi[0] * Zi[0];
                loop3(i + 1)
              }
            }
          };

          let _ = loop3(0);
          byte_acc[0] = byte_acc[0] * 2;
          let _ = if Tr[0] + Ti[0] <= limit * limit {
            let _ = if byte_acc[0] == byte_acc[0] / 2 * 2 {
              byte_acc[0] = byte_acc[0] + 1;
              ()
            };
            ()
          };
          bit_num[0] = bit_num[0] + 1;

          let _ = if bit_num[0] == 8 {
            let _ = print_char(byte_acc[0]);
            byte_acc[0] = 0;
            bit_num[0] = 0;
            ()
          } else {
            if x + 1 == w {
              let p = 8 - (w - w / 8 * 8);
              let _ = print_char(shiftl(byte_acc[0], p));
              byte_acc[0] = 0;
              bit_num[0] = 0;
              ()
            }
          };

          loop2(x + 1)
        }
      };

      let _ = loop2(0);
      loop1(y + 1)
    }
  };

  let _ = print_char(80);
  let _ = print_char(52);
  let _ = print_endline();
  let _ = print_int(w);
  let _ = print_char(32);
  let _ = print_int(h);
  let _ = print_endline();

  let _ = loop1(0);
  ()
};