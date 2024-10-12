pub fn parse_minimoonbit(source_code : String) -> Syntax {
  let input : String = source_code
  let context = @lex.Context::new(input)
  let ok = @lex.lex(context)
  let parser : Parser[Syntax] = Parser(prog)
  // assert_eq!(ok, 0)
  let (expr, rest) = parser.parse(context.tokens[:]).unwrap()
  // assert_eq!(rest.length(), 0)
  if rest.length() != 0 {
    @util.die("Error: \{rest}")
  }
  return expr
}

fn prog(tokens : ArrayView[Token]) -> (Syntax, ArrayView[Token])? {
  Parser(top_level)
  .many()
  .map(
    fn {
      list => {
        // [(,), (,)]
        let mut result = list[list.length() - 1]
        for i = list.length() - 2; i >= 0; i = i - 1 {
          result = match list[i] {
            Let((p1, p2), p3, _) => Let((p1, p2), p3, result)
            LetRec(p1, _) => LetRec(p1, result)
            _ => Syntax::Unit
          }
        }
        debug("prog fold: \{list} -> \{result}\n")
        result
      }
    },
  )
  .parse(tokens)
}

fn top_level(tokens : ArrayView[Token]) -> (Syntax, ArrayView[Token])? {
  Parser(top_let_decl).or(toplevel_fn_decl).parse(tokens)
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
      ((((((_, id), _), value_ty), _), exp), _) => {
        let result = Syntax::Let((id, value_ty), exp, Unit)
        debug("top_let_decl fold: -> \{result}\n")
        result
      }
    },
  )
  .parse(tokens)
}

fn toplevel_fn_decl(tokens : ArrayView[Token]) -> (Syntax, ArrayView[Token])? {
  Parser(main_fn_decl)
  .and(token_semicolon)
  .map(
    fn {
      (func, _) => {
        let result = Syntax::LetRec(func, Syntax::Unit)
        debug("toplevel_fn_decl fold: \{func}-> \{result}\n")
        result
      }
    },
  )
  .or(
    Parser(top_fn_decl)
    .and(token_semicolon)
    .map(
      fn {
        (func, _) => {
          let result = Syntax::LetRec(func, Syntax::Unit)
          debug("toplevel_fn_decl fold: \{func} -> \{result}\n")
          result
        }
      },
    ),
  )
  .parse(tokens)
}

fn main_fn_decl(
  tokens : ArrayView[Token]
) -> (@types.Fundef, ArrayView[Token])? {
  token_fn
  .and(liter_main.or(liter_init))
  .and(fn_body)
  .map(
    fn {
      ((_, liter), body) => {
        let func : @types.Fundef = {
          name: (liter, Type::Fun([], Type::Unit)),
          args: [],
          body,
        }
        debug("main_fn_decl: -> \{func}\n")
        func
      }
    },
  )
  .parse(tokens)
}

fn top_fn_decl(tokens : ArrayView[Token]) -> (@types.Fundef, ArrayView[Token])? {
  debug("Into top func")
  token_fn
  .and(token_identifier)
  .and(token_lparen)
  .and(Parser(param_list).any())
  .and(token_rparen)
  .and(token_arrow)
  .and(value_type)
  .and(fn_body)
  .map(
    fn {
      (((((((_, id), _), args), _), _), ty), body) => {
        let args = match args {
          Some(val) => val
          None => []
        }
        let func : @types.Fundef = {
          name: (id, Type::Fun(args.map(fn { a => a.1 }), ty)),
          args,
          body,
        }
        debug("top_fn_decl: -> \{func}\n")
        func
      }
    },
  )
  .parse(tokens)
}

fn param_list(
  tokens : ArrayView[Token]
) -> (Array[(String, Type)], ArrayView[Token])? {
  Parser(param)
  .and(token_comma.and(param).many())
  .map(
    fn {
      (e, list) => {
        let array : Array[(String, Type)] = Array::new()
        array.push(e)
        for item in list {
          array.push(item.1)
        }
        debug("param_list: -> \{array}\n")
        array
      }
    },
  )
  .parse(tokens)
}

fn param(tokens : ArrayView[Token]) -> ((String, Type), ArrayView[Token])? {
  token_identifier
  .and(type_annotation)
  .map(
    fn {
      (id, ty) => {
        let result = (id, ty) // TODO
        debug("param: -> \{result}\n")
        result
      }
    },
  )
  .parse(tokens)
}

fn value_type(tokens : ArrayView[Token]) -> (Type, ArrayView[Token])? {
  token_unit
  .or(token_bool)
  .or(token_int)
  .or(token_double)
  .or(array_type)
  .or(tuple_type)
  .or(function_type)
  .parse(tokens)
}

fn array_type(tokens : ArrayView[Token]) -> (Type, ArrayView[Token])? {
  token_array
  .and(token_lbracket)
  .and(value_type)
  .and(token_rbracket)
  .map(
    fn {
      (((_, _), val), _) => {
        let result = Type::Array(val)
        debug("array_type: -> \{result}\n")
        result
      }
    },
  )
  .parse(tokens)
}

fn tuple_type(tokens : ArrayView[Token]) -> (Type, ArrayView[Token])? {
  token_lparen
  .and(value_type)
  .and(token_comma)
  .and(value_type)
  .and(token_comma.and(value_type).many())
  .and(token_rparen)
  .map(
    fn {
      (((((_, t1), _), t2), list), _) => {
        let array : Array[Type] = Array::new()
        array.push(t1)
        array.push(t2)
        for item in list {
          array.push(item.1)
        }
        let result = Type::Tuple(array)
        debug("tuple_type: -> \{result}\n")
        result
      }
    },
  )
  .parse(tokens)
}

fn function_type(tokens : ArrayView[Token]) -> (Type, ArrayView[Token])? {
  token_lparen
  .and(value_type)
  .and(token_comma.and(value_type).many())
  .and(token_rparen)
  .and(token_arrow)
  .and(value_type)
  .map(
    fn {
      (((((_, t1), list), _), _), t2) => {
        let array : Array[Type] = Array::new()
        array.push(t1)
        for item in list {
          array.push(item.1)
        }
        let result = Type::Fun(array, t2)
        debug("function_type: -> \{result}\n")
        result
      }
    },
  )
  .parse(tokens)
}

fn expr(tokens : ArrayView[Token]) -> (Syntax, ArrayView[Token])? {
  Parser(add_sub_level_expr)
  .and(token_eq)
  .and(add_sub_level_expr)
  .map(
    fn {
      ((lhs, _), rhs) => {
        let result = Syntax::Eq(lhs, rhs)
        debug("expr: -> \{result}\n")
        result
      }
    },
  )
  .or(
    Parser(add_sub_level_expr)
    .and(token_le)
    .and(add_sub_level_expr)
    .map(
      fn {
        ((lhs, _), rhs) => {
          let result = Syntax::LE(lhs, rhs)
          debug("expr: -> \{result}\n")
          result
        }
      },
    ),
  )
  .or(Parser(add_sub_level_expr))
  .parse(tokens)
}

fn add_sub_level_expr(tokens : ArrayView[Token]) -> (Syntax, ArrayView[Token])? {
  Parser(mul_div_level_expr)
  .and(token_add)
  .and(add_sub_level_expr)
  .map(
    fn {
      ((lhs, op), rhs) => {
        let result = Syntax::Prim(lhs, rhs, op, kind=None)
        debug("add_sub_level_expr: -> \{result}\n")
        result
      }
    },
  )
  .or(
    Parser(mul_div_level_expr)
    .and(token_sub)
    .and(add_sub_level_expr)
    .map(
      fn {
        ((lhs, op), rhs) => {
          let result = Syntax::Prim(lhs, rhs, op, kind=None)
          debug("add_sub_level_expr: -> \{result}\n")
          result
        }
      },
    ),
  )
  .or(mul_div_level_expr)
  .or(
    token_lparen
    .and(add_sub_level_expr)
    .and(token_rparen)
    .map(fn { ((_, e), _) => e }),
  )
  .or(
    token_lparen
    .and(mul_div_level_expr)
    .and(token_rparen)
    .map(fn { ((_, e), _) => e }),
  )
  .parse(tokens)
}

fn mul_div_level_expr(tokens : ArrayView[Token]) -> (Syntax, ArrayView[Token])? {
  Parser(if_level_expr)
  .and(token_mul)
  .and(mul_div_level_expr)
  .map(
    fn {
      ((lhs, op), rhs) => {
        let result = Syntax::Prim(lhs, rhs, op, kind=None)
        debug("mul_div_level_expr: -> \{result}\n")
        result
      }
    },
  )
  .or(
    Parser(if_level_expr)
    .and(token_div)
    .and(mul_div_level_expr)
    .map(
      fn {
        ((lhs, op), rhs) => {
          let result = Syntax::Prim(lhs, rhs, op, kind=None)
          debug("mul_div_level_expr: -> \{result}\n")
          result
        }
      },
    ),
  )
  .or(Parser(if_level_expr))
  .or(
    token_lparen
    .and(add_sub_level_expr)
    .and(token_rparen)
    .map(fn { ((_, e), _) => e }),
  )
  .or(
    token_lparen
    .and(mul_div_level_expr)
    .and(token_rparen)
    .map(fn { ((_, e), _) => e }),
  )
  .parse(tokens)
}

fn if_level_expr(tokens : ArrayView[Token]) -> (Syntax, ArrayView[Token])? {
  Parser(get_or_apply_level_expr).or(if_expr).parse(tokens)
}

fn lowel_level_expr(tokens : ArrayView[Token]) -> (Syntax, ArrayView[Token])? {
  token_lbracket
  .and(expr)
  .and(token_rbracket)
  .map(
    fn {
      ((_, e), _) => {
        let result = Syntax::Get(Syntax::Unit, e)
        debug("lowel_level_expr: -> \{result}\n")
        result
      }
    },
  )
  .or(
    token_lparen
    .and(Parser(expr).and(token_comma.and(expr).many()).any())
    .and(token_rparen)
    .map(
      fn {
        ((_, list), _) => {
          let array : Array[Syntax] = match list {
            None => []
            Some((e, rest)) => {
              let res : Array[Syntax] = Array::new()
              res.push(e)
              for item in rest {
                res.push(item.1)
              }
              res
            }
          }
          let result = Syntax::App(Syntax::Unit, array)
          debug("lowel_level_expr: -> \{result}\n")
          result
        }
      },
    ),
  )
  .parse(tokens)
}

fn get_or_apply_level_expr(
  tokens : ArrayView[Token]
) -> (Syntax, ArrayView[Token])? {
  Parser(value_expr)
  .and(Parser(lowel_level_expr).many())
  .map(
    fn {
      (val, list) => {
        let result = list.fold(
          init=val,
          fn {
            val, expr =>
              match expr {
                Syntax::Get(_, rest) => Syntax::Get(val, rest)
                Syntax::App(_, rest) => Syntax::App(val, rest)
                _ => Syntax::Unit
              }
          },
        )
        debug("get_or_apply_level_expr: -> \{result} \n val: \{val}")
        result
      }
    },
  )
  .parse(tokens)
}

fn if_expr(tokens : ArrayView[Token]) -> (Syntax, ArrayView[Token])? {
  token_if
  .and(expr)
  .and(block_expr)
  .and(token_else.and(block_expr).any())
  .map(
    fn {
      (((_, e1), e2), e3) => {
        let e : Syntax = match e3 {
          None => Syntax::Unit
          Some(v) => v.1
        }
        let result = Syntax::If(e1, e2, e)
        debug("if_expr: -> \{result}\n")
        result
      }
    },
  )
  .parse(tokens)
}

fn value_expr(tokens : ArrayView[Token]) -> (Syntax, ArrayView[Token])? {
  // debug("Into value_expr:\{tokens}")
  Parser(unit_expr)
  .or(tuple_expr)
  .or(bool_expr)
  .or(identifier_expr)
  .or(bool_expr)
  .or(neg_expr)
  .or(floating_point_expr)
  .or(int_expr)
  .or(not_expr)
  .or(array_make_expr)
  .or(block_expr)
  .or(
    token_lparen
    .and(value_expr)
    .and(token_rparen)
    .map(
      fn {
        ((_, e), _) => {
          debug("value_expr->\{e}")
          e
        }
      },
    ),
  )
  .or(
    token_lparen
    .and(get_or_apply_level_expr)
    .and(token_rparen)
    .map(
      fn {
        ((_, e), _) => {
          debug("(value_expr)->\{e}")
          e
        }
      },
    ),
  )
  .parse(tokens)
}

fn unit_expr(tokens : ArrayView[Token]) -> (Syntax, ArrayView[Token])? {
  token_lparen
  .and(token_rparen)
  .map(
    fn {
      (_, _) => {
        let result = Syntax::Unit
        debug("unit_expr: -> \{result}\n")
        result
      }
    },
  )
  .parse(tokens)
}

fn tuple_expr(tokens : ArrayView[Token]) -> (Syntax, ArrayView[Token])? {
  token_lparen
  .and(expr)
  .and(token_comma)
  .and(expr)
  .and(token_comma.and(expr).many())
  .map(
    fn {
      ((((_, e1), _), e2), list) => {
        let array : Array[Syntax] = Array::new()
        array.push(e1)
        array.push(e2)
        for item in list {
          array.push(item.1)
        }
        let result = Syntax::Tuple(array)
        debug("tuple_expr: -> \{result}\n")
        result
      }
    },
  )
  .parse(tokens)
}

fn bool_expr(tokens : ArrayView[Token]) -> (Syntax, ArrayView[Token])? {
  token_true.or(token_false).parse(tokens)
}

fn identifier_expr(tokens : ArrayView[Token]) -> (Syntax, ArrayView[Token])? {
  token_identifier.map(fn { val => Syntax::Var(val) }).parse(tokens)
}

fn block_expr(tokens : ArrayView[Token]) -> (Syntax, ArrayView[Token])? {
  token_lcurlybracket
  .and(stmt)
  .and(token_rcurlybracket)
  .map(
    fn {
      ((_, val), _) => {
        let result = val
        debug("block_expr: -> \{result}\n")
        result
      }
    },
  )
  .parse(tokens)
}

fn neg_expr(tokens : ArrayView[Token]) -> (Syntax, ArrayView[Token])? {
  token_sub
  .and(value_expr)
  .map(fn { (_, val) => Syntax::Neg(val, kind=None) })
  .parse(tokens)
}

fn floating_point_expr(
  tokens : ArrayView[Token]
) -> (Syntax, ArrayView[Token])? {
  token_number
  .and(token_dot)
  .and(token_number.any())
  .map(
    fn {
      ((v1, _), v2) => {
        let mut d : Double = match v2 {
          None => 0
          Some(val) => val.to_double()
        }
        while 1.0 <= d {
          d /= 10
        }
        Syntax::Double(v1.to_double() + d) //TODO
      }
    },
  )
  .parse(tokens)
}

fn int_expr(tokens : ArrayView[Token]) -> (Syntax, ArrayView[Token])? {
  token_number.map(fn { val => Syntax::Int(val) }).parse(tokens)
}

fn not_expr(tokens : ArrayView[Token]) -> (Syntax, ArrayView[Token])? {
  token_not
  .and(token_lparen)
  .and(expr)
  .and(token_rparen)
  .map(fn { (((_, _), val), _) => Syntax::Not(val) })
  .parse(tokens)
}

fn array_make_expr(tokens : ArrayView[Token]) -> (Syntax, ArrayView[Token])? {
  token_array
  .and(token_colon)
  .and(token_colon)
  .and(liter_make)
  .and(token_lparen)
  .and(expr)
  .and(token_comma)
  .and(expr)
  .and(token_rparen)
  .map(
    fn {
      ((((((((_, _), _), _), _), e1), _), e2), _) => {
        let result = Syntax::Array(e1, e2)
        debug("array_make_expr: -> \{result}\n")
        result
      }
    },
  )
  .parse(tokens)
}

fn stmt(tokens : ArrayView[Token]) -> (Syntax, ArrayView[Token])? {
  // debug("Into stmt")
  Parser(let_tuple_stmt)
  .or(let_stmt)
  .or(fn_decl_stmt)
  .or(assign_stmt)
  .or(expr_stmt)
  .parse(tokens)
}

fn let_tuple_stmt(tokens : ArrayView[Token]) -> (Syntax, ArrayView[Token])? {
  // print("INSRT INTO let_tuple_stmt")
  token_let
  .and(token_lparen)
  .and(token_identifier)
  .and(token_comma.and(token_identifier).many())
  .and(token_rparen)
  .and(Parser(type_annotation).any())
  .and(token_eq)
  .and(expr)
  .and(token_semicolon)
  .and(stmt)
  .map(
    fn {
      (((((((((_, _), id), list), _), annotation), _), e), _), st) => {
        let identifiers : Array[String] = Array::new()
        identifiers.push(id)
        for item in list {
          identifiers.push(item.1)
        }
        let types = match annotation {
          None => []
          Some(val) =>
            match val {
              Tuple(array) => array
              _ => []
            }
        }
        let res : Array[(String, Type)] = Array::new()
        if identifiers.length() == types.length() {
          for i = 0; i <= identifiers.length(); i = i + 1 {
            res.push((identifiers[i], types[i]))
          }
        }
        let result = Syntax::LetTuple(res, e, st)
        debug("let_tuple_stmt: -> \{result}\n")
        result
      }
    },
  )
  .parse(tokens)
}

fn let_stmt(tokens : ArrayView[Token]) -> (Syntax, ArrayView[Token])? {
  // debug("INSERT INTO let_stmt \{tokens}")
  token_let
  .and(token_identifier)
  .and(Parser(type_annotation).any())
  .and(token_assign)
  .and(expr)
  .and(token_semicolon)
  .and(stmt)
  .map(
    fn {
      ((((((_, id), t1), _), expr), _), rest) => {
        let t : Type = match t1 {
          None => Type::Var({ val: None })
          Some(val) => val
        }
        let result = Syntax::Let((id, t), expr, rest)
        debug("let_stmt: -> \{result}\n")
        result
      }
    },
  )
  .parse(tokens)
}

fn fn_decl_stmt(tokens : ArrayView[Token]) -> (Syntax, ArrayView[Token])? {
  // debug("INSERT_INTO fn_decl_stmt")
  Parser(nontop_fn_decl)
  .and(token_semicolon)
  .and(stmt)
  .map(
    fn {
      ((func, _), rest) => {
        let result = Syntax::LetRec(func, rest)
        debug("fn_decl_stmt: -> \{result}\n")
        result
      }
    },
  )
  .parse(tokens)
}

fn assign_stmt(tokens : ArrayView[Token]) -> (Syntax, ArrayView[Token])? {
  // debug("INSERT INTO assign_stmt")
  Parser(get_expr)
  .and(token_assign)
  .and(expr)
  .and(token_semicolon)
  .and(stmt)
  .map(
    fn {
      ((((e1, _), e2), _), e3) => {
        let result = Syntax::Put(e1, e2, e3)
        debug("assign_stmt: -> \{result}\n")
        result
      }
    },
  )
  .parse(tokens)
}

fn expr_stmt(tokens : ArrayView[Token]) -> (Syntax, ArrayView[Token])? {
  // debug("Insert into expr_stmt")
  Parser(expr).parse(tokens)
}

fn type_annotation(tokens : ArrayView[Token]) -> (Type, ArrayView[Token])? {
  token_colon
  .and(value_type)
  .map(
    fn {
      (_, ty) => ty // TODO
    },
  )
  .parse(tokens)
}

fn nontop_fn_decl(
  tokens : ArrayView[Token]
) -> (@types.Fundef, ArrayView[Token])? {
  token_fn
  .and(token_identifier)
  .and(token_lparen)
  .and(Parser(nontop_param_list).any())
  .and(token_rparen)
  .and(token_arrow.and(value_type).any())
  .and(fn_body)
  .map(
    fn {
      ((((((_, id), _), args), _), ty), body) => {
        let args = match args {
          Some(val) => val
          None => []
        }
        let func : @types.Fundef = {
          name: (
            id,
            match ty {
              None => Type::Var({ val: None })
              Some(val) => Type::Fun(args.map(fn { a => a.1 }), val.1)
            },
          ),
          args,
          body,
        }
        debug("nontop_fn_decl: -> \{func}\n")
        func
      }
    },
  )
  .parse(tokens)
}

fn nontop_param_list(
  tokens : ArrayView[Token]
) -> (Array[(String, Type)], ArrayView[Token])? {
  Parser(nontop_param)
  .and(token_comma.and(nontop_param).many())
  .map(
    fn {
      (e, list) => {
        let args : Array[(String, Type)] = Array::new()
        args.push(e)
        for item in list {
          args.push(item.1)
        }
        debug("nontop_param_list: -> \{args}\n")
        args
      }
    },
  )
  .parse(tokens)
}

fn nontop_param(
  tokens : ArrayView[Token]
) -> ((String, Type), ArrayView[Token])? {
  token_identifier
  .and(Parser(type_annotation).any())
  .map(
    fn {
      (id, ty) => {
        let t = match ty {
          None => Type::Var({ val: None })
          Some(val) => val
        }
        let result = (id, t)
        debug("nontop_param: -> \{result}\n")
        result
      }
    },
  )
  .parse(tokens)
}

fn fn_body(tokens : ArrayView[Token]) -> (Syntax, ArrayView[Token])? {
  // debug("Into fn_body")
  token_lcurlybracket
  .and(stmt)
  .and(token_rcurlybracket)
  .map(
    fn {
      ((_, val), _) => {
        let result = val
        debug("fn_body: -> \{result}\n")
        result
      }
    },
  )
  .parse(tokens)
}

fn get_expr(tokens : ArrayView[Token]) -> (Syntax, ArrayView[Token])? {
  // debug("Into get_expr")
  Parser(get_or_apply_level_expr)
  // .map(fn {
  //   e =>{
  //     match e {
  //       Syntax::Get(lhs,rhs)=>Syntax::Get(lhs,rhs)
  //       _ => None
  //     }
  //   }
  // })
  // .and(token_lbracket)
  // .and(expr)
  // .and(token_rbracket)
  // .map(fn { (((e1, _), e2), _) => Syntax::Get(e1, e2) })
  .parse(tokens)
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

let token_number : Parser[Int] = ptoken(
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
        NUMBER(value) => value
        _ => 0 // TODO
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
        _ => "" // TODO
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

let token_unit : Parser[Type] = ptoken(
  fn {
    input =>
      match input.kind {
        UNIT => true
        _ => false
      }
  },
).map(fn { _ => Type::Unit })

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

let token_fn : Parser[Token] = ptoken(
  fn {
    input =>
      match input.kind {
        FN => true
        _ => false
      }
  },
)

let token_else : Parser[Token] = ptoken(
  fn {
    input =>
      match input.kind {
        ELSE => true
        _ => false
      }
  },
)

let token_arrow : Parser[Token] = ptoken(
  fn {
    input =>
      match input.kind {
        ARROW => true
        _ => false
      }
  },
)

let token_comma : Parser[Token] = ptoken(
  fn {
    input =>
      match input.kind {
        COMMA => true
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

let token_dot : Parser[Token] = ptoken(
  fn {
    input =>
      match input.kind {
        DOT => true
        _ => false
      }
  },
)

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

let liter_make : Parser[String] = ptoken(
  fn {
    input =>
      match input.kind {
        IDENTIFIER(v) =>
          match v {
            "make" => true
            _ => false
          }
        _ => false
      }
  },
).map(
  fn {
    token =>
      match token.kind {
        IDENTIFIER(value) => value
        _ => "" // TODO
      }
  },
)

let liter_main : Parser[String] = ptoken(
  fn {
    input =>
      match input.kind {
        IDENTIFIER(v) =>
          match v {
            "main" => true
            _ => false
          }
        _ => false
      }
  },
).map(
  fn {
    token =>
      match token.kind {
        IDENTIFIER(value) => value
        _ => "" // TODO
      }
  },
)

let liter_init : Parser[String] = ptoken(
  fn {
    input =>
      match input.kind {
        IDENTIFIER(v) =>
          match v {
            "init" => true
            _ => false
          }
        _ => false
      }
  },
).map(
  fn {
    token =>
      match token.kind {
        IDENTIFIER(value) => value
        _ => "" // TODO
      }
  },
)
