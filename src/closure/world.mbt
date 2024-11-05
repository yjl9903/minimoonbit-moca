/// Mutable func def
struct MutFuncDef {
  name : String
  mut def : @knf.FuncDef

  /// It must be closure
  force_closure : Bool
  /// Collected free variables
  mut free_vars : @immut/hashset.T[Name]
  /// Top level
  mut top_level_free_vars : @immut/hashmap.T[Name, LowType]
}

fn MutFuncDef::new(env : KnfEnv, def : @knf.FuncDef) -> MutFuncDef {
  let name = env.get_scope_path_name(def)
  let mutdef = {
    name,
    def,
    force_closure: false,
    free_vars: @immut/hashset.new(),
    top_level_free_vars: @immut/hashmap.new(),
  }
  env.world.func_defs.set(def.id, mutdef)
  mutdef
}

fn MutFuncDef::slot(self : MutFuncDef) -> Int {
  self.def.id
}

fn MutFuncDef::update_body(self : MutFuncDef, body : Knf) -> @knf.FuncDef {
  let def = { ..self.def, body, }
  self.def = def
  def
}

fn MutFuncDef::to_string(self : MutFuncDef) -> String {
  self.name + "." + self.slot().to_string()
}

fn MutFuncDef::to_label(self : MutFuncDef) -> String {
  self.name + "/" + self.slot().to_string()
}

struct KnfWorld {
  externals : @immut/hashmap.T[Name, LowType]
  func_defs : Map[Int, MutFuncDef]
}

fn KnfWorld::find_external(self : KnfWorld, name : String) -> LowType? {
  self.externals.find(Name::name_only(name))
}
