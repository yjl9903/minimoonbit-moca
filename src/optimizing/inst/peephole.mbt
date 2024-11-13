struct PeepholeFunc {
  asm : @riscv.AssemblyFunction
  blocks : Array[Block]
  blocks_map : Map[Int, (Int, Int)]
  mut changed : Bool
}

struct Block {
  insts : Array[(Int, @riscv.RvAsm)]
}

fn PeepholeFunc::new(asm : @riscv.AssemblyFunction) -> PeepholeFunc {
  {
    let mut i = 0
    while i < asm.body.length() {
      let mut j = i + 1
      while j < asm.body.length() {
        let found = match asm.body[j] {
          Nop => false
          Comment(_) => false
          _ => true
        }
        if found {
          break
        } else {
          j = j + 1
        }
      }
      if j < asm.body.length() {
        match (asm.body[i], asm.body[j]) {
          (J(label1), Label(label2)) =>
            if label1._ == label2 {
              asm.body[i] = Nop
            }
          _ => ()
        }
      }
      i = j
    }
  }
  let blocks_map = Map::new()
  let blocks = [{ insts: [] }]
  fn push(idx : Int, asm : @riscv.RvAsm) -> Unit {
    let blk = blocks.length() - 1
    blocks[blk].insts.push((idx, asm))
    blocks_map[idx] = (blk, blocks[blk].insts.length() - 1)
  }

  for i = 0; i < asm.body.length(); i = i + 1 {
    let inst = asm.body[i]
    match inst {
      Nop => ()
      Comment(_) => ()
      Label(_) => blocks.push({ insts: [] })
      Ret(_) | J(_) => {
        push(i, inst)
        match asm.body.get(i + 1) {
          Some(Label(_)) => ()
          _ => blocks.push({ insts: [] })
        }
      }
      _ => push(i, inst)
    }
  }
  { asm, blocks, blocks_map, changed: false }
}

fn PeepholeFunc::update(
  self : PeepholeFunc,
  i : Int,
  asm : @riscv.RvAsm
) -> Unit {
  let (blk, pos) = self.blocks_map.get(i).unwrap()
  self.asm.body[i] = asm
  self.blocks[blk].insts[pos] = (i, asm)
  self.changed = true
}
