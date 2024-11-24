fn print_arr(arr: Array[Int], n: Int) -> Unit {
    fn aux(i: Int) -> Unit {
        if i == n {
            ()
        } else {
            let _ = print_int(arr[i]);
            let _ = print_endline();
            aux(i + 1)
        }
    };
    let _ = aux(0);
    let _ = print_endline();
    ()
};

fn pascal_triangle(max_n: Int, i: Int, last_row: Array[Int]) -> Unit {
    if i == max_n {
        ()
    } else {
        let new_row = Array::make(i + 1, 0);
        fn aux(j: Int) -> Unit {
            if j == i + 1 {
                ()
            } else {
                let left = if j == 0 {
                    0
                } else {
                    last_row[j - 1]
                };
                let right = if j == i {
                    0
                } else {
                    last_row[j]
                };
                new_row[j] = left + right;
                aux(j + 1)
            }
        };
        let _ = aux(0);
        let _ = print_arr(new_row, i + 1);
        let _ = pascal_triangle(max_n, i + 1, new_row);
        ()
    }
};

fn main {
    let max_n = 10;
    let first_row = Array::make(1, 1);
    let _ = print_arr(first_row, 1);
    let _ = pascal_triangle(max_n, 1, first_row);
    ()
};