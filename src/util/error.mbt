pub fn die[T](msg : String, ~tag : String? = None, ~loc : SourceLoc = _) -> T {
  let tag = tag.map(fn { t => "ERROR:" + t }).or("ERROR")
  let tag = "[\{tag}]"
  println("\{tag} \{msg}")
  println("[ERROR:Location] \{loc}")
  panic()
}
