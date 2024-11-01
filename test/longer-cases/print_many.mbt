fn print_many(
  a0 : Int, 
  a1 : Int,
  a2 : Int,
  a3 : Int,
  a4 : Int,
  a5 : Int,
  a6 : Int,
  a7 : Int,
  a8 : Int,
  a9 : Int,
  a10 : Double,
  a11 : Int,
  a12 : Int,
  a13 : Int,
  a14 : Int,
  a15 : Int,
  a16 : Int,
  d0 : Double,
  d1 : Double,
  d2 : Double,
  d3 : Double,
  d4 : Double,
  d5 : Double,
  d6 : Double,
  d7 : Double,
  d8 : Double,
  d9 : Double
) -> Unit {
  let _ = print_int(a0);
  let _ = print_int(a1);
  let _ = print_int(a2);
  let _ = print_int(a3);
  let _ = print_int(a4);
  let _ = print_int(a5);
  let _ = print_int(a6);
  let _ = print_int(a7);
  let _ = print_int(a8);
  let _ = print_int(a9);
  let _ = print_int(truncate(a10));
  let _ = print_int(a11);
  let _ = print_int(a12);
  let _ = print_int(a13);
  let _ = print_int(a14);
  let _ = print_int(a15);
  let _ = print_int(a16);
  let _ = print_int(truncate(d0));
  let _ = print_int(truncate(d1));
  let _ = print_int(truncate(d2));
  let _ = print_int(truncate(d3));
  let _ = print_int(truncate(d4));
  let _ = print_int(truncate(d5));
  let _ = print_int(truncate(d6));
  let _ = print_int(truncate(d7));
  let _ = print_int(truncate(d8));
  let _ = print_int(truncate(d9));
  ()
};

fn main {
  let _ = print_many(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11.11, 12, 13, 14, 15, 16, 17, 0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0);
  ()
};