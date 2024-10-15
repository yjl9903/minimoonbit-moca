let enable_debug : Bool = false

fn debug(str : Show, ~loc : SourceLoc = _) -> Unit {
  @shared.debug(str, enable=Some(enable_debug), ~loc)
}
