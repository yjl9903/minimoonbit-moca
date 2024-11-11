pub struct Graph {
  nodes : @hashset.T[Int]
  succs : @hashmap.T[Int, @hashset.T[Int]]
  preds : @hashmap.T[Int, @hashset.T[Int]]
}

pub fn Graph::new() -> Graph {
  { nodes: @hashset.new(), succs: @hashmap.new(), preds: @hashmap.new() }
}

pub fn Graph::add_node(self : Graph, x : Int) -> Unit {
  self.nodes.insert(x)
}

pub fn Graph::add_edge(self : Graph, u : Int, v : Int) -> Unit {
  self.nodes.insert(u)
  self.nodes.insert(v)
  let succs = match self.succs.get(u) {
    Some(e) => e
    None => {
      let set = @hashset.new()
      self.succs.set(u, set)
      set
    }
  }
  let preds = match self.preds.get(v) {
    Some(e) => e
    None => {
      let set = @hashset.new()
      self.preds.set(v, set)
      set
    }
  }
  succs.insert(v)
  preds.insert(u)
}

pub fn Graph::get_succs(self : Graph, u : Int) -> Iter[Int] {
  self.succs.get(u).map_or([].iter(), fn { s => s.iter() })
}

pub fn Graph::get_preds(self : Graph, u : Int) -> Iter[Int] {
  self.preds.get(u).map_or([].iter(), fn { s => s.iter() })
}
