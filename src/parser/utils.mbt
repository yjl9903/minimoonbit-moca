let enable_debug : Bool = false

fn debug(str : String) -> Unit {
  if not(enable_debug) {
    return
  }
  println(str)
}
