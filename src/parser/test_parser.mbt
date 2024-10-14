pub fn parse_minimoonbit_file(path : String) -> Syntax! {
  assert_true!(@fs.path_exists(~path))
  let input : String = @fs.read_file_to_string!(~path)
  let context = @lex.Context::new(input)
  let ok = @lex.lex(context)
  let state = State::new(context.tokens)
  let mut result : Syntax = Syntax::Unit
  assert_eq!(ok, 0)
  try {
    result = state.parse!(prog)
  } catch {
    ParseError(e) => println(e)
  }
  debug(result.to_string())
  assert_eq!(state.empty(), true)
  return result
}

test "spill3" {
  inspect!(
    parse_minimoonbit_file!("test/test_src/spill3.mbt"),
    content="LetRec({name: (\"f\", Fun([], Int)), args: [(\"x0\", Int)], body: Let((\"x1\", Var({val: None})), Prim(Var(\"x0\"), Int(1), Add, kind=None), Let((\"x2\", Var({val: None})), Prim(Var(\"x1\"), Int(1), Add, kind=None), Let((\"x3\", Var({val: None})), Prim(Var(\"x2\"), Int(1), Add, kind=None), Let((\"x4\", Var({val: None})), Prim(Var(\"x3\"), Int(1), Add, kind=None), Let((\"x5\", Var({val: None})), Prim(Var(\"x4\"), Int(1), Add, kind=None), Let((\"x6\", Var({val: None})), Prim(Var(\"x5\"), Int(1), Add, kind=None), Let((\"x7\", Var({val: None})), Prim(Var(\"x6\"), Int(1), Add, kind=None), Let((\"x8\", Var({val: None})), Prim(Var(\"x7\"), Int(1), Add, kind=None), Let((\"x9\", Var({val: None})), Prim(Var(\"x8\"), Int(1), Add, kind=None), Let((\"x10\", Var({val: None})), Prim(Var(\"x9\"), Int(1), Add, kind=None), Let((\"x11\", Var({val: None})), Prim(Var(\"x10\"), Int(1), Add, kind=None), Let((\"x12\", Var({val: None})), Prim(Var(\"x11\"), Int(1), Add, kind=None), Let((\"x13\", Var({val: None})), Prim(Var(\"x12\"), Int(1), Add, kind=None), Let((\"x14\", Var({val: None})), Prim(Var(\"x13\"), Int(1), Add, kind=None), Let((\"x15\", Var({val: None})), Prim(Var(\"x14\"), Int(1), Add, kind=None), Let((\"x16\", Var({val: None})), Prim(Var(\"x15\"), Int(1), Add, kind=None), Let((\"x17\", Var({val: None})), Prim(Var(\"x16\"), Int(1), Add, kind=None), Let((\"x18\", Var({val: None})), Prim(Var(\"x17\"), Int(1), Add, kind=None), Let((\"x19\", Var({val: None})), Prim(Var(\"x18\"), Var(\"x1\"), Add, kind=None), Let((\"x20\", Var({val: None})), Prim(Var(\"x19\"), Var(\"x2\"), Add, kind=None), Let((\"x21\", Var({val: None})), Prim(Var(\"x20\"), Var(\"x3\"), Add, kind=None), Let((\"x22\", Var({val: None})), Prim(Var(\"x21\"), Var(\"x4\"), Add, kind=None), Let((\"x23\", Var({val: None})), Prim(Var(\"x22\"), Var(\"x5\"), Add, kind=None), Let((\"x24\", Var({val: None})), Prim(Var(\"x23\"), Var(\"x6\"), Add, kind=None), Let((\"x25\", Var({val: None})), Prim(Var(\"x24\"), Var(\"x7\"), Add, kind=None), Let((\"x26\", Var({val: None})), Prim(Var(\"x25\"), Var(\"x8\"), Add, kind=None), Let((\"x27\", Var({val: None})), Prim(Var(\"x26\"), Var(\"x9\"), Add, kind=None), Let((\"x28\", Var({val: None})), Prim(Var(\"x27\"), Var(\"x10\"), Add, kind=None), Let((\"x29\", Var({val: None})), Prim(Var(\"x28\"), Var(\"x11\"), Add, kind=None), Let((\"x30\", Var({val: None})), Prim(Var(\"x29\"), Var(\"x12\"), Add, kind=None), Let((\"x31\", Var({val: None})), Prim(Var(\"x30\"), Var(\"x13\"), Add, kind=None), Let((\"x32\", Var({val: None})), Prim(Var(\"x31\"), Var(\"x14\"), Add, kind=None), Let((\"x33\", Var({val: None})), Prim(Var(\"x32\"), Var(\"x15\"), Add, kind=None), Let((\"x34\", Var({val: None})), Prim(Var(\"x33\"), Var(\"x16\"), Add, kind=None), Let((\"x35\", Var({val: None})), Prim(Var(\"x34\"), Var(\"x17\"), Add, kind=None), Let((\"x36\", Var({val: None})), Prim(Var(\"x35\"), Var(\"x0\"), Add, kind=None), Prim(Var(\"x1\"), Prim(Var(\"x2\"), Prim(Var(\"x3\"), Prim(Var(\"x4\"), Prim(Var(\"x5\"), Prim(Var(\"x6\"), Prim(Var(\"x7\"), Prim(Var(\"x8\"), Prim(Var(\"x9\"), Prim(Var(\"x10\"), Prim(Var(\"x11\"), Prim(Var(\"x12\"), Prim(Var(\"x13\"), Prim(Var(\"x14\"), Prim(Var(\"x15\"), Prim(Var(\"x16\"), Prim(Var(\"x17\"), Prim(Var(\"x18\"), Prim(Var(\"x19\"), Prim(Var(\"x20\"), Prim(Var(\"x21\"), Prim(Var(\"x22\"), Prim(Var(\"x23\"), Prim(Var(\"x24\"), Prim(Var(\"x25\"), Prim(Var(\"x26\"), Prim(Var(\"x27\"), Prim(Var(\"x28\"), Prim(Var(\"x29\"), Prim(Var(\"x30\"), Prim(Var(\"x31\"), Prim(Var(\"x32\"), Prim(Var(\"x33\"), Prim(Var(\"x34\"), Prim(Var(\"x35\"), Prim(Var(\"x36\"), Var(\"x0\"), Add, kind=None), Add, kind=None), Add, kind=None), Add, kind=None), Add, kind=None), Add, kind=None), Add, kind=None), Add, kind=None), Add, kind=None), Add, kind=None), Add, kind=None), Add, kind=None), Add, kind=None), Add, kind=None), Add, kind=None), Add, kind=None), Add, kind=None), Add, kind=None), Add, kind=None), Add, kind=None), Add, kind=None), Add, kind=None), Add, kind=None), Add, kind=None), Add, kind=None), Add, kind=None), Add, kind=None), Add, kind=None), Add, kind=None), Add, kind=None), Add, kind=None), Add, kind=None), Add, kind=None), Add, kind=None), Add, kind=None), Add, kind=None)))))))))))))))))))))))))))))))))))))}, LetRec({name: (\"main\", Fun([], Unit)), args: [], body: App(Var(\"print_int\"), [App(Var(\"f\"), [Int(0)])])}, Unit))",
  )
}

test "ack" {
  inspect!(
    parse_minimoonbit_file!("test/test_src/ack.mbt"),
    content="LetRec({name: (\"ack\", Fun([], Int)), args: [(\"x\", Int), (\"y\", Int)], body: If(LE(Var(\"x\"), Int(0)), Prim(Var(\"y\"), Int(1), Add, kind=None), If(LE(Var(\"y\"), Int(0)), App(Var(\"ack\"), [Prim(Var(\"x\"), Int(1), Sub, kind=None), Int(1)]), App(Var(\"ack\"), [Prim(Var(\"x\"), Int(1), Sub, kind=None), App(Var(\"ack\"), [Var(\"x\"), Prim(Var(\"y\"), Int(1), Sub, kind=None)])])))}, LetRec({name: (\"main\", Fun([], Unit)), args: [], body: App(Var(\"print_int\"), [App(Var(\"ack\"), [Int(3), Int(8)])])}, Unit))",
  )
}

test "adder2" {
  inspect!(
    parse_minimoonbit_file!("test/test_src/adder2.mbt"),
    content="LetRec({name: (\"make_adder\", Fun([Int], Int)), args: [(\"x\", Int)], body: LetRec({name: (\"adder\", Fun([], Int)), args: [(\"y\", Int)], body: Prim(Var(\"x\"), Var(\"y\"), Add, kind=None)}, Var(\"adder\"))}, LetRec({name: (\"main\", Fun([], Unit)), args: [], body: Let((\"add2\", Var({val: None})), App(Var(\"make_adder\"), [Int(2)]), Let((\"add3\", Var({val: None})), App(Var(\"make_adder\"), [Int(3)]), App(Var(\"print_int\"), [Prim(App(Var(\"add2\"), [Int(10)]), App(Var(\"add3\"), [Int(20)]), Add, kind=None)])))}, Unit))",
  )
}

test {
  inspect!(
    parse_minimoonbit_file!("test/test_src/cls-bug.mbt"),
    content="LetRec({name: (\"f\", Fun([], Int)), args: [(\"x\", Int)], body: Prim(Var(\"x\"), Int(123), Add, kind=None)}, LetRec({name: (\"g\", Fun([Int], Int)), args: [(\"y\", Int)], body: Var(\"f\")}, LetRec({name: (\"main\", Fun([], Unit)), args: [], body: App(Var(\"print_int\"), [App(App(Var(\"g\"), [Int(456)]), [Int(789)])])}, Unit)))",
  )
}

test {
  inspect!(
    parse_minimoonbit_file!("test/test_src/matmul-flat.mbt"),
    content="LetRec({name: (\"loop3\", Fun([], Unit)), args: [(\"i\", Int), (\"j\", Int), (\"k\", Int), (\"a\", Array(Array(Double))), (\"b\", Array(Array(Double))), (\"c\", Array(Array(Double)))], body: If(LE(Int(0), Var(\"k\")), Let((\"_\", Unit), Put(Get(Var(\"c\"), Var(\"i\")), Var(\"j\"), Prim(Get(Get(Var(\"c\"), Var(\"i\")), Var(\"j\")), Prim(Get(Get(Var(\"a\"), Var(\"i\")), Var(\"k\")), Get(Get(Var(\"b\"), Var(\"k\")), Var(\"j\")), Mul, kind=None), Add, kind=None)), App(Var(\"loop3\"), [Var(\"i\"), Var(\"j\"), Prim(Var(\"k\"), Int(1), Sub, kind=None), Var(\"a\"), Var(\"b\"), Var(\"c\")])), Unit)}, LetRec({name: (\"loop2\", Fun([], Unit)), args: [(\"i\", Int), (\"m\", Int), (\"j\", Int), (\"a\", Array(Array(Double))), (\"b\", Array(Array(Double))), (\"c\", Array(Array(Double)))], body: If(LE(Int(0), Var(\"j\")), Let((\"_\", Var({val: None})), App(Var(\"loop3\"), [Var(\"i\"), Var(\"j\"), Prim(Var(\"m\"), Int(1), Sub, kind=None), Var(\"a\"), Var(\"b\"), Var(\"c\")]), App(Var(\"loop2\"), [Var(\"i\"), Var(\"m\"), Prim(Var(\"j\"), Int(1), Sub, kind=None), Var(\"a\"), Var(\"b\"), Var(\"c\")])), Unit)}, LetRec({name: (\"loop1\", Fun([], Unit)), args: [(\"i\", Int), (\"m\", Int), (\"n\", Int), (\"a\", Array(Array(Double))), (\"b\", Array(Array(Double))), (\"c\", Array(Array(Double)))], body: If(LE(Int(0), Var(\"i\")), Let((\"_\", Var({val: None})), App(Var(\"loop2\"), [Var(\"i\"), Var(\"m\"), Prim(Var(\"n\"), Int(1), Sub, kind=None), Var(\"a\"), Var(\"b\"), Var(\"c\")]), App(Var(\"loop1\"), [Prim(Var(\"i\"), Int(1), Sub, kind=None), Var(\"m\"), Var(\"n\"), Var(\"a\"), Var(\"b\"), Var(\"c\")])), Unit)}, LetRec({name: (\"mul\", Fun([], Unit)), args: [(\"l\", Int), (\"m\", Int), (\"n\", Int), (\"a\", Array(Array(Double))), (\"b\", Array(Array(Double))), (\"c\", Array(Array(Double)))], body: Let((\"_\", Var({val: None})), App(Var(\"loop1\"), [Prim(Var(\"l\"), Int(1), Sub, kind=None), Var(\"m\"), Var(\"n\"), Var(\"a\"), Var(\"b\"), Var(\"c\")]), Unit)}, LetRec({name: (\"main\", Fun([], Unit)), args: [], body: Let((\"dummy\", Var({val: None})), Array(Int(0), Double(0)), LetRec({name: (\"init_arr\", Fun([], Unit)), args: [(\"i\", Int), (\"n\", Int), (\"mat\", Array(Array(Double)))], body: If(LE(Int(0), Var(\"i\")), Let((\"_\", Unit), Put(Var(\"mat\"), Var(\"i\"), Array(Var(\"n\"), Double(0))), App(Var(\"init_arr\"), [Prim(Var(\"i\"), Int(1), Sub, kind=None), Var(\"n\"), Var(\"mat\")])), Unit)}, LetRec({name: (\"make_arr\", Fun([], Array(Array(Double)))), args: [(\"m\", Int), (\"n\", Int), (\"dummy\", Array(Double))], body: Let((\"mat\", Var({val: None})), Array(Var(\"m\"), Var(\"dummy\")), Let((\"_\", Var({val: None})), App(Var(\"init_arr\"), [Prim(Var(\"m\"), Int(1), Sub, kind=None), Var(\"n\"), Var(\"mat\")]), Var(\"mat\")))}, Let((\"a\", Var({val: None})), App(Var(\"make_arr\"), [Int(2), Int(3), Var(\"dummy\")]), Let((\"b\", Var({val: None})), App(Var(\"make_arr\"), [Int(3), Int(2), Var(\"dummy\")]), Let((\"c\", Var({val: None})), App(Var(\"make_arr\"), [Int(2), Int(2), Var(\"dummy\")]), Let((\"_\", Unit), Put(Get(Var(\"a\"), Int(0)), Int(0), Double(1)), Let((\"_\", Unit), Put(Get(Var(\"a\"), Int(0)), Int(1), Double(2)), Let((\"_\", Unit), Put(Get(Var(\"a\"), Int(0)), Int(2), Double(3)), Let((\"_\", Unit), Put(Get(Var(\"a\"), Int(1)), Int(0), Double(4)), Let((\"_\", Unit), Put(Get(Var(\"a\"), Int(1)), Int(1), Double(5)), Let((\"_\", Unit), Put(Get(Var(\"a\"), Int(1)), Int(2), Double(6)), Let((\"_\", Unit), Put(Get(Var(\"b\"), Int(0)), Int(0), Double(7)), Let((\"_\", Unit), Put(Get(Var(\"b\"), Int(0)), Int(1), Double(8)), Let((\"_\", Unit), Put(Get(Var(\"b\"), Int(1)), Int(0), Double(9)), Let((\"_\", Unit), Put(Get(Var(\"b\"), Int(1)), Int(1), Double(10)), Let((\"_\", Unit), Put(Get(Var(\"b\"), Int(2)), Int(0), Double(11)), Let((\"_\", Unit), Put(Get(Var(\"b\"), Int(2)), Int(1), Double(12)), Let((\"_\", Var({val: None})), App(Var(\"mul\"), [Int(2), Int(3), Int(2), Var(\"a\"), Var(\"b\"), Var(\"c\")]), Let((\"_\", Var({val: None})), App(Var(\"print_int\"), [App(Var(\"truncate\"), [Get(Get(Var(\"c\"), Int(0)), Int(0))])]), Let((\"_\", Var({val: None})), App(Var(\"print_endline\"), []), Let((\"_\", Var({val: None})), App(Var(\"print_int\"), [App(Var(\"truncate\"), [Get(Get(Var(\"c\"), Int(0)), Int(1))])]), Let((\"_\", Var({val: None})), App(Var(\"print_endline\"), []), Let((\"_\", Var({val: None})), App(Var(\"print_int\"), [App(Var(\"truncate\"), [Get(Get(Var(\"c\"), Int(1)), Int(0))])]), Let((\"_\", Var({val: None})), App(Var(\"print_endline\"), []), Let((\"_\", Var({val: None})), App(Var(\"print_int\"), [App(Var(\"truncate\"), [Get(Get(Var(\"c\"), Int(1)), Int(1))])]), Unit))))))))))))))))))))))))))}, Unit)))))",
  )
}

test {
  inspect!(
    parse_minimoonbit_file!("test/test_src/matmul.mbt"),
    content="LetRec({name: (\"matmul\", Fun([], Unit)), args: [(\"l\", Int), (\"m\", Int), (\"n\", Int), (\"a\", Array(Array(Double))), (\"b\", Array(Array(Double))), (\"c\", Array(Array(Double)))], body: LetRec({name: (\"loop1\", Fun([], Unit)), args: [(\"i\", Int)], body: If(LE(Int(0), Var(\"i\")), LetRec({name: (\"loop2\", Fun([], Unit)), args: [(\"j\", Int)], body: If(LE(Int(0), Var(\"j\")), LetRec({name: (\"loop3\", Fun([], Unit)), args: [(\"k\", Int)], body: If(LE(Int(0), Var(\"k\")), Let((\"_\", Unit), Put(Get(Var(\"c\"), Var(\"i\")), Var(\"j\"), Prim(Get(Get(Var(\"c\"), Var(\"i\")), Var(\"j\")), Prim(Get(Get(Var(\"a\"), Var(\"i\")), Var(\"k\")), Get(Get(Var(\"b\"), Var(\"k\")), Var(\"j\")), Mul, kind=None), Add, kind=None)), App(Var(\"loop3\"), [Prim(Var(\"k\"), Int(1), Sub, kind=None)])), Unit)}, Let((\"_\", Var({val: None})), App(Var(\"loop3\"), [Prim(Var(\"m\"), Int(1), Sub, kind=None)]), App(Var(\"loop2\"), [Prim(Var(\"j\"), Int(1), Sub, kind=None)]))), Unit)}, Let((\"_\", Var({val: None})), App(Var(\"loop2\"), [Prim(Var(\"n\"), Int(1), Sub, kind=None)]), App(Var(\"loop1\"), [Prim(Var(\"i\"), Int(1), Sub, kind=None)]))), Unit)}, App(Var(\"loop1\"), [Prim(Var(\"l\"), Int(1), Sub, kind=None)]))}, LetRec({name: (\"main\", Fun([], Unit)), args: [], body: Let((\"dummy\", Var({val: None})), Array(Int(0), Double(0)), LetRec({name: (\"gen_arr\", Fun([], Array(Array(Double)))), args: [(\"m\", Int), (\"n\", Int)], body: Let((\"mat\", Var({val: None})), Array(Var(\"m\"), Var(\"dummy\")), LetRec({name: (\"init_arr\", Fun([], Unit)), args: [(\"i\", Int)], body: If(LE(Int(0), Var(\"i\")), Let((\"_\", Unit), Put(Var(\"mat\"), Var(\"i\"), Array(Var(\"n\"), Double(0))), App(Var(\"init_arr\"), [Prim(Var(\"i\"), Int(1), Sub, kind=None)])), Unit)}, Let((\"_\", Var({val: None})), App(Var(\"init_arr\"), [Prim(Var(\"m\"), Int(1), Sub, kind=None)]), Var(\"mat\"))))}, Let((\"a\", Var({val: None})), App(Var(\"gen_arr\"), [Int(2), Int(3)]), Let((\"b\", Var({val: None})), App(Var(\"gen_arr\"), [Int(3), Int(2)]), Let((\"c\", Var({val: None})), App(Var(\"gen_arr\"), [Int(2), Int(2)]), Let((\"_\", Unit), Put(Get(Var(\"a\"), Int(0)), Int(0), Double(1)), Let((\"_\", Unit), Put(Get(Var(\"a\"), Int(0)), Int(1), Double(2)), Let((\"_\", Unit), Put(Get(Var(\"a\"), Int(0)), Int(2), Double(3)), Let((\"_\", Unit), Put(Get(Var(\"a\"), Int(1)), Int(0), Double(4)), Let((\"_\", Unit), Put(Get(Var(\"a\"), Int(1)), Int(1), Double(5)), Let((\"_\", Unit), Put(Get(Var(\"a\"), Int(1)), Int(2), Double(6)), Let((\"_\", Unit), Put(Get(Var(\"b\"), Int(0)), Int(0), Double(7)), Let((\"_\", Unit), Put(Get(Var(\"b\"), Int(0)), Int(1), Double(8)), Let((\"_\", Unit), Put(Get(Var(\"b\"), Int(1)), Int(0), Double(9)), Let((\"_\", Unit), Put(Get(Var(\"b\"), Int(1)), Int(1), Double(10)), Let((\"_\", Unit), Put(Get(Var(\"b\"), Int(2)), Int(0), Double(11)), Let((\"_\", Unit), Put(Get(Var(\"b\"), Int(2)), Int(1), Double(12)), Let((\"_\", Var({val: None})), App(Var(\"matmul\"), [Int(2), Int(3), Int(2), Var(\"a\"), Var(\"b\"), Var(\"c\")]), Let((\"_\", Var({val: None})), App(Var(\"print_int\"), [App(Var(\"truncate\"), [Get(Get(Var(\"c\"), Int(0)), Int(0))])]), Let((\"_\", Var({val: None})), App(Var(\"print_endline\"), []), Let((\"_\", Var({val: None})), App(Var(\"print_int\"), [App(Var(\"truncate\"), [Get(Get(Var(\"c\"), Int(0)), Int(1))])]), Let((\"_\", Var({val: None})), App(Var(\"print_endline\"), []), Let((\"_\", Var({val: None})), App(Var(\"print_int\"), [App(Var(\"truncate\"), [Get(Get(Var(\"c\"), Int(1)), Int(0))])]), Let((\"_\", Var({val: None})), App(Var(\"print_endline\"), []), Let((\"_\", Var({val: None})), App(Var(\"print_int\"), [App(Var(\"truncate\"), [Get(Get(Var(\"c\"), Int(1)), Int(1))])]), Unit)))))))))))))))))))))))))}, Unit))",
  )
}

test {
  inspect!(
    parse_minimoonbit_file!("test/test_src/join-stack3.mbt"),
    content="LetRec({name: (\"f\", Fun([], Int)), args: [(\"u\", Unit)], body: Int(123)}, LetRec({name: (\"g\", Fun([], Int)), args: [(\"u\", Unit)], body: Int(456)}, LetRec({name: (\"h\", Fun([], Int)), args: [(\"u\", Unit)], body: Int(789)}, LetRec({name: (\"main\", Fun([], Unit)), args: [], body: Let((\"x\", Var({val: None})), App(Var(\"f\"), [Unit]), App(Var(\"print_int\"), [Prim(If(LE(Var(\"x\"), Int(0)), App(Var(\"g\"), [Unit]), App(Var(\"h\"), [Unit])), Var(\"x\"), Add, kind=None)]))}, Unit))))",
  )
}

test {
  inspect!(
    parse_minimoonbit_file!("test/test_src/cls-reg-bug.mbt"),
    content=
      #|LetRec({name: ("h", Fun([], Int)), args: [("p", Tuple([Int, Int, Int, Int, Int, Int, Int, Int, Int, Int]))], body: LetTuple([("v1", Var({val: None})), ("v2", Var({val: None})), ("v3", Var({val: None})), ("v4", Var({val: None})), ("v5", Var({val: None})), ("v6", Var({val: None})), ("v7", Var({val: None})), ("v8", Var({val: None})), ("v9", Var({val: None})), ("v10", Var({val: None}))], Var("p"), LetRec({name: ("g", Fun([], Int)), args: [("z", Int)], body: Let(("r", Var({val: None})), Prim(Var("v1"), Prim(Var("v2"), Prim(Var("v3"), Prim(Var("v4"), Prim(Var("v5"), Prim(Var("v6"), Prim(Var("v7"), Prim(Var("v8"), Prim(Var("v9"), Var("v10"), Add, kind=None), Add, kind=None), Add, kind=None), Add, kind=None), Add, kind=None), Add, kind=None), Add, kind=None), Add, kind=None), Add, kind=None), If(Not(LE(Var("z"), Int(0))), Var("r"), App(Var("g"), [Neg(Var("z"), kind=None)])))}, App(Var("g"), [Int(1)])))}, LetRec({name: ("main", Fun([], Unit)), args: [], body: Let(("t1", Var({val: None})), App(Var("print_int"), [App(Var("h"), [Tuple([Int(1), Int(2), Int(3), Int(4), Int(5), Int(6), Int(7), Int(8), Int(9), Int(10)])])]), Unit)}, Unit))
    ,
  )
}

test {
  inspect!(
    parse_minimoonbit_file!("test/test_src/float.mbt"),
    content=
      #|LetRec({name: ("main", Fun([], Unit)), args: [], body: App(Var("print_int"), [App(Var("int_of_float"), [Prim(Prim(App(Var("sin"), [App(Var("cos"), [App(Var("sqrt"), [App(Var("abs_float"), [Neg(Double(12.3), kind=None)])])])]), Prim(Double(4.5), Prim(Double(6.7), Prim(Double(8.9), Double(1.23456789), Div, kind=None), Mul, kind=None), Sub, kind=None), Add, kind=None), App(Var("float_of_int"), [Int(1000000)]), Mul, kind=None)])])}, Unit)
    ,
  )
}

test {
  inspect!(
    parse_minimoonbit_file!("test/test_src/inprod.mbt"),
    content=
      #|LetRec({name: ("getx", Fun([], Double)), args: [("v", Tuple([Double, Double, Double]))], body: LetTuple([("x", Var({val: None})), ("_", Var({val: None})), ("_", Var({val: None}))], Var("v"), Var("x"))}, LetRec({name: ("gety", Fun([], Double)), args: [("v", Tuple([Double, Double, Double]))], body: LetTuple([("_", Var({val: None})), ("y", Var({val: None})), ("_", Var({val: None}))], Var("v"), Var("y"))}, LetRec({name: ("getz", Fun([], Double)), args: [("v", Tuple([Double, Double, Double]))], body: LetTuple([("_", Var({val: None})), ("_", Var({val: None})), ("z", Var({val: None}))], Var("v"), Var("z"))}, LetRec({name: ("inprod", Fun([], Double)), args: [("v1", Tuple([Double, Double, Double])), ("v2", Tuple([Double, Double, Double]))], body: Prim(Prim(App(Var("getx"), [Var("v1")]), App(Var("getx"), [Var("v2")]), Mul, kind=None), Prim(Prim(App(Var("gety"), [Var("v1")]), App(Var("gety"), [Var("v2")]), Mul, kind=None), Prim(App(Var("getz"), [Var("v1")]), App(Var("getz"), [Var("v2")]), Mul, kind=None), Add, kind=None), Add, kind=None)}, LetRec({name: ("main", Fun([], Unit)), args: [], body: App(Var("print_int"), [App(Var("truncate"), [Prim(Double(1000000), App(Var("inprod"), [Tuple([Double(1), Double(2), Double(3)]), Tuple([Double(4), Double(5), Double(6)])]), Mul, kind=None)])])}, Unit)))))
    ,
  )
}

test {
  inspect!(
    parse_minimoonbit_file!("test/test_src/matmul.mbt"),
    content=
      #|LetRec({name: ("matmul", Fun([], Unit)), args: [("l", Int), ("m", Int), ("n", Int), ("a", Array(Array(Double))), ("b", Array(Array(Double))), ("c", Array(Array(Double)))], body: LetRec({name: ("loop1", Fun([], Unit)), args: [("i", Int)], body: If(LE(Int(0), Var("i")), LetRec({name: ("loop2", Fun([], Unit)), args: [("j", Int)], body: If(LE(Int(0), Var("j")), LetRec({name: ("loop3", Fun([], Unit)), args: [("k", Int)], body: If(LE(Int(0), Var("k")), Let(("_", Unit), Put(Get(Var("c"), Var("i")), Var("j"), Prim(Get(Get(Var("c"), Var("i")), Var("j")), Prim(Get(Get(Var("a"), Var("i")), Var("k")), Get(Get(Var("b"), Var("k")), Var("j")), Mul, kind=None), Add, kind=None)), App(Var("loop3"), [Prim(Var("k"), Int(1), Sub, kind=None)])), Unit)}, Let(("_", Var({val: None})), App(Var("loop3"), [Prim(Var("m"), Int(1), Sub, kind=None)]), App(Var("loop2"), [Prim(Var("j"), Int(1), Sub, kind=None)]))), Unit)}, Let(("_", Var({val: None})), App(Var("loop2"), [Prim(Var("n"), Int(1), Sub, kind=None)]), App(Var("loop1"), [Prim(Var("i"), Int(1), Sub, kind=None)]))), Unit)}, App(Var("loop1"), [Prim(Var("l"), Int(1), Sub, kind=None)]))}, LetRec({name: ("main", Fun([], Unit)), args: [], body: Let(("dummy", Var({val: None})), Array(Int(0), Double(0)), LetRec({name: ("gen_arr", Fun([], Array(Array(Double)))), args: [("m", Int), ("n", Int)], body: Let(("mat", Var({val: None})), Array(Var("m"), Var("dummy")), LetRec({name: ("init_arr", Fun([], Unit)), args: [("i", Int)], body: If(LE(Int(0), Var("i")), Let(("_", Unit), Put(Var("mat"), Var("i"), Array(Var("n"), Double(0))), App(Var("init_arr"), [Prim(Var("i"), Int(1), Sub, kind=None)])), Unit)}, Let(("_", Var({val: None})), App(Var("init_arr"), [Prim(Var("m"), Int(1), Sub, kind=None)]), Var("mat"))))}, Let(("a", Var({val: None})), App(Var("gen_arr"), [Int(2), Int(3)]), Let(("b", Var({val: None})), App(Var("gen_arr"), [Int(3), Int(2)]), Let(("c", Var({val: None})), App(Var("gen_arr"), [Int(2), Int(2)]), Let(("_", Unit), Put(Get(Var("a"), Int(0)), Int(0), Double(1)), Let(("_", Unit), Put(Get(Var("a"), Int(0)), Int(1), Double(2)), Let(("_", Unit), Put(Get(Var("a"), Int(0)), Int(2), Double(3)), Let(("_", Unit), Put(Get(Var("a"), Int(1)), Int(0), Double(4)), Let(("_", Unit), Put(Get(Var("a"), Int(1)), Int(1), Double(5)), Let(("_", Unit), Put(Get(Var("a"), Int(1)), Int(2), Double(6)), Let(("_", Unit), Put(Get(Var("b"), Int(0)), Int(0), Double(7)), Let(("_", Unit), Put(Get(Var("b"), Int(0)), Int(1), Double(8)), Let(("_", Unit), Put(Get(Var("b"), Int(1)), Int(0), Double(9)), Let(("_", Unit), Put(Get(Var("b"), Int(1)), Int(1), Double(10)), Let(("_", Unit), Put(Get(Var("b"), Int(2)), Int(0), Double(11)), Let(("_", Unit), Put(Get(Var("b"), Int(2)), Int(1), Double(12)), Let(("_", Var({val: None})), App(Var("matmul"), [Int(2), Int(3), Int(2), Var("a"), Var("b"), Var("c")]), Let(("_", Var({val: None})), App(Var("print_int"), [App(Var("truncate"), [Get(Get(Var("c"), Int(0)), Int(0))])]), Let(("_", Var({val: None})), App(Var("print_endline"), []), Let(("_", Var({val: None})), App(Var("print_int"), [App(Var("truncate"), [Get(Get(Var("c"), Int(0)), Int(1))])]), Let(("_", Var({val: None})), App(Var("print_endline"), []), Let(("_", Var({val: None})), App(Var("print_int"), [App(Var("truncate"), [Get(Get(Var("c"), Int(1)), Int(0))])]), Let(("_", Var({val: None})), App(Var("print_endline"), []), Let(("_", Var({val: None})), App(Var("print_int"), [App(Var("truncate"), [Get(Get(Var("c"), Int(1)), Int(1))])]), Unit)))))))))))))))))))))))))}, Unit))
    ,
  )
}

test {
  inspect!(
    parse_minimoonbit_file!("test/test_typing/global_let.mbt"),
    content=
      #|Let(("a", Int), Int(100), LetRec({name: ("main", Fun([], Unit)), args: [], body: Let(("x", Var({val: None})), Int(1), Let(("y", Var({val: None})), Int(2), Let(("z", Var({val: None})), Prim(Var("x"), Prim(Var("y"), Var("a"), Add, kind=None), Add, kind=None), App(Var("print_int"), [Var("z")]))))}, Unit))
    ,
  )
}

test {
  inspect!(
    parse_minimoonbit_file!("test/test_typing/arith.mbt"),
    content=
      #|LetRec({name: ("main", Fun([], Unit)), args: [], body: Let(("a", Var({val: None})), Prim(Int(1), Prim(Int(2), Prim(Prim(Int(3), Prim(Int(4), Int(6), Div, kind=None), Mul, kind=None), Prim(Int(7), Prim(Prim(Int(8), Int(9), Mul, kind=None), Int(11), Sub, kind=None), Mul, kind=None), Add, kind=None), Sub, kind=None), Add, kind=None), Let(("b", Var({val: None})), Prim(Neg(Var("a"), kind=None), Int(55), Add, kind=None), App(Var("print_int"), [Var("b")])))}, Unit)
    ,
  )
}

test {
  inspect!(
    parse_minimoonbit_file!("test/test_typing/ident.mbt"),
    content=
      #|LetRec({name: ("main", Fun([], Unit)), args: [], body: Let(("a", Var({val: None})), Int(0), Let(("bcdef", Var({val: None})), Int(100), Let(("c_d_e_f", Var({val: None})), Int(200), Let(("Aaaaaaaaaaaaaaaaaaaaaaaaaaaaarghhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhh", Var({val: None})), Int(114514), Unit))))}, Unit)
    ,
  )
}

test {
  inspect!(
    parse_minimoonbit_file!("test/test_typing/very_deep.mbt"),
    content=
      #|LetRec({name: ("main", Fun([], Unit)), args: [], body: LetRec({name: ("foo", Var({val: None})), args: [], body: LetRec({name: ("bar", Var({val: None})), args: [], body: LetRec({name: ("baz", Var({val: None})), args: [], body: LetRec({name: ("level1", Var({val: None})), args: [], body: LetRec({name: ("level2", Var({val: None})), args: [], body: LetRec({name: ("level3", Var({val: None})), args: [], body: LetRec({name: ("level4", Var({val: None})), args: [], body: LetRec({name: ("level5", Var({val: None})), args: [], body: LetRec({name: ("level6", Var({val: None})), args: [], body: LetRec({name: ("level7", Var({val: None})), args: [], body: LetRec({name: ("level8", Var({val: None})), args: [], body: LetRec({name: ("level9", Var({val: None})), args: [], body: LetRec({name: ("level10", Var({val: None})), args: [], body: LetRec({name: ("level11", Var({val: None})), args: [], body: LetRec({name: ("level12", Var({val: None})), args: [], body: LetRec({name: ("level13", Var({val: None})), args: [], body: LetRec({name: ("level14", Var({val: None})), args: [], body: LetRec({name: ("level15", Var({val: None})), args: [], body: LetRec({name: ("level16", Var({val: None})), args: [], body: LetRec({name: ("level17", Var({val: None})), args: [], body: LetRec({name: ("level18", Var({val: None})), args: [], body: LetRec({name: ("level19", Var({val: None})), args: [], body: LetRec({name: ("level20", Var({val: None})), args: [], body: Unit}, Unit)}, Unit)}, Unit)}, Unit)}, Unit)}, Unit)}, Unit)}, Unit)}, Unit)}, Unit)}, Unit)}, Unit)}, Unit)}, Unit)}, Unit)}, Unit)}, Unit)}, Unit)}, Unit)}, Unit)}, Unit)}, Unit)}, Unit)}, Unit)
    ,
  )
}

test {
  let input : String = "print_int((g(456))(789))"
  let context = @lex.Context::new(input)
  let ok = @lex.lex(context)
  let state = State::new(context.tokens)
  let mut result : Syntax = Syntax::Unit
  assert_eq!(ok, 0)
  try {
    result = state.parse!(get_or_apply_level_expr)
    debug(result.to_string())
  } catch {
    ParseError(e) => println(e)
  }
  assert_true!(state.empty())
}

test {
  let input : String = "let (v1, v2, v3, v4, v5, v6, v7, v8, v9, v10) = p;"
  let context = @lex.Context::new(input)
  let ok = @lex.lex(context)
  let state = State::new(context.tokens)
  assert_eq!(ok, 0)
  try {
    let result = state.parse!(let_tuple_stmt)
    debug("result : \{result}")
  } catch {
    ParseError(e) => println(e)
  }
  assert_true!(state.empty())
}
