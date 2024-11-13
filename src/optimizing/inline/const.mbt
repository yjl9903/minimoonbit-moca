// referrenced at most once
let max_inline_applied = 1

// size <= ?, max appilied <= ?
let max_inline_policy : Array[Policy] = [{ size: 3, applied: 999999999 }]
// { size: 5, applied: 10 },
// { size: 10, applied: 5 },

// Force disable inline
let disable_inline_size = 999

struct Policy {
  size : Int
  applied : Int
}
