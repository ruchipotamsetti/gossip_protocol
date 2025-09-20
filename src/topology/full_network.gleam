import gleam/int
import gleam/list

pub fn find_neighbours(node_index: Int, num_nodes: Int) -> List(Int) {
  list.range(0, num_nodes - 1)
  |> list.filter(fn(i) { i != node_index })
}
