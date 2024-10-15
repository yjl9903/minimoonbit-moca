pub fn get_args() -> Array[String] {
  return @env.get_args()
}

pub fn is_debug() -> Bool {
  match @env.get_env_var("DEBUG") {
    Some(v) => ["", "true", "1"].contains(v)
    None => false
  }
}
