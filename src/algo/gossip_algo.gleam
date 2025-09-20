// ---gossip algo ---

// create a sub_list of subjects of lenght N+1
//inside  a loop of 1...N do : 
//     initialize a actor/
//     store its subject at sub_list[i]
// 

//inside a loop of 1...N again
//     update the state : provide the actors its own subject and the subject of its neighbours in a list
//     to find the neighbours call the relevant function in topology



// 2. Message Handling (Main Loop)
//    - Wait for and react to different messages:
//      - On `SetNeighbors(subjects)`: Store the list of subjects in my state.
//      - On `Gossip` from a neighbor: Update my `rumor_heard_count`. Check if I'm finished.
//      - On `PushSum(s, w)` from a neighbor: Update my `s` and `w` values. Check if I'm finished.
//      - On `GossipTick` from myself:
//        - Pick a random neighbor subject from my list.
//        - Send it the appropriate message (`Gossip` or `PushSum(s/2, w/2)`).

// 3. Termination Logic
//    - After handling any message, check if my termination condition is met:
//      - (For gossip: `rumor_heard_count` >= 10?)
//      - (For push-sum: `s/w` ratio is stable for 3 rounds?)
//    - If the condition is met:
//      - Send one final `ActorFinished` message to the `main_pid`.
//      - Stop my own process.

import gleam/otp/actor
import gleam/erlang/process.{Pid, Subject, send_after}
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/prng
import gossip_protocol/topology/line
import gossip_protocol/topology/full_network
import gossip_protocol/topology/imperfect_3D
import gossip_protocol/topology/three_D

// A unique, type-safe handle for communicating with an actor.
pub type NodeSubject =
  Subject(Message)

// All possible messages an actor can receive for the gossip algorithm.
pub type Message {
  // From Main: The initial configuration of this node's neighbors.
  SetNeighbors(subjects: List(NodeSubject))
  // From Main or Neighbor: The message that starts the gossip process.
  Gossip
  // From Self: A recurring timer tick that triggers this node to act.
  GossipTick
}

// All the data a node needs to remember.
pub type State {
  State(
    main_pid: Pid, // The PID of the main process to report back to.
    neighbors: List(NodeSubject), // A list of neighbor subjects to talk to.
    has_rumor: Bool, // Tracks if this node has heard the rumor yet.
    rumor_heard_count: Int, // How many times this node has heard the rumor.
    is_active: Bool, // Tracks if this node should still be sending messages.
    prng: prng.Prng, // A random number generator for picking neighbors.
  )
}

// The message type the Main process expects.
pub type MainMessage {
  ActorSubjectIs(subject: NodeSubject)
  ActorFinished
}

// This is the actor's main message-handling loop.
pub fn loop(message: Message, state: State) -> actor.Next(State) {
  case message {
    // ---- Handle receiving the neighbor list from Main ----
    SetNeighbors(subjects) -> {
      let new_state = State(..state, neighbors: subjects)
      actor.Continue(new_state)
    }

    // ---- Handle receiving a gossip message ----
    Gossip -> {
      let new_count = state.rumor_heard_count + 1
      let mut new_state = State(..state, rumor_heard_count: new_count)

      // How an actor becomes active:
      // If this is the FIRST time hearing the rumor, become active and start
      // our own periodic timer to begin gossiping to others.
      if !state.has_rumor {
        new_state = State(..new_state, has_rumor: True, is_active: True)
        send_after(GossipTick, 100) // Send the first tick to ourself.
      }

      // How an actor becomes inactive:
      // If we've heard the rumor 10 times, we stop gossiping.
      if new_count >= 10 && state.is_active {
        new_state = State(..new_state, is_active: False)
        // Our final duty: tell Main we are finished.
        process.send(state.main_pid, ActorFinished)
      }

      actor.Continue(new_state)
    }

    // ---- Handle our own periodic timer tick ----
    GossipTick -> {
      // Only send a message if we are still active.
      if state.is_active {
        case list.is_empty(state.neighbors) {
          True -> actor.Continue(state)
          False -> {
            let #(index, new_prng) =
              prng.int(state.prng, 0, list.length(state.neighbors) - 1)
            let neighbor = result.unwrap(
              list.at(state.neighbors, index),
              // This is safe because we checked that the list is not empty.
              list.first(state.neighbors) |> result.unwrap(Nil),
            )
            process.send(neighbor, Gossip)
            send_after(GossipTick, 100)
            actor.Continue(State(..state, prng: new_prng))
          }
        }
      } else {
        // If we get a tick but are no longer active, just ignore it.
        actor.Continue(state)
      }
    }
  }
}

// The public function used by the topology builder to start a new actor.
pub fn start(
  main_pid: Pid,
  prng: prng.Prng,
) -> Result(NodeSubject, actor.StartError) {
  actor.new_with_initialiser(fn(self_subject) {
    let state = State(
      main_pid: main_pid,
      neighbors: [],
      has_rumor: False,
      rumor_heard_count: 0,
      is_active: False, // An actor starts in an inactive state.
      prng: prng,
    )
    process.send(main_pid, ActorSubjectIs(self_subject))
    Ok(actor.initialised(state))
  })
  |> actor.on_message(loop)
  |> actor.start()
}

pub fn build(
  num_nodes: Int,
  topology: String,
  main_pid: Pid,
) -> List(NodeSubject) {
  // --- PHASE 1: SPAWN AND COLLECT ---
  let prng = prng.new(123)
  let subjects =
    list.range(0, num_nodes - 1)
    |> list.try_map(fn(_) { start(main_pid, prng) })
    |> result.unwrap([])

  // --- PHASE 2: CONFIGURE AND DISTRIBUTE ---
  list.each_with_index(subjects, fn(subject, i) {
    let neighbour_indices = case topology {
      "line" -> line.find_neighbours(i, num_nodes)
      "full" -> full_network.find_neighbours(i, num_nodes)
      "3D" -> three_D.find_neighbours(i, num_nodes)
      "imp3D" -> imperfect_3D.find_neighbours(i, num_nodes)
      _ -> []
    }
    let neighbour_subjects =
      list.filter_map(neighbour_indices, fn(index) { list.at(subjects, index) })
    process.send(subject, SetNeighbors(neighbour_subjects))
  })

  subjects
}