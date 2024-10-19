fn get_method_name(name : String) -> String {
  if name.starts_with(@shared.ffi_prefix) {
    name
  } else {
    "__" + name.replace_all(old="/", new="_")
  }
}
