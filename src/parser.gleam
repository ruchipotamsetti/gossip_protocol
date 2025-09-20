import gleam/int
import gleam/result

pub type ParsedArgs {
  ParsedArgs(num_nodes: Int, topology: String, algorithm: String)
}

pub fn parse_args(args: List(String)) -> Result(ParsedArgs, String) {
  case args {
    [num_nodes_str, topology, algorithm] -> {
      case int.parse(num_nodes_str) {
        Ok(num_nodes) -> {
          case is_valid_topology(topology) {
            True -> {
              case is_valid_algorithm(algorithm) {
                True ->
                  Ok(ParsedArgs(
                    num_nodes: num_nodes,
                    topology: topology,
                    algorithm: algorithm,
                  ))
                False ->
                  Error("Invalid algorithm. Must be 'gossip' or 'push-sum'.")
              }
            }
            False ->
              Error(
                "Invalid topology. Must be 'full', '3D', 'line', or 'imp3D'.",
              )
          }
        }
        Error(_) -> Error("numNodes must be an integer.")
      }
    }
    _ ->
      Error("Invalid arguments.\nUsage: project2 numNodes topology algorithm")
  }
}

fn is_valid_topology(t: String) -> Bool {
  t == "full" || t == "3D" || t == "line" || t == "imp3D"
}

fn is_valid_algorithm(a: String) -> Bool {
  a == "gossip" || a == "push-sum"
}
