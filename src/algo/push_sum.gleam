import gleam/erlang/process as process
import gleam/erlang/process.{send_after}
import gleam/int
import gleam/float
import gleam/list
import gleam/option.{None, Some}
import gleam/otp/actor
import gleam/prng
import gleam/result
import gossip_protocol/gossip_protocol.{type MainMessage, ActorFinished}
import gossip_protocol/topology/full_network
import gossip_protocol/topology/imperfect_3D
import gossip_protocol/topology/line
import gossip_protocol/topology/three_D

// A unique, type-safe handle for communicating with an actor.
pub type NodeSubject =
  process.Subject(Message)

// All possible messages an actor can receive for the push-sum algorithm.
pub type Message {
  SetNeighbors(subjects: List(NodeSubject))
  StartPushSum
  PushSum(s: Int, w: Int)
  PushSumTick
}

// All the data a node needs to remember.
pub type State {
  State(
    s: Int,
    w: Int,
    main_subject: process.Subject(MainMessage),
    neighbors: List(NodeSubject),
    ratio_history: List(Float),
    prng: prng.Prng,
    is_active: Bool,
  )
}

// The scaling factor for our fixed-point arithmetic. 10^16.
const scaling_factor = 1_000_000_000_000_0000

pub fn build(
  num_nodes: Int,
  topology: String,
  main_subject: process.Subject(MainMessage),
) -> List(NodeSubject) {
  // --- PHASE 1: SPAWN AND COLLECT ---
  let prng = prng.new(123)
  let subjects =
    list.range(1, num_nodes)
    |> list.try_map(fn(i) { start(main_subject, i, prng) })
    |> result.unwrap([])

  // --- PHASE 2: CONFIGURE AND DISTRIBUTE ---
  list.each_with_index(subjects, fn(subject, i) {
    let node_index = i + 1
    let neighbour_indices = case topology {
      "line" -> line.find_neighbours(node_index, num_nodes)
      "full" -> full_network.find_neighbours(node_index, num_nodes)
      "3D" -> three_D.find_neighbours(node_index, num_nodes)
      "imp3D" -> imperfect_3D.find_neighbours(node_index, num_nodes)
      _ -> []
    }
    let neighbour_subjects =
      list.filter_map(neighbour_indices, fn(index) { list.at(subjects, index - 1) })
    process.send(subject, SetNeighbors(neighbour_subjects))
  })

  subjects
}

pub fn start(
  main_subject: process.Subject(MainMessage),
  initial_s: Int,
  prng: prng.Prng,
) -> Result(NodeSubject, actor.StartError) {
  actor.new_with_initialiser(fn(self_subject) {
    let state = State(
      s: initial_s * scaling_factor,
      w: scaling_factor,
      main_subject: main_subject,
      neighbors: [],
      ratio_history: [],
      prng: prng,
      is_active: False,
    )
    Ok(actor.initialised(state))
  })
  |> actor.on_message(loop)
  |> actor.start()
}

// The actor's main message-handling loop.
pub fn loop(msg: Message, state: State) -> actor.Next(State) {
  case msg {
    SetNeighbors(subjects) -> {
      let new_state = State(..state, neighbors: subjects)
      actor.Continue(new_state)
    }

    StartPushSum -> {
      send_after(PushSumTick, 100)
      actor.Continue(State(..state, is_active: True))
    }

    PushSum(s, w) -> {
      let new_state = State(..state, s: state.s + s, w: state.w + w)
      send_after(PushSumTick, 1) // Send immediately after receiving
      actor.Continue(new_state)
    }

    PushSumTick -> {
      if state.is_active {
        case list.is_empty(state.neighbors) {
          True -> actor.Continue(state)
          False -> {
            let #(index, new_prng) =
              prng.int(state.prng, 0, list.length(state.neighbors) - 1)
            let neighbor = result.unwrap(list.at(state.neighbors, index), Nil)

            let s_to_send = state.s / 2
            let w_to_send = state.w / 2
            let new_s = state.s - s_to_send
            let new_w = state.w - w_to_send
            let mut new_state = State(..state, s: new_s, w: new_w, prng: new_prng)

            process.send(neighbor, PushSum(s_to_send, w_to_send))

            case check_termination(new_state) {
              Ok(terminated_state) -> {
                let final_ratio =
                  float.from_int(terminated_state.s)
                  /. float.from_int(terminated_state.w)
                process.send(
                  terminated_state.main_subject,
                  ActorFinished(average: Some(final_ratio)),
                )
                actor.Stop(process.Normal)
              }
              Error(active_state) -> {
                send_after(PushSumTick, 100)
                actor.Continue(active_state)
              }
            }
          }
        }
      } else {
        actor.Continue(state)
      }
    }
  }
}

// Checks if the s/w ratio has stabilized.
fn check_termination(state: State) -> Result(State, State) {
  let current_ratio =
    float.from_int(state.s) /. float.from_int(state.w)

  let new_history = list.prepend(state.ratio_history, current_ratio)
  let new_history = case list.length(new_history) > 3 {
    True -> result.unwrap(list.drop_right(new_history, 1), [])
    False -> new_history
  }
  let new_state = State(..state, ratio_history: new_history)

  case list.length(new_history) < 3 {
    True -> Error(new_state)
    False -> {
      let first = result.unwrap(list.at(new_history, 0), 0.0)
      let second = result.unwrap(list.at(new_history, 1), 0.0)
      let third = result.unwrap(list.at(new_history, 2), 0.0)

      let diff1 = float.absolute_value(first -. second)
      let diff2 = float.absolute_value(second -. third)

      case diff1 < 1.0e-10 && diff2 < 1.0e-10 {
        True -> Ok(new_state)
        False -> Error(new_state)
      }
    }
  }
} 
