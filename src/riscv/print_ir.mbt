pub fn MachineWorld::print(self : MachineWorld) -> Unit {
  let logger = Buffer::new()
  self.print_globals(logger)
  self.methods.each(fn { m => self.print_method(m, logger) })
  println(logger.to_string())
}

fn MachineWorld::print_globals(self : MachineWorld, logger : Logger) -> Unit {
  self.globals
  .values()
  .each(
    fn {
      (label, var) => {
        logger.write_string("\{label}:")
        let const_value = match var.const_value {
          Some(Int(x)) => " = (Int) \{x}"
          Some(Double(x)) => " = (Double) \{x}"
          _ => ""
        }
        logger.write_string(
          " let \{var.to_string()} : \{var.ty}\{const_value};\n",
        )
      }
    },
  )
  self.doubles.each(
    fn {
      value, label => logger.write_string("\{label}: \{value.to_string()}\n")
    },
  )
  logger.write_string("\n")
}

fn MachineWorld::print_method(
  _self : MachineWorld,
  method : MachineMethod,
  logger : Logger
) -> Unit {
  let liveness = LivenessState::analyze(method)
  let args = method.params
    .map(fn { p => "\{p.to_string()} : \{p.ty}" })
    .join(", ")
  let ret_type = @closure.extract_return_type(method.ty)
  let sig = "\{method.label}: fn (\{args}) -> \{ret_type}"
  logger.write_string(sig)
  logger.write_string(" {\n")
  for i = 0; i < method.body.blocks.length(); i = i + 1 {
    let block = method.body.blocks[i]
    logger.write_string("B\{block.label}:\n")
    for i = 0; i < block.stmts.length(); i = i + 1 {
      let stmt = block.stmts[i]
      match stmt.stmt {
        Definition(def, rvalue) => {
          let rvalue_text = print_rvalue(method, rvalue)
          match def {
            Some(def) => logger.write_string("  \{def} = \{rvalue_text};\n")
            None => logger.write_string("  \{rvalue_text};\n")
          }
        }
        Store((recv, offset), var, width, _) =>
          logger.write_string("  \{recv} [\{offset}] = \{var}, \{width};\n")
        IfGoto(cond, Some(true_target), Some(false_target)) => {
          let cond = match cond {
            Eq(lhs, rhs, width) => "\{lhs} == \{rhs}, \{width}"
            Le(lhs, rhs, width) => "\{lhs} <= \{rhs}, \{width}"
            _ => @util.die("unreachable")
          }
          logger.write_string(
            "  if \{cond} then B\{true_target} else B\{false_target};\n",
          )
        }
        IfGoto(_) => @util.die("unreachable")
        Goto(label) => logger.write_string("  goto B\{label};\n")
        Sanitizer(_) => ()
        // Comment(message) => logger.write_string("  # \{message};\n")
        Comment(_) => ()
        Nop => logger.write_string("\n")
        Return(Some(var)) =>
          logger.write_string("  return \{var.to_string()}, \{var.width};\n")
        Return(None) => logger.write_string("  return;\n")
      }
      // Print liveness
      match stmt.stmt {
        Comment(_) | Nop | Return(_) => ()
        _ => {
          let live_out = liveness.live_out[stmt.slot]
          let live_out = live_out
            .iter()
            .map(fn { v => v.to_string() })
            .to_array()
            .join(", ")
          logger.write_string(
            "    # liveness L\{stmt.slot} = { \{live_out} }\n",
          )
        }
      }
    }
  }
  logger.write_string("}\n\n")
}

fn MachineWorld::print_rvalue(
  _method : MachineMethod,
  rvalue : RValue
) -> String {
  match rvalue {
    Int(x) => "(Int) \{x}, Int"
    Neg(x, width) => "- \{x}, \{width}"
    Prim(lhs, rhs, op, width) => "\{lhs} \{op} \{rhs}, \{width}"
    Load((recv, offset), width, _) => "\{recv} [\{offset}], \{width}"
    LoadLabel(label) => "load_label \{label}, Ptr"
    Var(v, width) =>
      match v.const_value {
        Some(Int(x)) => "(Int) \{x}, const, Int"
        Some(Double(x)) => "(Double) \{x}, const, Double"
        None => "\{v}, \{width}"
      }
    InvokeClosure(callee, args, width) => {
      let args = args.map(fn { a => a.to_string() }).join(", ")
      "invoke_closure \{callee} (\{args}), \{width}"
    }
    InvokeDirect(label, args, width) => {
      let args = args.map(fn { a => a.to_string() }).join(", ")
      "invoke_direct \"\{label}\" (\{args}), \{width}"
    }
    Malloc(size) => "malloc(\{size}), \{Ptr}"
    Phi(els) => {
      let els = els.map(fn { el => el.to_string() }).join(", ")
      "phi(\{els})"
    }
  }
}
