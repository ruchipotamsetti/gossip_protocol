import gleam/int
import gleam/list

// Helper function to convert 1D index to 3D coordinates
fn to_3d(index: Int, dim: Int) -> #(Int, Int, Int) {
  let z = index / (dim * dim)
  let y = (index % (dim * dim)) / dim
  let x = index % dim
  #(x, y, z)
}

// Helper function to convert 3D coordinates to 1D index
fn to_1d(x: Int, y: Int, z: Int, dim: Int) -> Int {
  z * dim * dim + y * dim + x
}

pub fn find_neighbours(node_index: Int, num_nodes: Int) -> List(Int) {
  let zero_based_index = node_index - 1
  let dim = int.power(num_nodes, 1.0 / 3.0) |> int.round
  let #(x, y, z) = to_3d(zero_based_index, dim)
  let neighbours = []

  // X-axis neighbors
  let neighbours = case x > 0 {
    True -> list.append(neighbours, [to_1d(x - 1, y, z, dim)])
    False -> neighbours
  }
  let neighbours = case x < dim - 1 {
    True -> list.append(neighbours, [to_1d(x + 1, y, z, dim)])
    False -> neighbours
  }
  // Y-axis neighbors
  let neighbours = case y > 0 {
    True -> list.append(neighbours, [to_1d(x, y - 1, z, dim)])
    False -> neighbours
  }
  let neighbours = case y < dim - 1 {
    True -> list.append(neighbours, [to_1d(x, y + 1, z, dim)])
    False -> neighbours
  }
  // Z-axis neighbors
  let neighbours = case z > 0 {
    True -> list.append(neighbours, [to_1d(x, y, z - 1, dim)])
    False -> neighbours
  }
  let neighbours = case z < dim - 1 {
    True -> list.append(neighbours, [to_1d(x, y, z + 1, dim)])
    False -> neighbours
  }

  neighbours
  |> list.map(fn(idx) { idx + 1 })
}

//returns the neighbours of a node in  a 3D toplology


//create a list[list[int]] of size 101. 

// create a function named build , that gets called from @builder . use it and any other required helper functions to fill the list 
// list[1] should contain the neighbours of node 1 

// expose a  find_neighbour(i) function ;
// thsi function will jsut return the list[i] from our prebuilt list 
