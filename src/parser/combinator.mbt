typealias Token = @lex.Token

typealias Syntax = @types.Syntax

typealias Type = @types.Type

typealias TokenKind = @lex.TokenKind

type Parser[V] (State) -> V!ParseError

fn Parser::parse[V](self : Parser[V], state : State) -> V!ParseError {
  (self._)!(state)
}

fn State::parse[V](self : State, parser : Parser[V]) -> V!ParseError {
  (parser._)!(self)
}

fn or[V](parsers : Array[Parser[V]]) -> Parser[V] {
  fn {
    state => {
      let store = state.cursor
      for i = 0; i < parsers.length(); i = i + 1 {
        let parser = parsers[i]
        let result = parser.parse?(state)
        match result {
          Ok(value) => return value
          _ => state.cursor = store
        }
      }
      raise ParseError("")
    }
  }
}

fn many[V](parser : Parser[V]) -> Parser[Array[V]] {
  fn {
    state => {
      let results : Array[V] = []
      while true {
        let store = state.cursor
        let result = (parser._)?(state)
        match result {
          Ok(value) => results.push(value)
          Err(_) => {
            state.cursor = store
            break
          }
        }
      }
      results
    }
  }
}

fn any[V](parser : Parser[V]) -> Parser[V?] {
  fn {
    state => {
      let store = state.cursor
      let result = (parser._)?(state)
      match result {
        Ok(value) => return Some(value)
        Err(_) => {
          state.cursor = store
          return None
        }
      }
    }
  }
}
