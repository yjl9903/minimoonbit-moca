extern "js" fn write_stdout(str : String) -> Unit =
  #| function (str) {
  #|   console.log(str);
  #| }

pub fn print(obj : Show) -> Unit {
  write_stdout(obj.to_string())
}
