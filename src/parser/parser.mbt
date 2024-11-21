type! ParseError String

struct State {
  input : Array[Token]
  mut cursor : Int
}

fn State::new(input : Array[Token]) -> State {
  { input, cursor: 0 }
}

fn State::next(self : State) -> Token!ParseError {
  let cursor = self.cursor
  if self.empty() {
    raise ParseError("Next -> Tokens are already empty !")
  }
  self.cursor = self.cursor + 1
  self.input[cursor]
}

fn State::empty(self : State) -> Bool {
  self.cursor >= self.input.length()
}

fn State::accept(self : State, token : @lex.TokenKind) -> Unit!ParseError {
  if self.next!().kind == token {
    ()
  } else {
    raise ParseError(
      "Accept -> Except : \{token},but get : \{self.input[self.cursor - 1].kind} !",
    )
  }
}

fn State::try_parse(self : State, token : @lex.TokenKind) -> Bool {
  self.empty() == false && self.input[self.cursor].kind == token
}

fn State::peek(self : State) -> Token!ParseError {
  if self.empty() {
    raise ParseError("Peek -> Tokens are already empty !")
  }
  self.input[self.cursor]
}

fn prog(state : State) -> Syntax!ParseError {
  let list = state.parse!(many(top_level))
  if state.empty() {
    let mut result = list[list.length() - 1]
    for i = list.length() - 2; i >= 0; i = i - 1 {
      result = match list[i] {
        Let((p1, p2), p3, _) => Let((p1, p2), p3, result)
        LetRec(p1, _) => LetRec(p1, result)
        LetEnum(p1, _) => LetEnum(p1, result)
        _ => Syntax::Unit
      }
    }
    result
  } else {
    raise ParseError("Prog rest: \{state.peek!()}")
  }
}

fn top_level(state : State) -> Syntax!ParseError {
  if state.try_parse(TokenKind::LET) {
    state.parse!(top_let_decl)
  } else if state.try_parse(TokenKind::FN) {
    state.parse!(toplevel_fn_decl)
  } else if state.try_parse(TokenKind::ENUM) {
    state.parse!(top_enum_decl)
  } else {
    raise ParseError(
      "top_level parse Error -> Except : let or fn \ but get \{state.peek!()}",
    )
  }
}

fn enum_tuple(state : State) -> @types.EnumKind!ParseError {
  let name = state.peek!().raw
  state.accept!(TokenKind::IDENTIFIER)
  if state.try_parse(TokenKind::LPAREN) {
    let fields = match state.parse!(tuple_type_or_function_type) {
      Type::Tuple(array) => array
      error =>
        raise ParseError("Type Error : Except tuple type ,but get \{error}")
    }
    let result : @types.EnumKind = { name, fields }
    result
  } else {
    let result : @types.EnumKind = { name, fields: [] }
    result
  }
}

fn top_enum_decl(state : State) -> Syntax!ParseError {
  state.accept!(TokenKind::ENUM)
  let name = state.peek!().raw
  state.accept!(TokenKind::IDENTIFIER)
  if not(name[0].compare('A') >= 0 && name[0].compare('Z') <= 0) {
    raise ParseError("Enum must start with upper char !")
  }
  state.accept!(TokenKind::LCURLYBRACKET)
  let kinds = state.parse!(many(enum_tuple))
  state.accept!(TokenKind::RCURLYBRACKET)
  state.accept!(TokenKind::SEMICOLON)
  let result : @types.EnumDef = { name, kinds }
  Syntax::LetEnum(result, Syntax::Unit)
}

fn top_let_decl(state : State) -> Syntax!ParseError {
  state.accept!(TokenKind::LET)
  let id = state.peek!().raw
  debug("ID: \{id}")
  state.accept!(TokenKind::IDENTIFIER)
  state.accept!(TokenKind::COLON)
  let value_ty = state.parse!(value_type)
  debug("\{id} : \{value_ty}")
  state.accept!(TokenKind::ASSIGN)
  let exp = state.parse!(expr)
  state.accept!(TokenKind::SEMICOLON)
  debug("top_let_decl -> id : \{id}, type:\{value_ty} expr : \{exp} \n")
  Syntax::Let((id, value_ty), exp, Unit)
}

fn toplevel_fn_decl(state : State) -> Syntax!ParseError {
  state.accept!(TokenKind::FN)
  let raw = state.peek!().raw
  state.accept!(TokenKind::IDENTIFIER)
  if raw == "main" || raw == "init" {
    let body = state.parse!(fn_body)
    let func : @types.Fundef = {
      id: @types.generate_fun_def_id(),
      name: (raw, Type::Fun([], Type::Unit)),
      args: [],
      body,
    }
    debug("Main_fn_decl -> \{func}\n")
    state.accept!(TokenKind::SEMICOLON)
    Syntax::LetRec(func, Syntax::Unit)
  } else {
    let generics = state.parse!(any(generic_type))
    state.accept!(TokenKind::LPAREN)
    let args = state.parse!(any(param_list))
    state.accept!(TokenKind::RPAREN)
    state.accept!(TokenKind::ARROW)
    debug("args:" + args.to_string())
    let func_type = state.parse!(value_type)
    let body = state.parse!(fn_body)
    let args = match args {
      Some(val) => val
      None => []
    }
    let return_type = match generics {
      Some(array) =>
        Type::Pi(
          array.map(fn { a => (a, @types.generate_type_params_id()) }),
          Type::Fun(args.map(fn { a => a.1 }), func_type),
        )
      None => Type::Fun(args.map(fn { a => a.1 }), func_type)
    }
    let func : @types.Fundef = {
      id: @types.generate_fun_def_id(),
      name: (raw, return_type),
      args,
      body,
    }
    state.accept!(TokenKind::SEMICOLON)
    debug("Top_fn_decl -> \{func}\n")
    Syntax::LetRec(func, Syntax::Unit)
  }
}

fn generic_type(state : State) -> Array[String]!ParseError {
  state.accept!(TokenKind::LBRACKET)
  let id = state.peek!().raw
  state.accept!(TokenKind::IDENTIFIER)
  let generics = state.parse!(
    many(
      fn {
        s => {
          s.accept!(TokenKind::COMMA)
          let generic = state.peek!().raw
          state.accept!(TokenKind::IDENTIFIER)
          generic
        }
      },
    ),
  )
  state.accept!(TokenKind::RBRACKET)
  [id, ..generics]
}

fn fn_body(state : State) -> Syntax!ParseError {
  state.accept!(TokenKind::LCURLYBRACKET)
  let body = state.parse!(stmt)
  debug("body: \{body}")
  state.accept!(TokenKind::RCURLYBRACKET)
  return body
}

fn stmt(state : State) -> Syntax!ParseError {
  if state.try_parse(TokenKind::LET) {
    // LL(2) can Optimize
    return state.parse!(or([let_tuple_stmt, let_stmt]))
  } else if state.try_parse(TokenKind::FN) {
    return state.parse!(fn_decl_stmt)
  }
  return state.parse!(or([assign_stmt, expr_stmt]))
}

fn let_tuple_stmt(state : State) -> Syntax!ParseError {
  state.accept!(TokenKind::LET)
  state.accept!(TokenKind::LPAREN)
  let id = state.peek!().raw
  state.accept!(TokenKind::IDENTIFIER)
  let list = state.parse!(
    many(
      fn {
        s => {
          s.accept!(TokenKind::COMMA)
          let item = s.peek!().raw
          s.accept!(TokenKind::IDENTIFIER)
          return item
        }
      },
    ),
  )
  state.accept!(TokenKind::RPAREN)
  let identifiers = [id, ..list]
  debug("identifier: \{identifiers}")
  let annotation = state.parse!(any(type_annotation))
  state.accept!(TokenKind::ASSIGN)
  debug("annotation: \{annotation}")
  let e = state.parse!(expr)
  debug("e : \{e}")
  state.accept!(TokenKind::SEMICOLON)
  let rest = state.parse!(stmt)
  debug("rest: \{rest}")
  let types = match annotation {
    None => []
    Some(val) =>
      match val {
        Tuple(array) => array
        _ => []
      }
  }
  let res : Array[(String, Type)] = []
  if identifiers.length() == types.length() {
    for i = 0; i < identifiers.length(); i = i + 1 {
      res.push((identifiers[i], types[i]))
    }
  } else {
    for i = 0; i < identifiers.length(); i = i + 1 {
      res.push((identifiers[i], Type::Var({ val: None })))
    }
  }
  let result = Syntax::LetTuple(res, e, rest)
  debug("let_tuple_stmt: -> \{result}\n")
  result
}

fn let_stmt(state : State) -> Syntax!ParseError {
  state.accept!(TokenKind::LET)
  let id = state.peek!().raw
  state.accept!(TokenKind::IDENTIFIER)
  let ty = state.parse!(any(type_annotation))
  state.accept!(TokenKind::ASSIGN)
  let exp = state.parse!(expr)
  state.accept!(TokenKind::SEMICOLON)
  let rest = state.parse!(stmt)
  let t : Type = match ty {
    None => Type::Var({ val: None })
    Some(val) => val
  }
  let result = Syntax::Let((id, t), exp, rest)
  debug("let_stmt: -> \{result}\n")
  result
}

fn fn_decl_stmt(state : State) -> Syntax!ParseError {
  let func = state.parse!(nontop_fn_decl)
  state.accept!(TokenKind::SEMICOLON)
  let rest = state.parse!(stmt)
  let result = Syntax::LetRec(func, rest)
  debug("fn_decl_stmt: -> \{result}\n")
  result
}

fn nontop_fn_decl(state : State) -> @types.Fundef!ParseError {
  state.accept!(TokenKind::FN)
  let raw = state.peek!().raw
  state.accept!(TokenKind::IDENTIFIER)
  state.accept!(TokenKind::LPAREN)
  let args = state.parse!(any(nontop_param_list))
  state.accept!(TokenKind::RPAREN)
  let func_type = state.parse!(
    any(
      fn {
        s => {
          s.accept!(TokenKind::ARROW)
          let func_type = s.parse!(value_type)
          return func_type
        }
      },
    ),
  )
  let body = state.parse!(fn_body)
  let args = match args {
    Some(val) => val
    None => []
  }
  let ty = match func_type {
    None => Type::Var({ val: None })
    Some(val) => val
  }
  let func : @types.Fundef = {
    id: @types.generate_fun_def_id(),
    name: (raw, Type::Fun(args.map(fn { a => a.1 }), ty)),
    args,
    body,
  }
  debug("Nontop_fn_decl -> \{func}\n")
  func
}

fn nontop_param_list(state : State) -> Array[(String, Type)]!ParseError {
  let e = state.parse!(nontop_param)
  let list = state.parse!(
    many(
      fn {
        s => {
          s.accept!(TokenKind::COMMA)
          s.parse!(nontop_param)
        }
      },
    ),
  )
  return [e, ..list]
}

fn nontop_param(state : State) -> (String, Type)!ParseError {
  let id = state.peek!().raw
  state.accept!(TokenKind::IDENTIFIER)
  let ty = state.parse!(any(type_annotation))
  let t = match ty {
    None => Type::Var({ val: None })
    Some(val) => val
  }
  let result = (id, t)
  debug("nontop_param: -> \{result}\n")
  result
}

fn assign_stmt(state : State) -> Syntax!ParseError {
  // x[y] = z;
  let e1 = state.parse!(get_expr)
  state.accept!(TokenKind::ASSIGN)
  let e2 = state.parse!(expr)
  state.accept!(TokenKind::SEMICOLON)
  let e3 = state.parse!(stmt)
  match e1 {
    Get(arr, idx) => {
      let result = Syntax::Put(arr, idx, e2)
      debug("assign_stmt: -> \{result}\n")
      @types.Syntax::Let(("_", Type::Unit), result, e3)
    }
    _ => @util.die("should put array")
  }
}

fn get_expr(state : State) -> Syntax!ParseError {
  let result = state.parse!(get_or_apply_level_expr)
  match result {
    Syntax::Get(_, _) => return result
    _ => raise ParseError("Get_expr error -> It must be identifier[expr]")
  }
}

fn lowel_level_expr(state : State) -> Syntax!ParseError {
  if state.try_parse(TokenKind::LBRACKET) {
    state.accept!(TokenKind::LBRACKET)
    let result = state.parse!(expr)
    state.accept!(TokenKind::RBRACKET)
    let result = Syntax::Get(Syntax::Unit, result)
    debug("[] lowel_level_expr: -> \{result}\n")
    return result
  } else if state.try_parse(TokenKind::LPAREN) {
    state.accept!(TokenKind::LPAREN)
    let v = state.parse!(
      any(
        fn {
          s1 => {
            let e = s1.parse!(expr)
            let list = s1.parse!(
              many(
                fn {
                  s => {
                    s.accept!(TokenKind::COMMA)
                    s.parse!(expr)
                  }
                },
              ),
            )
            return [e, ..list]
          }
        },
      ),
    )
    state.accept!(TokenKind::RPAREN)
    let array = match v {
      Some(val) => val
      _ => []
    }
    let result = Syntax::App(Syntax::Unit, [], array)
    debug("() lowel_level_expr :  \{result}")
    return result
  }
  raise ParseError(
    "lowel_level_expr Error -> Except : '(' or '[' but got \{state.peek!()}",
  )
}

fn get_or_apply_level_expr(state : State) -> Syntax!ParseError {
  let val = state.parse!(value_expr)
  let list = state.parse!(many(lowel_level_expr))
  let result = list.fold(
    init=val,
    fn {
      val, expr =>
        match expr {
          Syntax::Get(_, rest) => Syntax::Get(val, rest)
          Syntax::App(_, typs, rest) => Syntax::App(val, typs, rest)
          _ => Syntax::Unit
        }
    },
  )
  debug("get_or_apply_level_expr: -> \{result} val: \{val}")
  result
}

fn expr_stmt(state : State) -> Syntax!ParseError {
  state.parse!(expr)
}

fn param_list(state : State) -> Array[(String, Type)]!ParseError {
  let e = state.parse!(param)
  let list = state.parse!(
    many(
      fn {
        s => {
          s.accept!(TokenKind::COMMA)
          s.parse!(param)
        }
      },
    ),
  )
  debug("Param List -> \{[e,..list]}")
  [e, ..list]
}

fn param(state : State) -> (String, Type)!ParseError {
  debug("type_annotation")
  let id = state.peek!().raw
  state.accept!(TokenKind::IDENTIFIER)
  let ty = state.parse!(type_annotation)
  (id, ty)
}

fn type_annotation(state : State) -> Type!ParseError {
  state.accept!(TokenKind::COLON)
  let ty = state.parse!(value_type)
  ty
}

fn value_type(state : State) -> Type!ParseError {
  if state.try_parse(TokenKind::UNIT) {
    state.accept!(TokenKind::UNIT)
    return Type::Unit
  } else if state.try_parse(TokenKind::BOOL) {
    state.accept!(TokenKind::BOOL)
    return Type::Bool
  } else if state.try_parse(TokenKind::INT) {
    state.accept!(TokenKind::INT)
    return Type::Int
  } else if state.try_parse(TokenKind::DOUBLE) {
    state.accept!(TokenKind::DOUBLE)
    return Type::Double
  } else if state.try_parse(TokenKind::ARRAY) {
    return state.parse!(array_type)
  } else if state.try_parse(TokenKind::LPAREN) {
    return state.parse!(tuple_type_or_function_type)
  } else if state.try_parse(TokenKind::IDENTIFIER) {
    let ty = state.peek!().raw
    state.accept!(TokenKind::IDENTIFIER)
    return Type::Identifier(ty)
  }
  raise ParseError("Error value type !")
}

fn array_type(state : State) -> Type!ParseError {
  state.accept!(TokenKind::ARRAY)
  state.accept!(TokenKind::LBRACKET)
  let val = state.parse!(value_type)
  state.accept!(TokenKind::RBRACKET)
  debug("Array_type -> Array[\{val}]")
  Type::Array(val)
}

fn tuple_type_or_function_type(state : State) -> Type!ParseError {
  debug("Into tuple_type_or_function_type , peek : \{state.peek!()}")
  state.accept!(TokenKind::LPAREN)
  let t1 = state.parse!(value_type)
  debug("t1: \{t1}")
  let list = state.parse!(
    many(
      fn {
        s => {
          s.accept!(TokenKind::COMMA)
          s.parse!(value_type)
        }
      },
    ),
  )
  state.accept!(TokenKind::RPAREN)
  let array = [t1, ..list]
  debug("array: \{array}")
  if state.try_parse(TokenKind::ARROW) {
    state.accept!(TokenKind::ARROW)
    let fun_type = state.parse!(value_type)
    return Type::Fun(array, fun_type)
  }
  Type::Tuple(array)
}

fn expr(state : State) -> Syntax!ParseError {
  let lhs = state.parse!(add_sub_level_expr)
  let mut flag = 0
  if state.try_parse(TokenKind::EQ) {
    state.accept!(TokenKind::EQ)
    flag = 1
  } else if state.try_parse(TokenKind::LE) {
    state.accept!(TokenKind::LE)
    flag = 2
  } else {
    return lhs
  }
  let rhs = state.parse!(add_sub_level_expr)
  if flag == 1 {
    Syntax::Eq(lhs, rhs)
  } else {
    Syntax::LE(lhs, rhs)
  }
}

// add ::= item rhs

fn get_op_prec(op : TokenKind) -> Int {
  match op {
    TokenKind::ADD | TokenKind::SUB => 20
    TokenKind::MUL | TokenKind::DIV => 40
    _ => -1
  }
}

fn add_sub_level_expr(state : State) -> Syntax!ParseError {
  let i1 = state.parse!(if_level_expr)
  fn bin_op_rhs(
    state : State,
    expr_prec : Int,
    lhs : Syntax
  ) -> Syntax?!ParseError {
    let mut lhs = lhs
    while true {
      let tok_prec = get_op_prec(state.peek!().kind)
      if tok_prec < expr_prec {
        return Some(lhs)
      }
      let mut op = @types.Op::Add
      if state.try_parse(TokenKind::ADD) {
        state.accept!(TokenKind::ADD)
        op = @types.Op::Add
      } else if state.try_parse(TokenKind::SUB) {
        state.accept!(TokenKind::SUB)
        op = @types.Op::Sub
      } else if state.try_parse(TokenKind::MUL) {
        state.accept!(TokenKind::MUL)
        op = @types.Op::Mul
      } else if state.try_parse(TokenKind::DIV) {
        state.accept!(TokenKind::DIV)
        op = @types.Op::Div
      } else {
        raise ParseError("Error Op!")
      }
      debug("Op: \{op},lhs: \{lhs}")
      let mut rhs = Syntax::Unit
      rhs = state.parse!(if_level_expr)
      debug("rhs : \{rhs}")
      let next_prec = get_op_prec(state.peek!().kind)
      if tok_prec < next_prec {
        try {
          rhs = match bin_op_rhs!(state, tok_prec + 1, rhs) {
            Some(val) => val
            _ => raise ParseError("rhs parse error")
          }
        } catch {
          _ => return None
        }
      }
      debug("lhs : \{lhs},rhs : \{rhs},op : \{op}")
      lhs = Syntax::Prim(lhs, rhs, op, kind=None)
    }
    raise ParseError("Unreachable Code")
  }

  match bin_op_rhs!(state, 0, i1) {
    Some(val) => val
    _ => raise ParseError("add_sub_level_expr parse Error")
  }
}

fn if_level_expr(state : State) -> Syntax!ParseError {
  if state.try_parse(TokenKind::IF) {
    state.accept!(TokenKind::IF)
    let e1 = state.parse!(expr)
    state.accept!(TokenKind::LCURLYBRACKET)
    let e2 = state.parse!(stmt)
    state.accept!(TokenKind::RCURLYBRACKET)
    debug("e1: \{e1} \ne2: \{e2}")
    debug("peek: \{state.peek!()}")
    let e3 = state.parse!(
      any(
        fn {
          s => {
            s.accept!(TokenKind::ELSE)
            debug("!!!!!!!!!!!!!!!!")
            s.accept!(TokenKind::LCURLYBRACKET)
            let e3 = state.parse!(stmt)
            debug("e3 : \{e3}")
            s.accept!(TokenKind::RCURLYBRACKET)
            return e3
          }
        },
      ),
    )
    let e = match e3 {
      None => Syntax::Unit
      Some(v) => v
    }
    let result = Syntax::If(e1, e2, e)
    debug("if_expr: -> \{result}\n")
    result
  } else {
    let result = state.parse!(
      or(
        [
          get_or_apply_level_expr,
          fn {
            s => {
              s.accept!(TokenKind::LPAREN)
              let res = s.parse!(expr)
              s.accept!(TokenKind::RPAREN)
              res
            }
          },
        ],
      ),
    )
    debug("If_level_expr : \{result}")
    result
  }
}

fn unit_expr(state : State) -> Syntax!ParseError {
  state.accept!(TokenKind::LPAREN)
  state.accept!(TokenKind::RPAREN)
  return Syntax::Unit
}

fn tuple_expr(state : State) -> Syntax!ParseError {
  state.accept!(TokenKind::LPAREN)
  let e1 = state.parse!(expr)
  state.accept!(TokenKind::COMMA)
  let e2 = state.parse!(expr)
  let list = state.parse!(
    many(
      fn {
        s => {
          s.accept!(COMMA)
          s.parse!(expr)
        }
      },
    ),
  )
  state.accept!(TokenKind::RPAREN)
  let result = Syntax::Tuple([e1, e2, ..list])
  debug("tuple_expr: -> \{result}\n")
  result
}

fn pattern(state : State) -> @types.Pattern!ParseError {
  if state.try_parse(TokenKind::LPAREN) {
    state.accept!(TokenKind::LPAREN)
    if state.try_parse(TokenKind::RPAREN) {
      state.accept!(TokenKind::RPAREN)
      return @types.Pattern::Unit
    } else {
      let e = state.parse!(pattern)
      let list = state.parse!(
        many(
          fn {
            s => {
              s.accept!(TokenKind::COMMA)
              s.parse!(pattern)
            }
          },
        ),
      )
      state.accept!(TokenKind::RPAREN)
      return @types.Pattern::Tuple([e, ..list])
    }
  } else if state.try_parse(TokenKind::FALSE) {
    state.accept!(TokenKind::FALSE)
    return @types.Pattern::Bool(false)
  } else if state.try_parse(TokenKind::TRUE) {
    state.accept!(TokenKind::TRUE)
    return @types.Pattern::Bool(true)
  } else if state.try_parse(TokenKind::NUMBER) ||
    state.try_parse(TokenKind::SUB) { // Double ,int 
    let mut op = 1
    if state.try_parse(TokenKind::SUB) {
      state.accept!(TokenKind::SUB)
      op = -1
    }
    let lhs = state.peek!().raw
    state.accept!(TokenKind::NUMBER)
    if state.try_parse(TokenKind::DOT) {
      state.accept!(TokenKind::DOT)
      if state.try_parse(TokenKind::NUMBER) {
        let rhs = state.peek!().raw
        state.accept!(TokenKind::NUMBER)
        return @types.Pattern::Double(
          op.to_double() * @strconv.parse_double?(lhs + "." + rhs).unwrap(),
        )
      } else {
        return @types.Pattern::Double(
          op.to_double() * @strconv.parse_double?(lhs + ".0").unwrap(),
        )
      }
    } else {
      return @types.Pattern::Int(op * @strconv.parse_int?(lhs).unwrap())
    }
  } else {
    let id1 = state.peek!().raw
    state.accept!(TokenKind::IDENTIFIER)
    if state.try_parse(TokenKind::COLON) {
      state.accept!(TokenKind::COLON)
      state.accept!(TokenKind::COLON)
      let id2 = state.peek!().raw
      state.accept!(TokenKind::IDENTIFIER)
      if state.try_parse(TokenKind::LPAREN) {
        state.accept!(TokenKind::LPAREN)
        let e = state.parse!(pattern)
        let list = state.parse!(
          many(
            fn {
              s => {
                s.accept!(TokenKind::COMMA)
                s.parse!(pattern)
              }
            },
          ),
        )
        state.accept!(TokenKind::RPAREN)
        @types.Pattern::Enum(id1, id2, [e, ..list])
      } else {
        @types.Pattern::Enum(id1, id2, [])
      }
    } else if id1 == "_" {
      @types.Pattern::Var(None, Var({ val: None }))
    } else {
      @types.Pattern::Var(Some(id1), Var({ val: None }))
    }
  }
}

fn match_expr(state : State) -> Syntax!ParseError {
  let raw = state.peek!().raw
  if raw != "match" {
    raise ParseError("match_expr Error -> Except : match , but got : \{raw}")
  }
  state.accept!(TokenKind::IDENTIFIER)
  let condition = state.parse!(expr)
  state.accept!(TokenKind::LCURLYBRACKET)
  let list = state.parse!(
    many(
      fn {
        s => {
          let lhs = s.parse!(pattern)
          s.accept!(TokenKind::RA)
          s.accept!(TokenKind::LCURLYBRACKET)
          let rhs = s.parse!(expr)
          s.accept!(TokenKind::RCURLYBRACKET)
          (lhs, rhs)
        }
      },
    ),
  )
  state.accept!(TokenKind::RCURLYBRACKET)
  Syntax::Match(condition, list)
}

fn enum_expr(state : State) -> Syntax!ParseError {
  let id1 = state.peek!().raw
  state.accept!(TokenKind::IDENTIFIER)
  state.accept!(TokenKind::COLON)
  state.accept!(TokenKind::COLON)
  let id2 = state.peek!().raw
  state.accept!(TokenKind::IDENTIFIER)
  if state.try_parse(TokenKind::LPAREN) {
    state.accept!(TokenKind::LPAREN)
    let e = state.parse!(expr)
    let list = state.parse!(
      many(
        fn {
          s => {
            s.accept!(TokenKind::COMMA)
            s.parse!(expr)
          }
        },
      ),
    )
    state.accept!(TokenKind::RPAREN)
    return Syntax::Enum(id1, id2, [e, ..list])
  } else {
    return Syntax::Enum(id1, id2, [])
  }
}

fn value_expr(state : State) -> Syntax!ParseError {
  if state.try_parse(TokenKind::LPAREN) {
    return state.parse!(
      or(
        [
          unit_expr,
          tuple_expr,
          fn {
            s => {
              s.accept!(TokenKind::LPAREN)
              let result = s.parse!(expr)
              s.accept!(TokenKind::RPAREN)
              debug("get_or_apply_level_expr: \{result}")
              result
            }
          },
          fn {
            s => {
              s.accept!(TokenKind::LPAREN)
              let result = s.parse!(get_or_apply_level_expr)
              debug("value_expr: \{result}")
              s.accept!(TokenKind::RPAREN)
              result
            }
          },
        ],
      ),
    )
  } else if state.try_parse(TokenKind::TRUE) {
    state.accept!(TokenKind::TRUE)
    return Syntax::Bool(true)
  } else if state.try_parse(TokenKind::FALSE) {
    state.accept!(TokenKind::FALSE)
    return Syntax::Bool(false)
  } else if state.try_parse(TokenKind::IDENTIFIER) {
    let id = state.peek!().raw
    if id == "match" {
      return state.parse!(match_expr)
    }
    return state.parse!(
      or(
        [
          enum_expr,
          fn {
            s => {
              s.accept!(TokenKind::IDENTIFIER)
              Syntax::Var(id)
            }
          },
        ],
      ),
    )
  } else if state.try_parse(TokenKind::SUB) { // neg_expr
    state.accept!(TokenKind::SUB)
    return Syntax::Neg(state.parse!(value_expr), kind=None)
  } else if state.try_parse(TokenKind::NUMBER) { // Double ,int 
    let lhs = state.peek!().raw
    state.accept!(TokenKind::NUMBER)
    if state.try_parse(TokenKind::DOT) {
      state.accept!(TokenKind::DOT)
      if state.try_parse(TokenKind::NUMBER) {
        let rhs = state.peek!().raw
        state.accept!(TokenKind::NUMBER)
        return Syntax::Double(@strconv.parse_double?(lhs + "." + rhs).unwrap())
      } else {
        return Syntax::Double(@strconv.parse_double?(lhs + ".0").unwrap())
      }
    } else {
      return Syntax::Int(@strconv.parse_int?(lhs).unwrap())
    }
  } else if state.try_parse(TokenKind::NOT) {
    state.accept!(TokenKind::NOT)
    state.accept!(TokenKind::LPAREN)
    let e = state.parse!(expr)
    state.accept!(TokenKind::RPAREN)
    return Syntax::Not(e)
  } else if state.try_parse(TokenKind::ARRAY) {
    state.accept!(TokenKind::ARRAY)
    state.accept!(TokenKind::COLON)
    state.accept!(TokenKind::COLON)
    let id = state.peek!().raw
    state.accept!(TokenKind::IDENTIFIER)
    if id != "make" {
      raise ParseError("Array_make Error -> Except : make , but got : \{id}")
    }
    state.accept!(TokenKind::LPAREN)
    let e1 = state.parse!(expr)
    state.accept!(TokenKind::COMMA)
    let e2 = state.parse!(expr)
    state.accept!(TokenKind::RPAREN)
    return Syntax::Array(e1, e2)
  } else if state.try_parse(TokenKind::LCURLYBRACKET) {
    state.accept!(TokenKind::LCURLYBRACKET)
    let result = state.parse!(stmt)
    state.accept!(TokenKind::RCURLYBRACKET)
    debug("block_expr: -> \{result}\n")
    return result
  }
  raise ParseError("Value_expr Error")
}

// -> main
pub fn parse_minimoonbit(source_code : String) -> Syntax {
  let input : String = source_code
  let context = @lex.Context::new(input)
  let ok = @lex.lex(context)
  let state = State::new(context.tokens)
  let mut result : Syntax = Syntax::Unit
  if ok == 1 {
    @util.die("failed at \{state.cursor}", tag=Some("Lex"))
  }
  try {
    result = state.parse!(prog)
  } catch {
    ParseError(e) => @util.die("\{e}", tag=Some("Parse"))
  }
  return result
}
