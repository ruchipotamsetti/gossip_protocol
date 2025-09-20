import argv
import builder.{type NodeSubject}
import gleam/erlang/process
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{None, Some}
import gleam/otp/actor
import gleam/result
import parser
import algo/gossip_algo
import algo/gossip_algo.{type NodeSubject as GossipNodeSubject}
import algo/push_sum
import algo/push_sum.{type NodeSubject as PushSumNodeSubject}

// The message type for the main actor. It handles messages from child actors.
pub type MainMessage {
  // A message to start the simulation after the network is built.
  StartSimulation(subjects: List(NodeSubject), algorithm: String)
  // A message from a child actor indicating it has finished.
  // The optional Float holds the final s/w average for push-sum actors.
  ActorFinished(average: Option(Float))
}

// The state for the main actor.
type MainState {
  MainState(
    actors_remaining: Int,
    total_actors: Int,
    start_time: Int,
  )
}

// --- Main Process Duties ---

// 1. Parse Command-Line Arguments
//    - Get num_nodes, topology_type, and algorithm_type from the input.

pub fn main() {
  let args = argv.load().arguments

  case parser.parse_args(args) {
    Ok(parsed) -> {
      let state =
        MainState(
          actors_remaining: parsed.num_nodes,
          total_actors: parsed.num_nodes,
          start_time: 0,
        )

      let spec =
        actor.spec(main_loop)
        |> actor.from_state(state)
        |> actor.start

      assert Ok(main_subject) = spec

      let subjects =
        builder.build(
          parsed.num_nodes,
          parsed.topology,
          parsed.algorithm,
          main_subject,
        )

      // Tell the main actor to start the simulation.
      process.send(
        main_subject,
        StartSimulation(subjects: subjects, algorithm: parsed.algorithm),
      )
    }
    Error(msg) -> io.println(msg)
  }
}

// The main actor's message-handling loop.
fn main_loop(message: MainMessage, state: MainState) -> actor.Next(MainState) {
  case message {
    StartSimulation(subjects, _) -> {
      let start_time = process.system_time(process.Millisecond)
      let new_state = MainState(..state, start_time: start_time)

      // Start the protocol on the first node.
      case list.first(subjects) {
        Ok(first_node) -> {
          case first_node {
            builder.Gossip(gossip_node) ->
              process.send(gossip_node, gossip_algo.Gossip)
            builder.PushSum(push_sum_node) ->
              process.send(push_sum_node, push_sum.StartPushSum)
          }
        }
        Error(_) -> io.println("Error: No actors were created.")
      }
      actor.Continue(new_state)
    }

    ActorFinished(average) -> {
      case average {
        Some(avg) ->
          io.println("Node finished with average: " <> float.to_string(avg))
        None -> Nil
      }

      let new_remaining = state.actors_remaining - 1
      let finish_threshold = (state.total_actors * 99) / 100

      case (state.total_actors - new_remaining) >= finish_threshold {
        True -> {
          let end_time = process.system_time(process.Millisecond)
          let duration = end_time - state.start_time
          io.println("All actors finished.")
          io.println("Convergence time: " <> int.to_string(duration) <> " ms")
          actor.Stop(process.Normal)
        }
        False -> {
          let new_state = MainState(..state, actors_remaining: new_remaining)
          actor.Continue(new_state)
        }
      }
    }
  }
}
