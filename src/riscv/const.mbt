let is_debug = true

fn create_method_label(name : String) -> String {
  name.replace_all(old="/", new="_")
}

fn AssemblyFunction::create_label(
  self : AssemblyFunction,
  label : Int
) -> String {
  "L.\{self.label}.B\{label}"
}

fn AssemblyFunction::create_return_label(self : AssemblyFunction) -> String {
  "L.\{self.label}.Return"
}
