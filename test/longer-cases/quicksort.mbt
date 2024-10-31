


fn rand(x : Int) -> Int{
  x * 2
};

fn mod(x : Int, y: Int) -> Int{
  x - x / y * y
};

fn print_array(n : Int, arr : Array[Int]) -> Unit {
  fn print_col(j : Int) -> Unit {
    if j + 1 <= n {
      let _ = print_int(arr[j]);
      let _ = print_char(32);
      print_col(j + 1)
    }
    else{
      ()
    }
  };
  let _ = print_col(0);
  let _ = print_char(10);
  ()
};

fn quick_sort(low: Int, high: Int,arr : Array[Int]) -> Unit{
  if low + 1 <= high{
    fn partition(l: Int,r: Int) -> Int{
      let pivot = arr[r];
      let i = Array::make(1,l - 1);
      fn loop_1(j : Int) -> Unit{
        if j + 1 <= r {
          if arr[j] + 1 <= pivot {
            i[0] = i[0] + 1;
            let tmp = arr[i[0]];
            arr[i[0]] = arr[j];
            arr[j] = tmp;
            loop_1(j + 1)
          }
          else{
            loop_1(j + 1)
          }
        }
        else{
          ()
        }
      };
      let _ = loop_1(l);
      let tmp = arr[i[0] + 1];
      arr[i[0] + 1] = arr[r];
      arr[r] = tmp;
      i[0] + 1
    };
    let pivotIndex = partition(low, high);
    let _ = quick_sort(low,pivotIndex - 1,arr);
    let _ = quick_sort(pivotIndex + 1, high,arr);
    ()
  }
  else{
    ()
  }
};

fn main{
  let n = 16;
  let arr = Array::make(n, 0);
  let seed = Array::make(1,1);
  fn init(x : Int)->Unit{
    if 0 <= x{
      arr[x] = mod(rand(seed[0]),1000007);
      seed[0] = arr[x];
      init(x - 1)
    }
    else{
      ()
    }
  };
  let _ = init(n - 1);
  let _ = print_array(n,arr);
  let _ = quick_sort(0,n-1,arr);
  let _ = print_array(n,arr);
  ()
};