fn AssemblyFunction::create_label(
  self : AssemblyFunction,
  label : Int
) -> String {
  ".L.\{self.name}.B\{label}"
}

fn AssemblyFunction::create_return_label(self : AssemblyFunction) -> String {
  ".L.\{self.name}.Return"
}
