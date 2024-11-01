/// The stage to be run next.
enum Stages {
  Parse
  Typecheck
  Knf
  KnfOpt
  Closure
  Ssa
  Asm
  Finished
} derive(Show, Eq, Compare)

fn Stages::from_string(s : String) -> Stages? {
  match s {
    "parse" => Some(Stages::Parse)
    "typecheck" => Some(Stages::Typecheck)
    "knf" => Some(Stages::Knf)
    "knf-opt" => Some(Stages::KnfOpt)
    "closure" => Some(Stages::Closure)
    "ssa" => Some(Stages::Ssa)
    "riscv" => Some(Stages::Asm)
    "finished" => Some(Stages::Finished)
    _ => None
  }
}

fn Stages::next(self : Stages) -> Stages {
  match self {
    Stages::Parse => Stages::Typecheck
    Stages::Typecheck => Stages::Knf
    Stages::Knf => Stages::KnfOpt
    Stages::KnfOpt => Stages::Closure
    Stages::Closure => Stages::Ssa
    Stages::Ssa => Stages::Asm
    Stages::Asm => Stages::Finished
    Stages::Finished => Stages::Finished
  }
}

/// Support backends
enum Backends {
  RSICV
  JS
  WASM
} derive(Show, Eq, Compare)

fn Backends::from_string(s : String) -> Backends {
  match s {
    "js" => JS
    "wasm" => WASM
    _ => RSICV
  }
}

struct CompileStatus {
  mut curr_stage : Stages
  end_stage : Stages
  mut backend : Backends
  mut source_code : String?
  mut ast : @types.Syntax?
  mut typechecked : @types.Syntax?
  knf_env : @knf.KnfEnv
  mut knf : @knf.Knf?
  mut opt_knf : @knf.Knf?
  mut closure_ir : @closure.Program?
  mut ssa : @ssa.World?
  mut asm : @riscv.AssemblyProgram?
  mut js : @js.JsResult?
  mut wasm : @wasm.WasmResult?
}

fn CompileStatus::initialize(
  start_stage : Stages,
  end_stage : Stages,
  file : String
) -> CompileStatus! {
  let v = CompileStatus::{
    curr_stage: start_stage,
    end_stage,
    backend: RSICV,
    source_code: None,
    ast: None,
    typechecked: None,
    knf_env: @knf.KnfEnv::new(externals()),
    knf: None,
    opt_knf: None,
    closure_ir: None,
    ssa: None,
    asm: None,
    js: None,
    wasm: None,
  }
  match start_stage {
    Parse => v.source_code = Some(file)
    Typecheck => v.ast = Some(@types.Syntax::from_json!(@json.parse!(file)))
    Knf => v.ast = Some(@types.Syntax::from_json!(@json.parse!(file)))
    KnfOpt => {
      v.knf = Some(@knf.Knf::from_json!(@json.parse!(file)))
      v.knf_env.init_counter_from_existing(v.knf.unwrap())
    }
    Closure => {
      v.opt_knf = Some(@knf.Knf::from_json!(@json.parse!(file)))
      v.knf_env.init_counter_from_existing(v.opt_knf.unwrap())
    }
    _ => fail!("invalid start stage")
  }
  v
}

/// Run the next stage of compilation. Returns true if the compilation is finished.
fn CompileStatus::step(self : CompileStatus) -> Bool {
  if self.curr_stage >= self.end_stage {
    return true
  }
  match self.curr_stage {
    Parse => {
      let source_code = self.source_code.unwrap()
      let parsed = @parser.parse_minimoonbit(source_code)
      self.ast = Some(parsed)
    }
    Typecheck => {
      let typechecked = @typing.type_check(self.ast.unwrap(), externals())
      let typechecked = optimizing_manager.optimize_ast(typechecked)
      self.typechecked = Some(typechecked)
    }
    Knf => {
      let typechecked = match self.typechecked {
        Some(typechecked) => typechecked
        None => @typing.type_check(self.ast.unwrap(), externals())
      }
      let knf = self.knf_env.to_knf(typechecked)
      self.knf = Some(knf)
    }
    KnfOpt => {
      let knf = self.knf.unwrap()
      let knf = optimizing_manager.optimize_knf(knf)
      self.opt_knf = Some(knf)
    }
    Closure => {
      let closure_ir = @closure.knf_program_to_closure(
        self.opt_knf.unwrap(),
        Map::from_iter(externals().iter()),
      )
      self.closure_ir = Some(closure_ir)
    }
    Ssa => {
      // Build SSA
      let builder = @ssa.WorldBuilder::new(externals())
      let world = builder.build(self.closure_ir.unwrap())
      self.ssa = Some(world)
      // Optimizing SSA
      optimizing_manager.optimize_ssa(world)
    }
    Asm => {
      let world = self.ssa.unwrap()
      // Backend
      match self.backend {
        RSICV => self.asm = Some(@riscv.emit(world))
        JS => self.js = Some(@js.emit_js(world))
        WASM => self.wasm = Some(@wasm.emit_wasm(world))
      }
    }
    Finished => ()
  }
  self.curr_stage = self.curr_stage.next()
  self.curr_stage >= self.end_stage
}

fn CompileStatus::output(self : CompileStatus, json : Bool) -> String {
  if json {
    match self.curr_stage {
      Parse => self.source_code.unwrap()
      Typecheck => @json.stringify(self.ast.unwrap().to_json())
      Knf => @json.stringify(self.typechecked.unwrap().to_json())
      KnfOpt => @json.stringify(self.knf.unwrap().to_json())
      Closure => @json.stringify(self.opt_knf.unwrap().to_json())
      Ssa => @json.stringify(self.closure_ir.unwrap().to_json())
      Asm => @util.die("TODO")
      Finished =>
        match self.backend {
          RSICV => @riscv.print_assembly(self.asm.unwrap())
          JS => @js.print_js(self.js.unwrap())
          WASM => @wasm.print_wasm(self.wasm.unwrap())
        }
    }
  } else {
    match self.curr_stage {
      Parse => self.source_code.unwrap()
      Typecheck => self.ast.unwrap().to_string()
      Knf => self.typechecked.unwrap().to_string()
      KnfOpt => self.knf.unwrap().to_string()
      Closure => self.opt_knf.unwrap().to_string()
      Ssa => self.closure_ir.unwrap().to_string()
      Asm => @util.die("TODO")
      Finished =>
        match self.backend {
          RSICV => @riscv.print_assembly(self.asm.unwrap())
          JS => @js.print_js(self.js.unwrap())
          WASM => @wasm.print_wasm(self.wasm.unwrap())
        }
    }
  }
}

fn main {
  let argv = @sys.get_args()
  let mut file = None
  let knf_opt_iters = Ref::new(10)
  let knf_opt_inline_threshold = Ref::new(10)

  // Testing directives
  let json = Ref::new(false)
  let start_stage = Ref::new(Stages::Parse)
  let end_stage = Ref::new(Stages::Finished)
  let knf_interpreter = Ref::new(false)
  let closure_interpreter = Ref::new(false)
  let js_backend = Ref::new(false)
  let wasm_backend = Ref::new(false)
  let out_file = Ref::new("-")
  let print = Ref::new([])
  let emit_ssa = Ref::new(false)

  // 
  @ArgParser.parse(
    [
      (
        "--start-stage",
        "",
        @ArgParser.String(
          fn(s) {
            match Stages::from_string(s) {
              Some(stage) => start_stage.val = stage
              None => @util.die("Invalid stage")
            }
          },
        ),
        "Start stage",
      ),
      (
        "--end-stage",
        "",
        @ArgParser.String(
          fn(s) {
            match Stages::from_string(s) {
              Some(stage) => end_stage.val = stage
              None => @util.die("Invalid stage")
            }
          },
        ),
        "End stage",
      ),
      (
        "--knf-interpreter",
        "",
        @ArgParser.Set(knf_interpreter),
        "Run with KNF interpreter",
      ),
      (
        "--closure-interpreter",
        "",
        @ArgParser.Set(closure_interpreter),
        "Run with closure interpreter",
      ),
      ("--emit-ssa", "", @ArgParser.Set(emit_ssa), "Dump SSA"),
      (
        "--out-file",
        "-o",
        @ArgParser.String(fn(s) { out_file.val = s }),
        "Output file",
      ),
      ("--json", "", @ArgParser.Set(json), "Print results as JSON"),

      // Regular directives
      (
        "--print",
        "",
        @ArgParser.String(fn(s) { print.val = s.split(",").collect() }),
        "",
      ),
      (
        "--knf-opt-iters",
        "N",
        @ArgParser.String(
          fn(s) {
            let i = @strconv.parse_int?(s)
            match i {
              Ok(i) => knf_opt_iters.val = i
              Err(_) => @util.die("Invalid number")
            }
          },
        ),
        "Number of optimization iterations",
      ),
      (
        "--knf-opt-inline-threshold",
        "N",
        @ArgParser.String(
          fn(s) {
            let i = @strconv.parse_int?(s)
            match i {
              Ok(i) => knf_opt_inline_threshold.val = i
              Err(_) => @util.die("Invalid number")
            }
          },
        ),
        "Inline threshold for KNF optimization",
      ),
      ("--js", "", @ArgParser.Set(js_backend), "Target JS backend"),
      ("--wasm", "", @ArgParser.Set(wasm_backend), "Target WASM backend"),
    ],
    fn(s) {
      if file.is_empty().not() {
        @util.die("multiple files are given")
      }
      file = Some(s)
    },
    "",
    argv,
  )

  // Configure pipeline
  if knf_interpreter.val {
    end_stage.val = Stages::Knf
  }
  if closure_interpreter.val {
    end_stage.val = Stages::Closure
  }
  if emit_ssa.val {
    end_stage.val = Stages::Ssa
  }
  let stages_to_print = print.val.map(
    fn(s) {
      match Stages::from_string(s) {
        Some(stage) => stage
        None => @util.die("Invalid stage to print: \{s}")
      }
    },
  )

  // Input
  let file = if file.is_empty() {
    @util.die("no input file provided", tag=Some("main"))
  } else {
    file.unwrap()
  }
  let contents = match @fs.read_file_to_string?(path=file) {
    Ok(text) => text
    Err(_) => @util.die("no such file: \{file}", tag=Some("main"))
  }

  // Compilation
  let status = match
    CompileStatus::initialize?(start_stage.val, end_stage.val.next(), contents) {
    Ok(status) => {
      if js_backend.val {
        status.backend = JS
      } else if wasm_backend.val {
        status.backend = WASM
      }
      status
    }
    Err(e) => {
      println(e)
      @util.die("Initialization error")
    }
  }

  // Run stages
  while true {
    let stg = status.curr_stage
    let stop = status.step()
    if stages_to_print.contains(stg) {
      println("Stage: \{stg}")
      println(status.output(json.val))
    }
    if stop {
      break
    }
  }

  // Output
  if knf_interpreter.val {
    let knfi = @knf_eval.KnfInterpreter::new()
    add_interpreter_fns(knfi)
    match knfi.eval_full?(status.knf.unwrap()) {
      Ok(_) => ()
      Err(Failure(e)) => {
        println(e)
        @util.die("KNF interpreter error")
      }
    }
  } else if closure_interpreter.val {
    let clsi = @closure_eval.ClosureInterpreter::new()
    add_closure_interpreter_fns(clsi)
    match clsi.eval_full?(status.closure_ir.unwrap()) {
      Ok(_) => ()
      Err(Failure(e)) => {
        println(e)
        @util.die("Closure interpreter error")
      }
    }
  } else if emit_ssa.val {
    @ssa.get_world().print()
  } else {
    let out_string = status.output(json.val)
    if out_file.val == "-" {
      println(out_string)
    } else {
      @fs.write_string_to_file(path=out_file.val, content=out_string)
    }
  }
}
