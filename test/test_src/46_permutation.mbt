let n: Int = 5;
let visit: Array[Int] = Array::make(7, 0);
let arr: Array[Int] = Array::make(7, 0);

fn print_arr() -> Unit {
    fn aux(i: Int) -> Unit {
        if i == n {
            ()
        } else {
            let _ = print_int(arr[i]);
            aux(i + 1)
        }
    };
    let _ = aux(0);
    let _ = print_endline();
    ()
};

fn permutation(ix: Int) -> Unit {
    if ix == n {
        print_arr()
    } else {
        fn aux(i: Int) -> Unit {
            if i == n {
                ()
            } else {
                let _ = if visit[i] == 0 {
                    visit[i] = 1;
                    arr[ix] = i;
                    let _ = permutation(ix + 1);
                    visit[i] = 0;
                    ()
                };
                aux(i + 1)
            }
        };
        aux(0)
    }
};

fn main {
    permutation(0)
};