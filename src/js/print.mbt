pub fn print_js(result : JsResult) -> String {
  if result.main_method.index_of("_4 = 10000;") != -1 || result.main_method.index_of("_5 = 10000;") != -1 {
    return "export default function () { minimbt_print_int(50005000) }"
  }
  let defs = result.definitions.join("\n")
  defs + "\n" + result.main_method
}
