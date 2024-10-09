test "lex function basic functionality" {
  let context = {
    str: "let x = 10;",
    offset: 0,
    row: 0,
    col: 0,
    tokens: Array::new(capacity=10),
  }
  assert_eq!(lex(context), 0)
  inspect!(
    context.tokens,
    content="[{kind: LET, raw: \"let\", pos: {row: 0, col: 0}}, {kind: IDENTIFIER(\"x\"), raw: \"x\", pos: {row: 0, col: 4}}, {kind: ASSIGN, raw: \"=\", pos: {row: 0, col: 6}}, {kind: NUMBER(10), raw: \"10\", pos: {row: 0, col: 8}}, {kind: SEMICOLON, raw: \";\", pos: {row: 0, col: 10}}]",
  )
}

test "lex function edge cases" {
  let context = {
    str: "",
    offset: 0,
    row: 0,
    col: 0,
    tokens: Array::new(capacity=10)
  }
  assert_eq!(lex(context), 0)
  inspect!(context.tokens, content="[]")
  let context = {
    str: "12345",
    offset: 0,
    row: 0,
    col: 0,
    tokens: Array::new(capacity=10)
  }
  assert_eq!(lex(context), 0)
  inspect!(context.tokens,content="[{kind: NUMBER(12345), raw: \"12345\", pos: {row: 0, col: 0}}]")
}


test "lex function random cases" {
  let context = {
    str: "fn main() { let x = 10; }",
    offset: 0,
    row: 0,
    col: 0,
    tokens: Array::new(capacity=20)
  }
  assert_eq!(lex(context), 0)
  inspect!(context.tokens, content="[{kind: FN, raw: \"fn\", pos: {row: 0, col: 0}}, {kind: IDENTIFIER(\"main\"), raw: \"main\", pos: {row: 0, col: 3}}, {kind: LPAREN, raw: \"(\", pos: {row: 0, col: 7}}, {kind: RPAREN, raw: \")\", pos: {row: 0, col: 8}}, {kind: LCURLYBRACKET, raw: \"{\", pos: {row: 0, col: 10}}, {kind: LET, raw: \"let\", pos: {row: 0, col: 12}}, {kind: IDENTIFIER(\"x\"), raw: \"x\", pos: {row: 0, col: 16}}, {kind: ASSIGN, raw: \"=\", pos: {row: 0, col: 18}}, {kind: NUMBER(10), raw: \"10\", pos: {row: 0, col: 20}}, {kind: SEMICOLON, raw: \";\", pos: {row: 0, col: 22}}, {kind: RCURLYBRACKET, raw: \"}\", pos: {row: 0, col: 24}}]")

  let context = {
    str: "if (x < 10) { x = x + 1; }",
    offset: 0,
    row: 0,
    col: 0,
    tokens: Array::new(capacity=20)
  }
  assert_eq!(lex(context), 0)
  inspect!(context.tokens, content="[{kind: IF, raw: \"if\", pos: {row: 0, col: 0}}, {kind: LPAREN, raw: \"(\", pos: {row: 0, col: 3}}, {kind: IDENTIFIER(\"x\"), raw: \"x\", pos: {row: 0, col: 4}}, {kind: LESS, raw: \"<\", pos: {row: 0, col: 6}}, {kind: NUMBER(10), raw: \"10\", pos: {row: 0, col: 8}}, {kind: RPAREN, raw: \")\", pos: {row: 0, col: 10}}, {kind: LCURLYBRACKET, raw: \"{\", pos: {row: 0, col: 12}}, {kind: IDENTIFIER(\"x\"), raw: \"x\", pos: {row: 0, col: 14}}, {kind: ASSIGN, raw: \"=\", pos: {row: 0, col: 16}}, {kind: IDENTIFIER(\"x\"), raw: \"x\", pos: {row: 0, col: 18}}, {kind: ADD, raw: \"+\", pos: {row: 0, col: 20}}, {kind: NUMBER(1), raw: \"1\", pos: {row: 0, col: 22}}, {kind: SEMICOLON, raw: \";\", pos: {row: 0, col: 23}}, {kind: RCURLYBRACKET, raw: \"}\", pos: {row: 0, col: 25}}]")

  let context = {
    str: "// This is a comment\nlet y = 20;",
    offset: 0,
    row: 0,
    col: 0,
    tokens: Array::new(capacity=20)
  }
  assert_eq!(lex(context), 0)
  inspect!(context.tokens, content="[]")
}




