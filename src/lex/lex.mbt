struct Token {
  kind : TokenKind
  raw : String
  pos : Position
} derive(Show)

struct Position {
  row : Int
  col : Int
} derive(Show)

pub enum TokenKind {
  TRUE
  FALSE
  UINT
  BOOL
  INT
  DOUBLE
  ARRAY
  NOT
  IF
  ELSE
  FN
  LET
  NUMBER(Int)
  IDENTIFIER(String)
  DOT
  ADD
  SUB
  MUL
  DIV
  ASSIGN
  EQ
  LE
  LPAREN
  RPAREN
  LBRACKET
  RBRACKET
  LCURLYBRACKET
  RCURLYBRACKET
  ARROW
  COLON
  SEMICOLON
  COMMA
  LESS
} derive(Eq, Show)

pub struct Context {
  str : String
  mut offset : Int
  mut row : Int // 当前行号
  mut col : Int // 当前列号
  tokens : Array[Token]
}

fn is_digit(ch : Char) -> Bool {
  ch >= '0' && ch <= '9'
}

fn is_alpha(ch : Char) -> Bool {
  (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || ch == '_'
}

fn lex_number(context : Context) -> UInt {
  let { offset, str, .. } = context
  let number = "\{str[offset]}"
  context.offset += 1
  context.col += 1
  lex_number_rest(context, number)
}

fn lex_number_rest(context : Context, number : String) -> UInt {
  let { offset, str, tokens, row, col } = context
  if offset >= str.length() {
    tokens.push(
      {
        kind: NUMBER(@strconv.parse_int?(number).unwrap()),
        raw: number,
        pos: { row, col: col - number.length() },
      },
    )
    return 0
  }
  let ch = str[offset]
  if is_digit(ch) {
    context.offset += 1
    context.col += 1
    lex_number_rest(context, number + ch.to_string())
  } else {
    tokens.push(
      {
        kind: NUMBER(@strconv.parse_int?(number).unwrap()),
        raw: number,
        pos: { row, col: col - number.length() },
      },
    )
    lex(context)
  }
}

fn lex_alpha(context : Context) -> UInt {
  let { offset, str, .. } = context
  let alpha = "\{str[offset]}"
  context.offset += 1
  context.col += 1
  lex_alpha_rest(context, alpha)
}

fn lex_alpha_rest(context : Context, alpha : String) -> UInt {
  let { offset, str, tokens, row, col } = context
  if offset >= str.length() {
    let tokenKind = get_token(alpha)
    tokens.push({ kind: tokenKind, raw: alpha, pos: { row: row, col: col - alpha.length()} })
    return 0
  }
  let ch = str[offset]
  if is_digit(ch) || is_alpha(ch) {
    context.offset += 1
    context.col += 1;
    lex_alpha_rest(context, alpha + ch.to_string())
  } else {
    let tokenKind = get_token(alpha)
    tokens.push({ kind: tokenKind, raw: alpha, pos: { row: row, col: col - alpha.length()} })
    lex(context)
  }
}

fn get_token(text : String) -> TokenKind {
  match text {
    "true" => return TRUE
    "false" => return FALSE
    "Uint" => return UINT
    "Int" => return INT
    "Bool" => return BOOL
    "Double" => return DOUBLE
    "Array" => return ARRAY
    "not" => return NOT
    "if" => return IF
    "else" => return ELSE
    "fn" => return FN
    "let" => return LET
    _ => return IDENTIFIER(text)
  }
}

pub fn lex(context : Context) -> UInt {
  let { offset, str, tokens, row, col } = context
  if offset >= str.length() {
    return 0
  }
  match str[offset] {
    '+' => {
      tokens.push({ kind: ADD, raw: "+", pos: { row, col } })
      context.offset += 1
      context.col += 1
      lex(context)
    }
    '-' =>
      if offset + 1 >= str.length() || str[offset + 1] != '>' {
        tokens.push({ kind: SUB, raw: "-", pos: { row, col } })
        context.offset += 1
        context.col += 1
        lex(context)
      } else {
        tokens.push({ kind: ARROW, raw: "->", pos: { row, col } })
        context.offset += 2
        context.col += 2
        lex(context)
      }
    '*' => {
      tokens.push({ kind: MUL, raw: "*", pos: { row, col } })
      context.offset += 1
      context.col += 1
      lex(context)
    }
    '/' =>
      if offset + 1 >= str.length() || str[offset + 1] != '/' {
        tokens.push({ kind: DIV, raw: "/", pos: { row, col } })
        context.offset += 1
        context.col += 1
        lex(context)
      } else {
        context.offset += 2
        while context.offset < str.length() &&
              (str[context.offset] != '\n' || str[context.offset] != '\r') {
          context.offset += 1
        }
        context.row += 1
        context.col = 0
        lex(context)
      }
    '.' => {
      tokens.push({ kind: DOT, raw: ".", pos: { row, col } })
      context.offset += 1
      context.col += 1
      lex(context)
    }
    '(' => {
      tokens.push({ kind: LPAREN, raw: "(", pos: { row, col } })
      context.offset += 1
      context.col += 1
      lex(context)
    }
    ')' => {
      tokens.push({ kind: RPAREN, raw: ")", pos: { row, col } })
      context.offset += 1
      context.col += 1
      lex(context)
    }
    '[' => {
      tokens.push({ kind: LBRACKET, raw: "[", pos: { row, col } })
      context.offset += 1
      context.col += 1
      lex(context)
    }
    ']' => {
      tokens.push({ kind: RBRACKET, raw: "]", pos: { row, col } })
      context.offset += 1
      context.col += 1
      lex(context)
    }
    '{' => {
      tokens.push({ kind: LCURLYBRACKET, raw: "{", pos: { row, col } })
      context.offset += 1
      context.col += 1
      lex(context)
    }
    '}' => {
      tokens.push({ kind: RCURLYBRACKET, raw: "}", pos: { row, col } })
      context.offset += 1
      context.col += 1
      lex(context)
    }
    ':' => {
      tokens.push({ kind: COLON, raw: ":", pos: { row, col } })
      context.offset += 1
      lex(context)
    }
    ',' => {
      tokens.push({ kind: COMMA, raw: ",", pos: { row, col } })
      context.offset += 1
      lex(context)
    }
    ';' => {
      tokens.push({ kind: SEMICOLON, raw: ";", pos: { row, col } })
      context.offset += 1
      context.col += 1
      lex(context)
    }
    ' ' | '\t' => {
      context.offset += 1
      context.col += 1
      lex(context)
    }
    '\n' | '\r' => {
      context.offset += 1
      context.row += 1
      context.col = 0
      lex(context)
    }
    '=' =>
      if offset + 1 >= str.length() || str[offset + 1] != '=' {
        tokens.push({ kind: ASSIGN, raw: "=", pos: { row, col } })
        context.offset += 1
        context.col += 1
        lex(context)
      } else {
        tokens.push({ kind: EQ, raw: "==", pos: { row, col } })
        context.offset += 2
        context.col += 2
        lex(context)
      }
    '<' =>
      if offset + 1 >= str.length() || str[offset + 1] != '=' {
        tokens.push({ kind: LESS, raw: "<", pos: { row, col } })
        context.offset += 1
        context.col += 1
        lex(context)
      } else {
        tokens.push({ kind: LE, raw: "<=", pos: { row, col } })
        context.offset += 2
        context.col += 2
        lex(context)
      }
    ch =>
      if is_digit(ch) {
        lex_number(context)
      } else if is_alpha(ch) {
        lex_alpha(context)
      } else {
        return 1
      }
  }
}




//   let context = {
//     str: "let",
//     offset: 0,
//     row: 0,
//     col: 0,
//     tokens: Array::new(capacity=10)
//   }
//   lex(context)
//   inspect!(context.tokens, content="[{kind: LET, raw: \"let\", pos: {row: 0, col: 0}}]")
// }

