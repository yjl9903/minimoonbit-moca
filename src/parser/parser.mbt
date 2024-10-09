typealias Token = @lex.Token

typealias Syntax = @types.Syntax

typealias Type = @types.Type

type Parser[V] (ArrayView[Token]) -> (V, ArrayView[Token])?

fn ptoken(predicate : (Token) -> Bool) -> Parser[Token] {
  fn {
    [hd, .. as tl] =>
      if predicate(hd) {
        println("hd:\{hd}")
        Some((hd, tl))
      } else {
        None
      }
    [] => None
  }
}

fn map[I, O](self : Parser[I], f : (I) -> O) -> Parser[O] {
  fn {
    input =>
      match self.parse(input) {
        Some((token, rest)) => Some((f(token), rest))
        None => None
      }
  }
}

fn and[V1, V2](self : Parser[V1], parser2 : Parser[V2]) -> Parser[(V1, V2)] {
  fn {
    input =>
      self
      .parse(input)
      .bind(
        fn {
          (value, rest) =>
            parser2
            .parse(rest)
            .map(fn { (value2, rest2) => ((value, value2), rest2) })
        },
      )
  }
}

fn or[Value](self : Parser[Value], parser2 : Parser[Value]) -> Parser[Value] {
  fn {
    input =>
      match self.parse(input) {
        None => parser2.parse(input)
        Some(_) as result => result
      }
  }
}

fn many[Value : Show](self : Parser[Value]) -> Parser[Array[Value]] {
  fn(input) {
    let cumul = []
    let mut rest = input
    println("Many")
    // println(input)
    // println(self.parse(input))
    loop self.parse(input) {
      None => Some((cumul, rest))
      Some((v, rest_)) => {
        println("Many")
        // println(rest_)
        // println(self.parse(rest_))
        cumul.push(v)
        rest = rest_
        continue self.parse(rest_)
      }
    }
  }
}

fn parse[V](
  self : Parser[V],
  tokens : ArrayView[Token]
) -> (V, ArrayView[Token])? {
  (self._)(tokens)
}

fn Parser::ref[Value](ref : Ref[Parser[Value]]) -> Parser[Value] {
  fn(input) { ref.val.parse(input) }
}

fn prog(tokens : ArrayView[Token]) -> (Syntax, ArrayView[Token])? {
  Parser(top_level)
  .many()
  .map(
    // fn(fn(e, list[0]), list[1])
    fn {
      list => {
        // [(,), (,)]
        let mut result = list[list.length() - 1]
        for i = list.length() - 2; i >= 0; i = i - 1 {
          result = match list[i] {
            Let((p1, p2), p3, _) => Let((p1, p2), p3, result)
            LetRec(p1, _) => LetRec(p1, result)
          }
        }
        println("prog fold: \{list} -> \{result}")
        result
      }
    },
  )
  .parse(tokens)
}

fn top_level(tokens : ArrayView[Token]) -> (Syntax, ArrayView[Token])? {
  Parser(top_let_decl)
  // .or(toplevel_fn_decl)
  .parse(tokens)
}

fn top_let_decl(tokens : ArrayView[Token]) -> (Syntax, ArrayView[Token])? {
  token_let
  .and(token_identifier)
  .and(token_colon)
  .and(value_type)
  .and(token_assign)
  .and(expr)
  .and(token_semicolon)
  .map(
    fn {
      ((((((_, id), colon), value_ty), asi), exp), semi_colon) =>
        Syntax::Let((id, value_ty), exp, Unit)
    },
  )
  .parse(tokens)
}

// fn toplevel_fn_decl(tokens : ArrayView[Token]) -> (Syntax, ArrayView[Token])? {

// }

fn value_type(tokens : ArrayView[Token]) -> (Type, ArrayView[Token])? {
  token_int.parse(tokens)
}

fn expr(tokens : ArrayView[Token]) -> (Syntax, ArrayView[Token])? {
  // token_number.parse(tokens)
  Parser(add_sub_level_expr)
  .or(
    Parser(add_sub_level_expr)
    .and(token_eq)
    .and(add_sub_level_expr)
    .map(fn { ((lhs, _), rhs) => Syntax::Eq(lhs, rhs) }),
  )
  .or(
    Parser(add_sub_level_expr)
    .and(token_le)
    .and(add_sub_level_expr)
    .map(fn { ((lhs, _), rhs) => Syntax::LE(lhs, rhs) }),
  )
  .parse(tokens)
}

fn add_sub_level_expr(tokens : ArrayView[Token]) -> (Syntax, ArrayView[Token])? {
  Parser(mul_div_level_expr)
  .and(token_add)
  .and(add_sub_level_expr)
  .map(fn { ((lhs, op), rhs) => Syntax::Prim(lhs, rhs, op, kind=None) })
  .or(
    Parser(mul_div_level_expr)
    .and(token_sub)
    .and(add_sub_level_expr)
    .map(fn { ((lhs, op), rhs) => Syntax::Prim(lhs, rhs, op, kind=None) }),
  )
  .or(mul_div_level_expr)
  .parse(tokens)
}

fn mul_div_level_expr(tokens : ArrayView[Token]) -> (Syntax, ArrayView[Token])? {
  Parser(if_level_expr)
  .and(token_mul)
  .and(mul_div_level_expr)
  .map(fn { ((lhs, op), rhs) => Syntax::Prim(lhs, rhs, op, kind=None) })
  .or(
    Parser(if_level_expr)
    .and(token_div)
    .and(mul_div_level_expr)
    .map(fn { ((lhs, op), rhs) => Syntax::Prim(lhs, rhs, op, kind=None) }),
  )
  .or(Parser(if_level_expr))
  .parse(tokens)
}

fn if_level_expr(tokens : ArrayView[Token]) -> (Syntax, ArrayView[Token])? {
  token_number.parse(tokens)
}

// fn get_or_apply_level_expr(tokens : ArrayView[Token]) -> (Syntax, ArrayView[Token])? {

// }

// fn if_expr(tokens : ArrayView[Token]) -> (Syntax, ArrayView[Token])? {

// }

// fn block_expr()

let parser : Parser[Syntax] = Parser(prog)

test {
  let input = "let i : Int = 1 + 3 * 3 + 1;"
  let context = @lex.Context::new(input)
  let ok = @lex.lex(context)
  println(context.tokens)
  let (expr, _) = parser.parse(context.tokens[:]).unwrap()
  println(expr)
}

let token_lparen : Parser[Token] = ptoken(
  fn {
    input =>
      match input.kind {
        LPAREN => true
        _ => false
      }
  },
)

let token_rparen : Parser[Token] = ptoken(
  fn {
    input =>
      match input.kind {
        RPAREN => true
        _ => false
      }
  },
)

let token_lbracket : Parser[Token] = ptoken(
  fn {
    input =>
      match input.kind {
        LBRACKET => true
        _ => false
      }
  },
)

let token_rbracket : Parser[Token] = ptoken(
  fn {
    input =>
      match input.kind {
        RBRACKET => true
        _ => false
      }
  },
)

let token_lcurlybracket : Parser[Token] = ptoken(
  fn {
    input =>
      match input.kind {
        LCURLYBRACKET => true
        _ => false
      }
  },
)

let token_rcurlybracket : Parser[Token] = ptoken(
  fn {
    input =>
      match input.kind {
        RCURLYBRACKET => true
        _ => false
      }
  },
)

let token_number : Parser[Syntax] = ptoken(
  fn {
    input =>
      match input.kind {
        NUMBER(_) => true
        _ => false
      }
  },
).map(
  fn {
    token =>
      match token.kind {
        NUMBER(value) => Syntax::Int(value)
        _ => Syntax::Unit // TODO
      }
  },
)

let token_identifier : Parser[String] = ptoken(
  fn {
    input =>
      match input.kind {
        IDENTIFIER(_) => true
        _ => false
      }
  },
).map(
  fn {
    token =>
      match token.kind {
        IDENTIFIER(value) => value
        _ => "Syntax::Unit" // TODO
      }
  },
)

let token_true : Parser[Syntax] = ptoken(
  fn {
    input =>
      match input.kind {
        TRUE => true
        _ => false
      }
  },
).map(fn { _ => Syntax::Bool(true) })

let token_false : Parser[Syntax] = ptoken(
  fn {
    input =>
      match input.kind {
        FALSE => true
        _ => false
      }
  },
).map(fn { _ => Syntax::Bool(false) })

let token_unit : Parser[Syntax] = ptoken(
  fn {
    input =>
      match input.kind {
        UNIT => true
        _ => false
      }
  },
).map(fn { _ => Syntax::Unit })

let token_bool : Parser[Type] = ptoken(
  fn {
    input =>
      match input.kind {
        BOOL => true
        _ => false
      }
  },
).map(fn { _ => Type::Bool })

let token_int : Parser[Type] = ptoken(
  fn {
    input =>
      match input.kind {
        INT => true
        _ => false
      }
  },
).map(fn { _ => Type::Int })

let token_double : Parser[Type] = ptoken(
  fn {
    input =>
      match input.kind {
        DOUBLE => true
        _ => false
      }
  },
).map(fn { _ => Type::Double })

let token_array : Parser[Token] = ptoken(
  fn {
    input =>
      match input.kind {
        ARRAY => true
        _ => false
      }
  },
)

let token_not : Parser[Token] = ptoken(
  fn {
    input =>
      match input.kind {
        NOT => true
        _ => false
      }
  },
)

let token_if : Parser[Token] = ptoken(
  fn {
    input =>
      match input.kind {
        IF => true
        _ => false
      }
  },
)

let token_let : Parser[Token] = ptoken(
  fn {
    input =>
      match input.kind {
        LET => true
        _ => false
      }
  },
)

let token_colon : Parser[Token] = ptoken(
  fn {
    input =>
      match input.kind {
        COLON => true
        _ => false
      }
  },
)

let token_eq : Parser[Token] = ptoken(
  fn {
    input =>
      match input.kind {
        EQ => true
        _ => false
      }
  },
)

let token_le : Parser[Token] = ptoken(
  fn {
    input =>
      match input.kind {
        LE => true
        _ => false
      }
  },
)

let token_assign : Parser[Token] = ptoken(
  fn {
    input =>
      match input.kind {
        ASSIGN => true
        _ => false
      }
  },
)

let token_semicolon : Parser[Token] = ptoken(
  fn {
    input =>
      match input.kind {
        SEMICOLON => true
        _ => false
      }
  },
)

// TODO
let token_add : Parser[@types.Op] = ptoken(
  fn {
    input =>
      match input.kind {
        ADD => true
        _ => false
      }
  },
).map(fn { _ => @types.Op::Add })

let token_sub : Parser[@types.Op] = ptoken(
  fn {
    input =>
      match input.kind {
        SUB => true
        _ => false
      }
  },
).map(fn { _ => @types.Op::Sub })

let token_mul : Parser[@types.Op] = ptoken(
  fn {
    input =>
      match input.kind {
        MUL => true
        _ => false
      }
  },
).map(fn { _ => @types.Op::Mul })

let token_div : Parser[@types.Op] = ptoken(
  fn {
    input =>
      match input.kind {
        DIV => true
        _ => false
      }
  },
).map(fn { _ => @types.Op::Div })
