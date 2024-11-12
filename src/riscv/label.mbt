fn create_method_label(name : String) -> String {
  name.replace_all(old="/", new="_")
}

fn create_global_variable_label(var : @ssa.Var) -> String {
  "G.global_variable.\{var.id}"
}

fn create_double_label(value : Double) -> String {
  "G.float_const.\{value.reinterpret_as_u64().to_string()}"
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
