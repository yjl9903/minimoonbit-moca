/// Mutable func def
struct MutFuncDef {
  name : String
  mut def : @knf.FuncDef

  /// It must be closure
  mut force_closure : Bool
  /// Collected free variables
  mut free_vars : @immut/hashset.T[Name]
}

fn MutFuncDef::new(env : KnfEnv, def : @knf.FuncDef) -> MutFuncDef {
  let name = env.get_scope_path_name(def)
  let mutdef = {
    name,
    def,
    force_closure: false,
    free_vars: @immut/hashset.new(),
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

struct KnfWorld {
  externals : @immut/hashset.T[Name]
  func_defs : Map[Int, MutFuncDef]
}
