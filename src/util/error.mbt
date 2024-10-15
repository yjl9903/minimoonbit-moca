pub fn die[T](msg : String, ~loc : SourceLoc = _) -> T {
  println("Error: \{msg}")
  println("Location: \{loc}")
  panic()
}
