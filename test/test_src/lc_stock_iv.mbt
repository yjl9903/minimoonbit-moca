fn max(a: Int, b: Int) -> Int {
  if b <= a {
    a
  } else {
    b
  }
};

fn max_profit(k: Int, prices: Array[Int], prices_size: Int) -> Int {
    let dp_len = 2 * k;
    let dp = Array::make(dp_len, 0);

    fn aux1(i: Int) -> Unit {
        if i == dp_len {
            ()
        } else {
            dp[i] = -(prices[0]);
            aux1(i + 2)
        }
    };
    let _ = aux1(0);

    fn aux2(i: Int) -> Unit {
        if i == prices_size {
            ()
        } else {
            dp[0] = max(dp[0], -(prices[i]));
            dp[1] = max(dp[1], dp[0] + prices[i]);
            fn aux3(j: Int) -> Unit {
                if j == dp_len {
                    ()
                } else {
                    dp[j] = max(dp[j], dp[j - 1] - prices[i]);
                    dp[j + 1] = max(dp[j + 1], dp[j] + prices[i]);
                    aux3(j + 2)
                }
            };
            let _ = aux3(2);
            aux2(i + 1)
        }
    };
    let _ = aux2(1);

    dp[dp_len - 1]
};

fn main {
//   let _ = print_int(max(1, 2));
  let prices: Array[Int] = Array::make(6, 3);
  prices[0] = 3;
  prices[1] = 2;
  prices[2] = 6;
  prices[3] = 5;
  prices[4] = 0;
  prices[5] = 3;
  let _ = print_int(max_profit(2, prices, 6));
  ()
};