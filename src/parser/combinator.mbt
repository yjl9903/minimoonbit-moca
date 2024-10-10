typealias Token = @lex.Token

typealias Syntax = @types.Syntax

typealias Type = @types.Type

type Parser[V] (ArrayView[Token]) -> (V, ArrayView[Token])?

fn ptoken(predicate : (Token) -> Bool) -> Parser[Token] {
  fn {
    [hd, .. as tl] =>
      if predicate(hd) {
        // debug("hd:\{hd}")
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
    // debug("Many")
    // debug(input)
    // debug(self.parse(input))
    loop self.parse(input) {
      None => Some((cumul, rest))
      Some((v, rest_)) => {
        // debug("Many")
        // debug(rest_)
        // debug(self.parse(rest_))
        cumul.push(v)
        rest = rest_
        continue self.parse(rest_)
      }
    }
  }
}

fn any[Value : Show](self : Parser[Value]) -> Parser[Value?] {
  fn(input) {
    let cumul = []
    let mut rest = input
    match self.parse(input) {
      None => Some((None, rest))
      Some((v, rest_)) => {
        cumul.push(v)
        rest = rest_
        Some((Some(v), rest_))
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
