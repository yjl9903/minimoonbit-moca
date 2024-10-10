fn parse_minimoonbit_file(path : String) -> Syntax! {
  let parser : Parser[Syntax] = Parser(prog)
  assert_true!(@fs.path_exists(~path))
  let input : String = @fs.read_file_to_string!(~path)
  let context = @lex.Context::new(input)
  let ok = @lex.lex(context)
  assert_eq!(ok, 0)
  let (expr, rest) = parser.parse(context.tokens[:]).unwrap()
  assert_eq!(rest.length(), 0)
  return expr
}

test {
  // println(parse_minimoonbit_file!("test/test_src/ack.mbt"))
  // println(parse_minimoonbit_file!("test/test_src/adder2.mbt"))
  // println(parse_minimoonbit_file!("test/test_src/adder.mbt"))
  println(parse_minimoonbit_file!("test/test_src/spill3.mbt"))
  // println(parse_minimoonbit_file!("src/parser/test/case_1.mbt"))

}

test {
  let parser : Parser[Syntax] = Parser(get_or_apply_level_expr)
  // assert_true!(@fs.path_exists(path="src/parser/test/case_1.txt"))
  // let input : String = @fs.read_file_to_string!(path="src/parser/test/case_1.txt")
  let input = "x(y)[z](h,q)[i][j]"
  let context = @lex.Context::new(input)
  let ok = @lex.lex(context)
  println(ok)
  println(context.tokens)
  let (expr, _) = parser.parse(context.tokens[:]).unwrap()
  println(expr)
}
