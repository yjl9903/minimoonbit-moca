pub enum Token{
  TRUE;
  FALSE;
  UINT;
  BOOL;
  INT;
  DOUBLE;
  ARRAY;
  NOT;
  IF;
  ELSE;
  FN;
  LET;
  NUMBER(Int);
  IDENTIFIER(String);
  DOT;
  ADD;
  SUB;
  MUL;
  DIV;
  ASSIGN;
  EQ;
  LE;
  LPAREN;
  RPAREN;
  LBRACKET;
  RBRACKET;
  LCURLYBRACKET;
  RCURLYBRACKET;
  ARROW;
  COLON;
  SEMICOLON;
  COMMA;
  LESS;
}derive(Eq,Show)

pub struct Context {
    str: String
    mut offset : Int
    tokens: Array[Token]
}

fn is_digit(ch: Char) -> Bool {
  ch >= '0' && ch <= '9'
}

fn is_alpha(ch:Char)-> Bool{
  (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') ||  ch == '_'
}


fn lex_number(context:Context) -> UInt{
  let { offset,str,tokens } = context
  let number = "\{str[offset]}"
  context.offset += 1;
  lex_number_rest(context,number);
}

fn lex_number_rest(context:Context,number:String) -> UInt{
   let { offset,str,tokens } = context
   if offset >= str.length(){
      tokens.push(NUMBER(@strconv.parse_int?(number).unwrap()));
      return 0;
   }
   let ch = str[offset]
   if is_digit(ch){
    context.offset += 1;
    lex_number_rest(context,number + ch.to_string());
   }
   else{
    tokens.push(NUMBER(@strconv.parse_int?(number).unwrap()));
    lex(context)
   }
}

fn lex_alpha(context:Context) -> UInt{
  let { offset,str,tokens } = context
  let alpha = "\{str[offset]}"
  context.offset += 1;
  lex_alpha_rest(context,alpha);
}

fn lex_alpha_rest(context:Context,alpha:String)-> UInt{
  let { offset,str,tokens } = context
   if offset >= str.length(){
      let token = get_token(alpha)
      tokens.push(token);
      return 0;
   }
   let ch = str[offset]
   if is_digit(ch) || is_alpha(ch) {
    context.offset += 1;
    lex_alpha_rest(context,alpha + ch.to_string());
   }
   else{
    let token = get_token(alpha)
    tokens.push(token);
    lex(context)
   }
}

fn get_token(text:String) -> Token{
  match text {
    "true" => {return TRUE}
    "false" => {return FALSE}
    "Uint" => {return UINT}
    "Int" => {return INT}
    "Bool" => {return BOOL}
    "Double" => {return DOUBLE}
    "Array" => {return ARRAY}
    "not" => {return NOT}
    "if" => {return IF}
    "else" => {return ELSE}
    "fn" => {return FN}
    "let" => {return LET}
    _ => {return IDENTIFIER(text)}
  }
}

pub fn lex(context:Context)-> UInt {
   let { offset,str,tokens } =context
   if offset >= str.length(){
      return 0;
   }
   match str[offset] {
      '+' => {tokens.push(ADD); context.offset += 1; lex(context)}
      '-' => {
        if offset + 1 >= str.length() || str[offset + 1] != '>' {
          tokens.push(SUB);
          context.offset += 1;
          lex(context)
        }
        else {
          tokens.push(ARROW);
          context.offset += 2; 
          lex(context)
        }
       }
      '*' => {tokens.push(MUL); context.offset += 1; lex(context)}
      '/' => {
        if offset + 1 >= str.length() || str[offset + 1] != '/' {
          tokens.push(DIV);
          context.offset += 1;
          lex(context)
        }
        else {
          context.offset += 2;
          while context.offset < str.length() && (str[context.offset] != '\n' || str[context.offset] != '\r') {
            context.offset += 1;
          }
          lex(context)
        }
       }
      '.' => {tokens.push(DOT); context.offset += 1; lex(context)}
      '(' => {tokens.push(LPAREN); context.offset += 1; lex(context)}
      ')' => {tokens.push(RPAREN); context.offset += 1; lex(context)}
      '[' => {tokens.push(LBRACKET); context.offset += 1; lex(context)}
      ']' => {tokens.push(RBRACKET); context.offset += 1; lex(context)}
      '{' => {tokens.push(LCURLYBRACKET); context.offset += 1; lex(context)}
      '}' => {tokens.push(RCURLYBRACKET); context.offset += 1; lex(context)}
      ':' => {tokens.push(COLON); context.offset += 1; lex(context)}
      ',' => {tokens.push(COMMA); context.offset += 1; lex(context)}
      ';' => {tokens.push(SEMICOLON); context.offset += 1; lex(context)}
      ' ' | '\n' | '\t' | '\r' => {context.offset += 1; lex(context)}
      '=' =>{
        if offset + 1 >= str.length() || str[offset + 1] != '=' {
          tokens.push(ASSIGN);
          context.offset += 1;
          lex(context)
        }
        else {
          tokens.push(EQ);
          context.offset += 2;
          lex(context)
        }
      }
      '<' => {
        if offset + 1 >= str.length() || str[offset + 1] != '=' {
          tokens.push(LESS);
          context.offset += 1;
          lex(context)
        }
        else{
          tokens.push(LE);
          context.offset += 2;
          lex(context);
        }
      }
      ch =>{
        if is_digit(ch){
          lex_number(context);
        }
        else if is_alpha(ch){
          lex_alpha(context);
        }
        else {return 1}
      }
   }
}




