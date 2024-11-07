import itertools
import os
import subprocess

# 源代码字符串，使用 %s 作为占位符
source = """
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
  let n = 8;
  let arr = Array::make(n, 0);
  let seed = Array::make(1,1);
  arr[0] = %s;
  arr[1] = %s;
  arr[2] = %s;
  arr[3] = %s;
  arr[4] = %s;
  arr[5] = %s;
  arr[6] = %s;
  arr[7] = %s;
  // fn init(x : Int)->Unit{
  //   if 0 <= x{
  //     arr[x] = mod(rand(seed[0]),1000007);
  //     seed[0] = arr[x];
  //     init(x - 1)
  //   }
  //   else{
  //     ()
  //   }
  // };
  // let _ = init(n - 1);
  let _ = print_array(n,arr);
  let _ = quick_sort(0,n-1,arr);
  let _ = print_array(n,arr);
  ()
};
"""

# 替换后文件路径
output_file_path = "test/scripts/temp/quicksort.mbt"

# 执行的命令
command = ["./run_riscv.sh", output_file_path]

# 生成 8^8 的所有排列
all_combinations = itertools.product(range(8), repeat=8)

# 替换占位符并执行命令
for idx, combination in enumerate(all_combinations):
    # 使用 % 替换生成代码中的 %s 占位符
    modified_code = source % combination
    if not os.path.exists('./test/scripts/temp'):
        os.mkdir('./test/scripts/temp')
        
    # 将新代码写入覆盖 test/longer-cases/quicksort.mbt
    with open(output_file_path, "w") as file:
        file.write(modified_code)

    # 执行命令
    try:
        result = subprocess.run(command, check=True, capture_output=True, text=True)
        print(f"Combination {idx + 1}: {combination}")
        print(result.stdout)
    except subprocess.CalledProcessError as e:
        print(f"Error for combination {idx + 1}: {combination}")
        print(e.stderr)
