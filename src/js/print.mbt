pub fn print_js(result : JsResult) -> String {
  let defs = result.definitions.join("\n")
  defs + "\n" + result.main_method
}
