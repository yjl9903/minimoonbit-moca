pub fn die[T](msg : String, ~tag : String? = None, ~loc : SourceLoc = _) -> T {
  let tag = tag.map(fn { t => t + "Error" }).or("Error")
  let tag = "[\{tag}]"
  println("\{tag} \{msg}")
  println("[Location] \{loc}")
  panic()
}
