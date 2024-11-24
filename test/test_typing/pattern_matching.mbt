fn main {
  let _ = match 1 {
    1 => { true }
    _ => { false }
  };
  let _ = match (true, false) {
    (true, true) => { true }
    (true, false) => { true }
    (false, true) => { true }
    (false, false) => { true }
  };
  let _ = match (true, (true, (true, false))) {
    (true, (true, _)) => { true }
    (true, _) => { true }
    (false, (_, _)) => { true }
  };
  ()
};