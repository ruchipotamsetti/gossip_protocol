import gleam/erlang/process
import gleam/erlang/process.{send_after}
import gleam/list
import gleam/otp/actor
import gleam/random
import gossip_protocol.{type MainMessage, ActorFinished}
import topology/full_network
import topology/imperfect_three_d
import topology/line
import topology/three_d

// A subject that can receive gossip-messages
pub type NodeSubject =
  process.Subject(Message)

// Messages this actor understands
pub type Message {
  SetNeighbours(List(NodeSubject))
  Gossip
  // somebody sent us the rumour
  Tick
  // internal timer
}

// Node-state
pub type State {
  State(
    main: process.Subject(MainMessage),
    self: NodeSubject,
    neighbours: List(NodeSubject),
    heard_cnt: Int,
    active: Bool,
  )
}

// ------------ public entry points ---------------------------------

pub fn start(
  main: process.Subject(MainMessage),
) -> Result(NodeSubject, actor.StartError) {
  actor.new(fn(self_subj) {
    let st =
      State(
        main: main,
        self: self_subj,
        neighbours: [],
        heard_cnt: 0,
        active: False,
      )
    Ok(actor.initialised(st))
  })
  |> actor.on_message(loop)
  |> actor.start()
}

// Factory for all nodes, used by builder.gleam
pub fn build(
  nodes: Int,
  topology: String,
  main: process.Subject(MainMessage),
) -> List(NodeSubject) {
  let subjects =
    list.range(1, nodes)
    |> list.try_map(fn(_) { start(main) })
    |> result.unwrap([])

  list.indexed_map(subjects, fn(i, sub) {
    let idx = i + 1
    let idxs = case topology {
      "line" -> line.find_neighbours(idx, nodes)
      "full" -> full_network.find_neighbours(idx, nodes)
      "3D" -> three_d.find_neighbours(idx, nodes)
      "imp3D" -> imperfect_three_d.find_neighbours(idx, nodes)
      _ -> []
    }
    let neighs = list.filter_map(idxs, fn(j) { list.get(subjects, j - 1) })
    process.send(sub, SetNeighbours(neighs))
  })

  subjects
}

// ------------------------------------------------------------------

fn loop(state: State, msg: Message) -> actor.Next(State, Message) {
  case msg {
    SetNeighbours(ns) -> actor.continue(State(..state, neighbours: ns))

    Gossip -> gossip_received(state)

    Tick -> on_tick(state)
  }
}

// ------- helpers --------------------------------------------------

fn gossip_received(state: State) -> actor.Next(State, Message) {
  let cnt = state.heard_cnt + 1
  let state1 = State(..state, heard_cnt: cnt)

  let state2 = case state.active {
    False -> {
      process.send_after(state.self, 30, Tick)
      // start ticking
      State(..state1, active: True)
    }
    True -> state1
  }

  case cnt >= 10 {
    True -> {
      process.send(state.main, ActorFinished(None))
      actor.stop()
    }
    False -> actor.continue(state2)
  }
}

fn on_tick(state: State) -> actor.Next(State, Message) {
  case state.active {
    False -> actor.continue(state)
    True -> {
      case get_random(state.neighbours) {
        None -> actor.continue(state)
        Some(n) -> {
          process.send(n, Gossip)
          process.send_after(state.self, 30, Tick)
          actor.continue(state)
        }
      }
    }
  }
}

// ------------- small util because std-lib hasn’t get_random --------
fn get_random(xs: List(a)) -> Option(a) {
  case list.length(xs) {
    0 -> None
    len -> {
      let idx = random.int(0, len - 1)
      result.to_option(list.get(xs, idx))
    }
  }
}
