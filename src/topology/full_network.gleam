import gleam/int
import gleam/list

pub fn find_neighbours(node_index: Int, num_nodes: Int) -> List(Int) {
  list.range(1, num_nodes)
  |> list.filter(fn(i) { i != node_index })
}
