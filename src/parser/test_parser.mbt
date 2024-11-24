pub fn parse_minimoonbit_file(path : String) -> Syntax! {
  @types.fun_def_id.val = 1
  @types.type_params_id.val = 0
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
    content=
      #|LetRec({id: 1, name: ("f", Fun([Int], Int)), args: [("x0", Int)], body: Let(("x1", Var({val: None})), Prim(Var("x0"), Int(1), Add, kind=None), Let(("x2", Var({val: None})), Prim(Var("x1"), Int(1), Add, kind=None), Let(("x3", Var({val: None})), Prim(Var("x2"), Int(1), Add, kind=None), Let(("x4", Var({val: None})), Prim(Var("x3"), Int(1), Add, kind=None), Let(("x5", Var({val: None})), Prim(Var("x4"), Int(1), Add, kind=None), Let(("x6", Var({val: None})), Prim(Var("x5"), Int(1), Add, kind=None), Let(("x7", Var({val: None})), Prim(Var("x6"), Int(1), Add, kind=None), Let(("x8", Var({val: None})), Prim(Var("x7"), Int(1), Add, kind=None), Let(("x9", Var({val: None})), Prim(Var("x8"), Int(1), Add, kind=None), Let(("x10", Var({val: None})), Prim(Var("x9"), Int(1), Add, kind=None), Let(("x11", Var({val: None})), Prim(Var("x10"), Int(1), Add, kind=None), Let(("x12", Var({val: None})), Prim(Var("x11"), Int(1), Add, kind=None), Let(("x13", Var({val: None})), Prim(Var("x12"), Int(1), Add, kind=None), Let(("x14", Var({val: None})), Prim(Var("x13"), Int(1), Add, kind=None), Let(("x15", Var({val: None})), Prim(Var("x14"), Int(1), Add, kind=None), Let(("x16", Var({val: None})), Prim(Var("x15"), Int(1), Add, kind=None), Let(("x17", Var({val: None})), Prim(Var("x16"), Int(1), Add, kind=None), Let(("x18", Var({val: None})), Prim(Var("x17"), Int(1), Add, kind=None), Let(("x19", Var({val: None})), Prim(Var("x18"), Var("x1"), Add, kind=None), Let(("x20", Var({val: None})), Prim(Var("x19"), Var("x2"), Add, kind=None), Let(("x21", Var({val: None})), Prim(Var("x20"), Var("x3"), Add, kind=None), Let(("x22", Var({val: None})), Prim(Var("x21"), Var("x4"), Add, kind=None), Let(("x23", Var({val: None})), Prim(Var("x22"), Var("x5"), Add, kind=None), Let(("x24", Var({val: None})), Prim(Var("x23"), Var("x6"), Add, kind=None), Let(("x25", Var({val: None})), Prim(Var("x24"), Var("x7"), Add, kind=None), Let(("x26", Var({val: None})), Prim(Var("x25"), Var("x8"), Add, kind=None), Let(("x27", Var({val: None})), Prim(Var("x26"), Var("x9"), Add, kind=None), Let(("x28", Var({val: None})), Prim(Var("x27"), Var("x10"), Add, kind=None), Let(("x29", Var({val: None})), Prim(Var("x28"), Var("x11"), Add, kind=None), Let(("x30", Var({val: None})), Prim(Var("x29"), Var("x12"), Add, kind=None), Let(("x31", Var({val: None})), Prim(Var("x30"), Var("x13"), Add, kind=None), Let(("x32", Var({val: None})), Prim(Var("x31"), Var("x14"), Add, kind=None), Let(("x33", Var({val: None})), Prim(Var("x32"), Var("x15"), Add, kind=None), Let(("x34", Var({val: None})), Prim(Var("x33"), Var("x16"), Add, kind=None), Let(("x35", Var({val: None})), Prim(Var("x34"), Var("x17"), Add, kind=None), Let(("x36", Var({val: None})), Prim(Var("x35"), Var("x0"), Add, kind=None), Prim(Prim(Prim(Prim(Prim(Prim(Prim(Prim(Prim(Prim(Prim(Prim(Prim(Prim(Prim(Prim(Prim(Prim(Prim(Prim(Prim(Prim(Prim(Prim(Prim(Prim(Prim(Prim(Prim(Prim(Prim(Prim(Prim(Prim(Prim(Prim(Var("x1"), Var("x2"), Add, kind=None), Var("x3"), Add, kind=None), Var("x4"), Add, kind=None), Var("x5"), Add, kind=None), Var("x6"), Add, kind=None), Var("x7"), Add, kind=None), Var("x8"), Add, kind=None), Var("x9"), Add, kind=None), Var("x10"), Add, kind=None), Var("x11"), Add, kind=None), Var("x12"), Add, kind=None), Var("x13"), Add, kind=None), Var("x14"), Add, kind=None), Var("x15"), Add, kind=None), Var("x16"), Add, kind=None), Var("x17"), Add, kind=None), Var("x18"), Add, kind=None), Var("x19"), Add, kind=None), Var("x20"), Add, kind=None), Var("x21"), Add, kind=None), Var("x22"), Add, kind=None), Var("x23"), Add, kind=None), Var("x24"), Add, kind=None), Var("x25"), Add, kind=None), Var("x26"), Add, kind=None), Var("x27"), Add, kind=None), Var("x28"), Add, kind=None), Var("x29"), Add, kind=None), Var("x30"), Add, kind=None), Var("x31"), Add, kind=None), Var("x32"), Add, kind=None), Var("x33"), Add, kind=None), Var("x34"), Add, kind=None), Var("x35"), Add, kind=None), Var("x36"), Add, kind=None), Var("x0"), Add, kind=None)))))))))))))))))))))))))))))))))))))}, LetRec({id: 2, name: ("main", Fun([], Unit)), args: [], body: App(Var("print_int"), [], [App(Var("f"), [], [Int(0)])])}, Unit))
    ,
  )
}

test "ack" {
  inspect!(
    parse_minimoonbit_file!("test/test_src/ack.mbt"),
    content=
      #|LetRec({id: 1, name: ("ack", Fun([Int, Int], Int)), args: [("x", Int), ("y", Int)], body: If(LE(Var("x"), Int(0)), Prim(Var("y"), Int(1), Add, kind=None), If(LE(Var("y"), Int(0)), App(Var("ack"), [], [Prim(Var("x"), Int(1), Sub, kind=None), Int(1)]), App(Var("ack"), [], [Prim(Var("x"), Int(1), Sub, kind=None), App(Var("ack"), [], [Var("x"), Prim(Var("y"), Int(1), Sub, kind=None)])])))}, LetRec({id: 2, name: ("main", Fun([], Unit)), args: [], body: App(Var("print_int"), [], [App(Var("ack"), [], [Int(3), Int(8)])])}, Unit))
    ,
  )
}

test "adder2" {
  inspect!(
    parse_minimoonbit_file!("test/test_src/adder2.mbt"),
    content=
      #|LetRec({id: 2, name: ("make_adder", Fun([Int], Fun([Int], Int))), args: [("x", Int)], body: LetRec({id: 1, name: ("adder", Fun([Int], Int)), args: [("y", Int)], body: Prim(Var("x"), Var("y"), Add, kind=None)}, Var("adder"))}, LetRec({id: 3, name: ("main", Fun([], Unit)), args: [], body: Let(("add2", Var({val: None})), App(Var("make_adder"), [], [Int(2)]), Let(("add3", Var({val: None})), App(Var("make_adder"), [], [Int(3)]), App(Var("print_int"), [], [Prim(App(Var("add2"), [], [Int(10)]), App(Var("add3"), [], [Int(20)]), Add, kind=None)])))}, Unit))
    ,
  )
}

test "cls-bug" {
  inspect!(
    parse_minimoonbit_file!("test/test_src/cls-bug.mbt"),
    content=
      #|LetRec({id: 1, name: ("f", Fun([Int], Int)), args: [("x", Int)], body: Prim(Var("x"), Int(123), Add, kind=None)}, LetRec({id: 2, name: ("g", Fun([Int], Fun([Int], Int))), args: [("y", Int)], body: Var("f")}, LetRec({id: 3, name: ("main", Fun([], Unit)), args: [], body: App(Var("print_int"), [], [App(App(Var("g"), [], [Int(456)]), [], [Int(789)])])}, Unit)))
    ,
  )
}

test "matmul-flat" {
  inspect!(
    parse_minimoonbit_file!("test/test_src/matmul-flat.mbt"),
    content=
      #|LetRec({id: 1, name: ("loop3", Fun([Int, Int, Int, Array(Array(Double)), Array(Array(Double)), Array(Array(Double))], Unit)), args: [("i", Int), ("j", Int), ("k", Int), ("a", Array(Array(Double))), ("b", Array(Array(Double))), ("c", Array(Array(Double)))], body: If(LE(Int(0), Var("k")), Let(("_", Unit), Put(Get(Var("c"), Var("i")), Var("j"), Prim(Get(Get(Var("c"), Var("i")), Var("j")), Prim(Get(Get(Var("a"), Var("i")), Var("k")), Get(Get(Var("b"), Var("k")), Var("j")), Mul, kind=None), Add, kind=None)), App(Var("loop3"), [], [Var("i"), Var("j"), Prim(Var("k"), Int(1), Sub, kind=None), Var("a"), Var("b"), Var("c")])), Unit)}, LetRec({id: 2, name: ("loop2", Fun([Int, Int, Int, Array(Array(Double)), Array(Array(Double)), Array(Array(Double))], Unit)), args: [("i", Int), ("m", Int), ("j", Int), ("a", Array(Array(Double))), ("b", Array(Array(Double))), ("c", Array(Array(Double)))], body: If(LE(Int(0), Var("j")), Let(("_", Var({val: None})), App(Var("loop3"), [], [Var("i"), Var("j"), Prim(Var("m"), Int(1), Sub, kind=None), Var("a"), Var("b"), Var("c")]), App(Var("loop2"), [], [Var("i"), Var("m"), Prim(Var("j"), Int(1), Sub, kind=None), Var("a"), Var("b"), Var("c")])), Unit)}, LetRec({id: 3, name: ("loop1", Fun([Int, Int, Int, Array(Array(Double)), Array(Array(Double)), Array(Array(Double))], Unit)), args: [("i", Int), ("m", Int), ("n", Int), ("a", Array(Array(Double))), ("b", Array(Array(Double))), ("c", Array(Array(Double)))], body: If(LE(Int(0), Var("i")), Let(("_", Var({val: None})), App(Var("loop2"), [], [Var("i"), Var("m"), Prim(Var("n"), Int(1), Sub, kind=None), Var("a"), Var("b"), Var("c")]), App(Var("loop1"), [], [Prim(Var("i"), Int(1), Sub, kind=None), Var("m"), Var("n"), Var("a"), Var("b"), Var("c")])), Unit)}, LetRec({id: 4, name: ("mul", Fun([Int, Int, Int, Array(Array(Double)), Array(Array(Double)), Array(Array(Double))], Unit)), args: [("l", Int), ("m", Int), ("n", Int), ("a", Array(Array(Double))), ("b", Array(Array(Double))), ("c", Array(Array(Double)))], body: Let(("_", Var({val: None})), App(Var("loop1"), [], [Prim(Var("l"), Int(1), Sub, kind=None), Var("m"), Var("n"), Var("a"), Var("b"), Var("c")]), Unit)}, LetRec({id: 7, name: ("main", Fun([], Unit)), args: [], body: Let(("dummy", Var({val: None})), Array(Int(0), Double(0)), LetRec({id: 5, name: ("init_arr", Fun([Int, Int, Array(Array(Double))], Unit)), args: [("i", Int), ("n", Int), ("mat", Array(Array(Double)))], body: If(LE(Int(0), Var("i")), Let(("_", Unit), Put(Var("mat"), Var("i"), Array(Var("n"), Double(0))), App(Var("init_arr"), [], [Prim(Var("i"), Int(1), Sub, kind=None), Var("n"), Var("mat")])), Unit)}, LetRec({id: 6, name: ("make_arr", Fun([Int, Int, Array(Double)], Array(Array(Double)))), args: [("m", Int), ("n", Int), ("dummy", Array(Double))], body: Let(("mat", Var({val: None})), Array(Var("m"), Var("dummy")), Let(("_", Var({val: None})), App(Var("init_arr"), [], [Prim(Var("m"), Int(1), Sub, kind=None), Var("n"), Var("mat")]), Var("mat")))}, Let(("a", Var({val: None})), App(Var("make_arr"), [], [Int(2), Int(3), Var("dummy")]), Let(("b", Var({val: None})), App(Var("make_arr"), [], [Int(3), Int(2), Var("dummy")]), Let(("c", Var({val: None})), App(Var("make_arr"), [], [Int(2), Int(2), Var("dummy")]), Let(("_", Unit), Put(Get(Var("a"), Int(0)), Int(0), Double(1)), Let(("_", Unit), Put(Get(Var("a"), Int(0)), Int(1), Double(2)), Let(("_", Unit), Put(Get(Var("a"), Int(0)), Int(2), Double(3)), Let(("_", Unit), Put(Get(Var("a"), Int(1)), Int(0), Double(4)), Let(("_", Unit), Put(Get(Var("a"), Int(1)), Int(1), Double(5)), Let(("_", Unit), Put(Get(Var("a"), Int(1)), Int(2), Double(6)), Let(("_", Unit), Put(Get(Var("b"), Int(0)), Int(0), Double(7)), Let(("_", Unit), Put(Get(Var("b"), Int(0)), Int(1), Double(8)), Let(("_", Unit), Put(Get(Var("b"), Int(1)), Int(0), Double(9)), Let(("_", Unit), Put(Get(Var("b"), Int(1)), Int(1), Double(10)), Let(("_", Unit), Put(Get(Var("b"), Int(2)), Int(0), Double(11)), Let(("_", Unit), Put(Get(Var("b"), Int(2)), Int(1), Double(12)), Let(("_", Var({val: None})), App(Var("mul"), [], [Int(2), Int(3), Int(2), Var("a"), Var("b"), Var("c")]), Let(("_", Var({val: None})), App(Var("print_int"), [], [App(Var("truncate"), [], [Get(Get(Var("c"), Int(0)), Int(0))])]), Let(("_", Var({val: None})), App(Var("print_endline"), [], []), Let(("_", Var({val: None})), App(Var("print_int"), [], [App(Var("truncate"), [], [Get(Get(Var("c"), Int(0)), Int(1))])]), Let(("_", Var({val: None})), App(Var("print_endline"), [], []), Let(("_", Var({val: None})), App(Var("print_int"), [], [App(Var("truncate"), [], [Get(Get(Var("c"), Int(1)), Int(0))])]), Let(("_", Var({val: None})), App(Var("print_endline"), [], []), Let(("_", Var({val: None})), App(Var("print_int"), [], [App(Var("truncate"), [], [Get(Get(Var("c"), Int(1)), Int(1))])]), Unit))))))))))))))))))))))))))}, Unit)))))
    ,
  )
}

test "matmul" {
  inspect!(
    parse_minimoonbit_file!("test/test_src/matmul.mbt"),
    content=
      #|LetRec({id: 4, name: ("matmul", Fun([Int, Int, Int, Array(Array(Double)), Array(Array(Double)), Array(Array(Double))], Unit)), args: [("l", Int), ("m", Int), ("n", Int), ("a", Array(Array(Double))), ("b", Array(Array(Double))), ("c", Array(Array(Double)))], body: LetRec({id: 3, name: ("loop1", Fun([Int], Unit)), args: [("i", Int)], body: If(LE(Int(0), Var("i")), LetRec({id: 2, name: ("loop2", Fun([Int], Unit)), args: [("j", Int)], body: If(LE(Int(0), Var("j")), LetRec({id: 1, name: ("loop3", Fun([Int], Unit)), args: [("k", Int)], body: If(LE(Int(0), Var("k")), Let(("_", Unit), Put(Get(Var("c"), Var("i")), Var("j"), Prim(Get(Get(Var("c"), Var("i")), Var("j")), Prim(Get(Get(Var("a"), Var("i")), Var("k")), Get(Get(Var("b"), Var("k")), Var("j")), Mul, kind=None), Add, kind=None)), App(Var("loop3"), [], [Prim(Var("k"), Int(1), Sub, kind=None)])), Unit)}, Let(("_", Var({val: None})), App(Var("loop3"), [], [Prim(Var("m"), Int(1), Sub, kind=None)]), App(Var("loop2"), [], [Prim(Var("j"), Int(1), Sub, kind=None)]))), Unit)}, Let(("_", Var({val: None})), App(Var("loop2"), [], [Prim(Var("n"), Int(1), Sub, kind=None)]), App(Var("loop1"), [], [Prim(Var("i"), Int(1), Sub, kind=None)]))), Unit)}, App(Var("loop1"), [], [Prim(Var("l"), Int(1), Sub, kind=None)]))}, LetRec({id: 7, name: ("main", Fun([], Unit)), args: [], body: Let(("dummy", Var({val: None})), Array(Int(0), Double(0)), LetRec({id: 6, name: ("gen_arr", Fun([Int, Int], Array(Array(Double)))), args: [("m", Int), ("n", Int)], body: Let(("mat", Var({val: None})), Array(Var("m"), Var("dummy")), LetRec({id: 5, name: ("init_arr", Fun([Int], Unit)), args: [("i", Int)], body: If(LE(Int(0), Var("i")), Let(("_", Unit), Put(Var("mat"), Var("i"), Array(Var("n"), Double(0))), App(Var("init_arr"), [], [Prim(Var("i"), Int(1), Sub, kind=None)])), Unit)}, Let(("_", Var({val: None})), App(Var("init_arr"), [], [Prim(Var("m"), Int(1), Sub, kind=None)]), Var("mat"))))}, Let(("a", Var({val: None})), App(Var("gen_arr"), [], [Int(2), Int(3)]), Let(("b", Var({val: None})), App(Var("gen_arr"), [], [Int(3), Int(2)]), Let(("c", Var({val: None})), App(Var("gen_arr"), [], [Int(2), Int(2)]), Let(("_", Unit), Put(Get(Var("a"), Int(0)), Int(0), Double(1)), Let(("_", Unit), Put(Get(Var("a"), Int(0)), Int(1), Double(2)), Let(("_", Unit), Put(Get(Var("a"), Int(0)), Int(2), Double(3)), Let(("_", Unit), Put(Get(Var("a"), Int(1)), Int(0), Double(4)), Let(("_", Unit), Put(Get(Var("a"), Int(1)), Int(1), Double(5)), Let(("_", Unit), Put(Get(Var("a"), Int(1)), Int(2), Double(6)), Let(("_", Unit), Put(Get(Var("b"), Int(0)), Int(0), Double(7)), Let(("_", Unit), Put(Get(Var("b"), Int(0)), Int(1), Double(8)), Let(("_", Unit), Put(Get(Var("b"), Int(1)), Int(0), Double(9)), Let(("_", Unit), Put(Get(Var("b"), Int(1)), Int(1), Double(10)), Let(("_", Unit), Put(Get(Var("b"), Int(2)), Int(0), Double(11)), Let(("_", Unit), Put(Get(Var("b"), Int(2)), Int(1), Double(12)), Let(("_", Var({val: None})), App(Var("matmul"), [], [Int(2), Int(3), Int(2), Var("a"), Var("b"), Var("c")]), Let(("_", Var({val: None})), App(Var("print_int"), [], [App(Var("truncate"), [], [Get(Get(Var("c"), Int(0)), Int(0))])]), Let(("_", Var({val: None})), App(Var("print_endline"), [], []), Let(("_", Var({val: None})), App(Var("print_int"), [], [App(Var("truncate"), [], [Get(Get(Var("c"), Int(0)), Int(1))])]), Let(("_", Var({val: None})), App(Var("print_endline"), [], []), Let(("_", Var({val: None})), App(Var("print_int"), [], [App(Var("truncate"), [], [Get(Get(Var("c"), Int(1)), Int(0))])]), Let(("_", Var({val: None})), App(Var("print_endline"), [], []), Let(("_", Var({val: None})), App(Var("print_int"), [], [App(Var("truncate"), [], [Get(Get(Var("c"), Int(1)), Int(1))])]), Unit)))))))))))))))))))))))))}, Unit))
    ,
  )
}

test "join-stack3" {
  inspect!(
    parse_minimoonbit_file!("test/test_src/join-stack3.mbt"),
    content=
      #|LetRec({id: 1, name: ("f", Fun([Unit], Int)), args: [("u", Unit)], body: Int(123)}, LetRec({id: 2, name: ("g", Fun([Unit], Int)), args: [("u", Unit)], body: Int(456)}, LetRec({id: 3, name: ("h", Fun([Unit], Int)), args: [("u", Unit)], body: Int(789)}, LetRec({id: 4, name: ("main", Fun([], Unit)), args: [], body: Let(("x", Var({val: None})), App(Var("f"), [], [Unit]), App(Var("print_int"), [], [Prim(If(LE(Var("x"), Int(0)), App(Var("g"), [], [Unit]), App(Var("h"), [], [Unit])), Var("x"), Add, kind=None)]))}, Unit))))
    ,
  )
}

test "cls-reg-bug" {
  inspect!(
    parse_minimoonbit_file!("test/test_src/cls-reg-bug.mbt"),
    content=
      #|LetRec({id: 2, name: ("h", Fun([Tuple([Int, Int, Int, Int, Int, Int, Int, Int, Int, Int])], Int)), args: [("p", Tuple([Int, Int, Int, Int, Int, Int, Int, Int, Int, Int]))], body: LetTuple([("v1", Var({val: None})), ("v2", Var({val: None})), ("v3", Var({val: None})), ("v4", Var({val: None})), ("v5", Var({val: None})), ("v6", Var({val: None})), ("v7", Var({val: None})), ("v8", Var({val: None})), ("v9", Var({val: None})), ("v10", Var({val: None}))], Var("p"), LetRec({id: 1, name: ("g", Fun([Int], Int)), args: [("z", Int)], body: Let(("r", Var({val: None})), Prim(Prim(Prim(Prim(Prim(Prim(Prim(Prim(Prim(Var("v1"), Var("v2"), Add, kind=None), Var("v3"), Add, kind=None), Var("v4"), Add, kind=None), Var("v5"), Add, kind=None), Var("v6"), Add, kind=None), Var("v7"), Add, kind=None), Var("v8"), Add, kind=None), Var("v9"), Add, kind=None), Var("v10"), Add, kind=None), If(Not(LE(Var("z"), Int(0))), Var("r"), App(Var("g"), [], [Neg(Var("z"), kind=None)])))}, App(Var("g"), [], [Int(1)])))}, LetRec({id: 3, name: ("main", Fun([], Unit)), args: [], body: Let(("t1", Var({val: None})), App(Var("print_int"), [], [App(Var("h"), [], [Tuple([Int(1), Int(2), Int(3), Int(4), Int(5), Int(6), Int(7), Int(8), Int(9), Int(10)])])]), Unit)}, Unit))
    ,
  )
}

test {
  inspect!(
    parse_minimoonbit_file!("test/test_src/float.mbt"),
    content=
      #|LetRec({id: 1, name: ("main", Fun([], Unit)), args: [], body: App(Var("print_int"), [], [App(Var("int_of_float"), [], [Prim(Prim(Prim(App(Var("sin"), [], [App(Var("cos"), [], [App(Var("sqrt"), [], [App(Var("abs_float"), [], [Neg(Double(12.3), kind=None)])])])]), Double(4.5), Add, kind=None), Prim(Prim(Double(6.7), Double(8.9), Mul, kind=None), Double(1.23456789), Div, kind=None), Sub, kind=None), App(Var("float_of_int"), [], [Int(1000000)]), Mul, kind=None)])])}, Unit)
    ,
  )
}

test {
  inspect!(
    parse_minimoonbit_file!("test/test_src/inprod.mbt"),
    content=
      #|LetRec({id: 1, name: ("getx", Fun([Tuple([Double, Double, Double])], Double)), args: [("v", Tuple([Double, Double, Double]))], body: LetTuple([("x", Var({val: None})), ("_", Var({val: None})), ("_", Var({val: None}))], Var("v"), Var("x"))}, LetRec({id: 2, name: ("gety", Fun([Tuple([Double, Double, Double])], Double)), args: [("v", Tuple([Double, Double, Double]))], body: LetTuple([("_", Var({val: None})), ("y", Var({val: None})), ("_", Var({val: None}))], Var("v"), Var("y"))}, LetRec({id: 3, name: ("getz", Fun([Tuple([Double, Double, Double])], Double)), args: [("v", Tuple([Double, Double, Double]))], body: LetTuple([("_", Var({val: None})), ("_", Var({val: None})), ("z", Var({val: None}))], Var("v"), Var("z"))}, LetRec({id: 4, name: ("inprod", Fun([Tuple([Double, Double, Double]), Tuple([Double, Double, Double])], Double)), args: [("v1", Tuple([Double, Double, Double])), ("v2", Tuple([Double, Double, Double]))], body: Prim(Prim(Prim(App(Var("getx"), [], [Var("v1")]), App(Var("getx"), [], [Var("v2")]), Mul, kind=None), Prim(App(Var("gety"), [], [Var("v1")]), App(Var("gety"), [], [Var("v2")]), Mul, kind=None), Add, kind=None), Prim(App(Var("getz"), [], [Var("v1")]), App(Var("getz"), [], [Var("v2")]), Mul, kind=None), Add, kind=None)}, LetRec({id: 5, name: ("main", Fun([], Unit)), args: [], body: App(Var("print_int"), [], [App(Var("truncate"), [], [Prim(Double(1000000), App(Var("inprod"), [], [Tuple([Double(1), Double(2), Double(3)]), Tuple([Double(4), Double(5), Double(6)])]), Mul, kind=None)])])}, Unit)))))
    ,
  )
}

test {
  inspect!(
    parse_minimoonbit_file!("test/test_src/matmul.mbt"),
    content=
      #|LetRec({id: 4, name: ("matmul", Fun([Int, Int, Int, Array(Array(Double)), Array(Array(Double)), Array(Array(Double))], Unit)), args: [("l", Int), ("m", Int), ("n", Int), ("a", Array(Array(Double))), ("b", Array(Array(Double))), ("c", Array(Array(Double)))], body: LetRec({id: 3, name: ("loop1", Fun([Int], Unit)), args: [("i", Int)], body: If(LE(Int(0), Var("i")), LetRec({id: 2, name: ("loop2", Fun([Int], Unit)), args: [("j", Int)], body: If(LE(Int(0), Var("j")), LetRec({id: 1, name: ("loop3", Fun([Int], Unit)), args: [("k", Int)], body: If(LE(Int(0), Var("k")), Let(("_", Unit), Put(Get(Var("c"), Var("i")), Var("j"), Prim(Get(Get(Var("c"), Var("i")), Var("j")), Prim(Get(Get(Var("a"), Var("i")), Var("k")), Get(Get(Var("b"), Var("k")), Var("j")), Mul, kind=None), Add, kind=None)), App(Var("loop3"), [], [Prim(Var("k"), Int(1), Sub, kind=None)])), Unit)}, Let(("_", Var({val: None})), App(Var("loop3"), [], [Prim(Var("m"), Int(1), Sub, kind=None)]), App(Var("loop2"), [], [Prim(Var("j"), Int(1), Sub, kind=None)]))), Unit)}, Let(("_", Var({val: None})), App(Var("loop2"), [], [Prim(Var("n"), Int(1), Sub, kind=None)]), App(Var("loop1"), [], [Prim(Var("i"), Int(1), Sub, kind=None)]))), Unit)}, App(Var("loop1"), [], [Prim(Var("l"), Int(1), Sub, kind=None)]))}, LetRec({id: 7, name: ("main", Fun([], Unit)), args: [], body: Let(("dummy", Var({val: None})), Array(Int(0), Double(0)), LetRec({id: 6, name: ("gen_arr", Fun([Int, Int], Array(Array(Double)))), args: [("m", Int), ("n", Int)], body: Let(("mat", Var({val: None})), Array(Var("m"), Var("dummy")), LetRec({id: 5, name: ("init_arr", Fun([Int], Unit)), args: [("i", Int)], body: If(LE(Int(0), Var("i")), Let(("_", Unit), Put(Var("mat"), Var("i"), Array(Var("n"), Double(0))), App(Var("init_arr"), [], [Prim(Var("i"), Int(1), Sub, kind=None)])), Unit)}, Let(("_", Var({val: None})), App(Var("init_arr"), [], [Prim(Var("m"), Int(1), Sub, kind=None)]), Var("mat"))))}, Let(("a", Var({val: None})), App(Var("gen_arr"), [], [Int(2), Int(3)]), Let(("b", Var({val: None})), App(Var("gen_arr"), [], [Int(3), Int(2)]), Let(("c", Var({val: None})), App(Var("gen_arr"), [], [Int(2), Int(2)]), Let(("_", Unit), Put(Get(Var("a"), Int(0)), Int(0), Double(1)), Let(("_", Unit), Put(Get(Var("a"), Int(0)), Int(1), Double(2)), Let(("_", Unit), Put(Get(Var("a"), Int(0)), Int(2), Double(3)), Let(("_", Unit), Put(Get(Var("a"), Int(1)), Int(0), Double(4)), Let(("_", Unit), Put(Get(Var("a"), Int(1)), Int(1), Double(5)), Let(("_", Unit), Put(Get(Var("a"), Int(1)), Int(2), Double(6)), Let(("_", Unit), Put(Get(Var("b"), Int(0)), Int(0), Double(7)), Let(("_", Unit), Put(Get(Var("b"), Int(0)), Int(1), Double(8)), Let(("_", Unit), Put(Get(Var("b"), Int(1)), Int(0), Double(9)), Let(("_", Unit), Put(Get(Var("b"), Int(1)), Int(1), Double(10)), Let(("_", Unit), Put(Get(Var("b"), Int(2)), Int(0), Double(11)), Let(("_", Unit), Put(Get(Var("b"), Int(2)), Int(1), Double(12)), Let(("_", Var({val: None})), App(Var("matmul"), [], [Int(2), Int(3), Int(2), Var("a"), Var("b"), Var("c")]), Let(("_", Var({val: None})), App(Var("print_int"), [], [App(Var("truncate"), [], [Get(Get(Var("c"), Int(0)), Int(0))])]), Let(("_", Var({val: None})), App(Var("print_endline"), [], []), Let(("_", Var({val: None})), App(Var("print_int"), [], [App(Var("truncate"), [], [Get(Get(Var("c"), Int(0)), Int(1))])]), Let(("_", Var({val: None})), App(Var("print_endline"), [], []), Let(("_", Var({val: None})), App(Var("print_int"), [], [App(Var("truncate"), [], [Get(Get(Var("c"), Int(1)), Int(0))])]), Let(("_", Var({val: None})), App(Var("print_endline"), [], []), Let(("_", Var({val: None})), App(Var("print_int"), [], [App(Var("truncate"), [], [Get(Get(Var("c"), Int(1)), Int(1))])]), Unit)))))))))))))))))))))))))}, Unit))
    ,
  )
}

test {
  inspect!(
    parse_minimoonbit_file!("test/test_typing/global_let.mbt"),
    content=
      #|Let(("a", Int), Int(100), LetRec({id: 1, name: ("main", Fun([], Unit)), args: [], body: Let(("x", Var({val: None})), Int(1), Let(("y", Var({val: None})), Int(2), Let(("z", Var({val: None})), Prim(Prim(Var("x"), Var("y"), Add, kind=None), Var("a"), Add, kind=None), App(Var("print_int"), [], [Var("z")]))))}, Unit))
    ,
  )
}

test {
  inspect!(
    parse_minimoonbit_file!("test/test_typing/arith.mbt"),
    content=
      #|LetRec({id: 1, name: ("main", Fun([], Unit)), args: [], body: Let(("a", Var({val: None})), Prim(Prim(Prim(Int(1), Int(2), Add, kind=None), Prim(Prim(Int(3), Int(4), Mul, kind=None), Int(6), Div, kind=None), Sub, kind=None), Prim(Int(7), Prim(Prim(Int(8), Int(9), Mul, kind=None), Int(11), Sub, kind=None), Mul, kind=None), Add, kind=None), Let(("b", Var({val: None})), Prim(Neg(Var("a"), kind=None), Int(55), Add, kind=None), App(Var("print_int"), [], [Var("b")])))}, Unit)
    ,
  )
}

test {
  inspect!(
    parse_minimoonbit_file!("test/test_typing/ident.mbt"),
    content=
      #|LetRec({id: 1, name: ("main", Fun([], Unit)), args: [], body: Let(("a", Var({val: None})), Int(0), Let(("bcdef", Var({val: None})), Int(100), Let(("c_d_e_f", Var({val: None})), Int(200), Let(("Aaaaaaaaaaaaaaaaaaaaaaaaaaaaarghhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhh", Var({val: None})), Int(114514), Unit))))}, Unit)
    ,
  )
}

test {
  inspect!(
    parse_minimoonbit_file!("test/test_typing/very_deep.mbt"),
    content=
      #|LetRec({id: 24, name: ("main", Fun([], Unit)), args: [], body: LetRec({id: 23, name: ("foo", Fun([], Var({val: None}))), args: [], body: LetRec({id: 22, name: ("bar", Fun([], Var({val: None}))), args: [], body: LetRec({id: 21, name: ("baz", Fun([], Var({val: None}))), args: [], body: LetRec({id: 20, name: ("level1", Fun([], Var({val: None}))), args: [], body: LetRec({id: 19, name: ("level2", Fun([], Var({val: None}))), args: [], body: LetRec({id: 18, name: ("level3", Fun([], Var({val: None}))), args: [], body: LetRec({id: 17, name: ("level4", Fun([], Var({val: None}))), args: [], body: LetRec({id: 16, name: ("level5", Fun([], Var({val: None}))), args: [], body: LetRec({id: 15, name: ("level6", Fun([], Var({val: None}))), args: [], body: LetRec({id: 14, name: ("level7", Fun([], Var({val: None}))), args: [], body: LetRec({id: 13, name: ("level8", Fun([], Var({val: None}))), args: [], body: LetRec({id: 12, name: ("level9", Fun([], Var({val: None}))), args: [], body: LetRec({id: 11, name: ("level10", Fun([], Var({val: None}))), args: [], body: LetRec({id: 10, name: ("level11", Fun([], Var({val: None}))), args: [], body: LetRec({id: 9, name: ("level12", Fun([], Var({val: None}))), args: [], body: LetRec({id: 8, name: ("level13", Fun([], Var({val: None}))), args: [], body: LetRec({id: 7, name: ("level14", Fun([], Var({val: None}))), args: [], body: LetRec({id: 6, name: ("level15", Fun([], Var({val: None}))), args: [], body: LetRec({id: 5, name: ("level16", Fun([], Var({val: None}))), args: [], body: LetRec({id: 4, name: ("level17", Fun([], Var({val: None}))), args: [], body: LetRec({id: 3, name: ("level18", Fun([], Var({val: None}))), args: [], body: LetRec({id: 2, name: ("level19", Fun([], Var({val: None}))), args: [], body: LetRec({id: 1, name: ("level20", Fun([], Var({val: None}))), args: [], body: Unit}, Unit)}, Unit)}, Unit)}, Unit)}, Unit)}, Unit)}, Unit)}, Unit)}, Unit)}, Unit)}, Unit)}, Unit)}, Unit)}, Unit)}, Unit)}, Unit)}, Unit)}, Unit)}, Unit)}, Unit)}, Unit)}, Unit)}, Unit)}, Unit)
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
// test {
//   let input : String = "1 + 2 * 3 + 100;"
//   let context = @lex.Context::new(input)
//   let ok = @lex.lex(context)
//   let state = State::new(context.tokens)
//   let mut result : Syntax = Syntax::Unit
//   assert_eq!(ok, 0)
//   try {
//     result = state.parse!(add_sub_level_expr)
//     debug(result.to_string())
//   } catch {
//     ParseError(e) => println(e)
//   }
//   assert_true!(state.empty())
// }

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

test {
  inspect!(
    parse_minimoonbit_file!("test/test_parser/let.mbt"),
    content=
      #|LetRec({id: 1, name: ("main", Fun([], Unit)), args: [], body: Let(("a", Var({val: None})), Neg(Prim(Int(1), Int(2), Add, kind=None), kind=None), Let(("t1", Var({val: None})), App(Var("print_int"), [], [Neg(Prim(Int(1), Int(2), Add, kind=None), kind=None)]), Unit))}, Unit)
    ,
  )
}
