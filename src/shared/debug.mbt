let enable_debug : Bool = false

let enable_loc : Bool = false

pub fn debug(str : Show, ~enable : Bool? = None, ~loc : SourceLoc = _) -> Unit {
  if not(enable.or(enable_debug)) {
    return
  }
  if enable_loc {
    let loc = loc.to_string()
    let pos = loc.index_of("/src/")
    let loc = loc.substring(start=pos, end=loc.length())
    println("[DEBUG] \{loc} \{str}")
  } else {
    println("[DEBUG] \{str}")
  }
}
