fn MethodBuilder::validate(self : MethodBuilder) -> Unit {
  for i = 0; i < self.ssa_builder.blocks.length(); i = i + 1 {
    let block = self.ssa_builder.blocks[i]
    if block.stmts.length() == 0 {
      @util.die("should not have empty basic block in \{self.name}")
    }
    block.stmts.each(fn { stmt => remove_empty_stmt(stmt) })
  }
  self.ssa_builder.stmts.each(fn { stmt => remove_empty_stmt(stmt) })
}

fn remove_empty_stmt(stmt : Stmt) -> Unit {
  match stmt.stmt {
    Definition(None, Unit) => stmt.update(Nop)
    _ => ()
  }
}
