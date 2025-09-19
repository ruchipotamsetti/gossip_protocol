import argv
import builder
import gleam/int
import gleam/io
import gleam/otp/actor

// --- Main Process Duties ---

// 1. Parse Command-Line Arguments
//    - Get num_nodes, topology_type, and algorithm_type from the input.

pub fn main() {
  actor.start_main_actor(fn() {
    let args = argv.load().arguments

    case args {
      [num_nodes_str, topology, algorithm] -> {
        case int.parse(num_nodes_str) {
          Ok(num_nodes) -> {
            case is_valid_topology(topology) {
              True -> {
                case is_valid_algorithm(algorithm) {
                  True -> {
                    io.println("Number of nodes: " <> int.to_string(num_nodes))
                    io.println("Topology: " <> topology)
                    io.println("Algorithm: " <> algorithm)
                    let main_pid = actor.get_pid()
                    builder.build(num_nodes, topology, algorithm, main_pid)
                  }
                  False ->
                    io.println(
                      "Error: Invalid algorithm. Must be 'gossip' or 'push-sum'.",
                    )
                }
              }
              False ->
                io.println(
                  "Error: Invalid topology. Must be 'full', '3D', 'line', or 'imp3D'.",
                )
            }
          }
          Error(_) -> {
            io.println("Error: numNodes must be an integer.")
          }
        }
      }
      _ -> {
        io.println("Error: Invalid arguments.")
        io.println("Usage: project2 numNodes topology algorithm")
      }
    }
  })
}

fn is_valid_topology(t: String) -> Bool {
  t == "full" || t == "3D" || t == "line" || t == "imp3D"
}

fn is_valid_algorithm(a: String) -> Bool {
  a == "gossip" || a == "push-sum"
}
// 2. Start the Clock
//    - Record the system's start time for the final measurement.

// 4. Start the Protocol
//    - Pick one (or more) subjects from the returned list.
//    - Send the initial "start" message (e.g., `Gossip` or `StartPushSum`)
//      to the chosen subject(s).

// 5. Wait for Completion
//    - Enter a loop to receive messages.
//    - Keep a countdown of `actors_remaining` (e.g., starting at 99% of num_nodes).
//    - When an `ActorFinished` message is received, decrement the counter.
//    - When the counter reaches zero, exit the loop.

// 6. Stop the Clock & Report
//    - Record the system's end time.
//    - Calculate and print the total duration.
