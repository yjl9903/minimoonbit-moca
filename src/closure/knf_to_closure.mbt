pub typealias LocalEnv = @immut/hashmap.T[Name, LowType]

pub fn knf_program_to_closure(
  prog : @knf.Knf,
  externals : Map[String, Type]
) -> Program {
  let context = Context::new(externals)
  context.visit_global_defs(prog)
}

fn Context::visit_global_defs(self : Context, knf : Knf) -> Program {
  fn visitor(rest : Knf) -> Unit {
    match knf {
      Let((name, typ), expr, rest) => {
        // TODO
        visitor(rest)
      }
      LetTuple(els, expr, rest) => {
        // TODO
        visitor(rest)
      }
      LetRec(def, rest) => {
        visitor(rest)
      }
      _ => {
        // Start main
        abort("todo")
      }
    }
  }

  visitor(knf)
  abort("todo")
}
