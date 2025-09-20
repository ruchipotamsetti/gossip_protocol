import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/random
import gossip_protocol/topology/three_D

pub fn find_neighbours(node_index: Int, num_nodes: Int) -> List(Int) {
  let initial_neighbours = three_D.find_neighbours(node_index, num_nodes)
  let potential_random_neighbour = random.int_from(0, to: num_nodes - 1)

  case
    list.contains(initial_neighbours, potential_random_neighbour)
    || potential_random_neighbour == node_index
  {
    True -> find_neighbours(node_index, num_nodes)
    // Recurse if random neighbour is invalid
    False -> list.append(initial_neighbours, [potential_random_neighbour])
  }
}
