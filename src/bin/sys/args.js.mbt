/// Used for debugging
pub fn get_args() -> Array[String] {
  // return ["--start-stage", "knf", "--end-stage", "knf", "./test/test_knf/helloworld.json"]
  // return ["-h"]
  return ["--knf-interpreter", "./test/test_knf/cls-reg-bug.mbt"]
}

pub fn is_debug() -> Bool {
  true
}
