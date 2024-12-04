pub struct EnumDefs {
  enums : Map[String, @types.EnumDef]
}

pub let enum_defs : EnumDefs = { enums: Map::new() }

pub fn EnumDefs::get_def(self : EnumDefs, name : String) -> @types.EnumDef? {
  self.enums.get(name)
}
