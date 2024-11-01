

let global_counter: Int = 0;


// fn global_counter() -> Int{
//   2
// };


fn create_incrementer() -> (Int) -> Int {
  let y = 100;
  fn increment(x : Int) ->Int {
      fn deep(z : Int) -> Int{
        fn d2(x : Int) -> Int{
          y + global_counter
        };
        d2(z)
      };
      deep(y)
  };
  increment
  // increment
};

fn init {
  if true {
    ()
  } else {
    ()
  }
};

fn main {
  let incrementer = create_incrementer();
  let _ = print_int(incrementer(global_counter)); 
  let _ = print_int(incrementer(incrementer(global_counter))); 
  let _ = print_int(incrementer(incrementer(incrementer(global_counter))));
  ()
};
