import gleam/erlang/process
import gleam/erlang/process.{send_after}
import gleam/float
import gleam/list
import gleam/option.{None, Some}
import gleam/otp/actor
import gleam/random
import gleam/result
import topology/full_network
import topology/imperfect_three_d
import topology/line
import topology/three_d

pub type NodeSubject =
  process.Subject(Message)

pub type Message {
  SetNeighbours(List(NodeSubject))
  Start
  Pair(s: Float, w: Float)
  Tick
}

pub type State {
  State(
    main: process.Subject(a),
    neighbours: List(NodeSubject),
    s: Float,
    w: Float,
    history: List(Float),
    active: Bool,
  )
}

const scale = 10_000_000_000_000_000.0

pub fn start(
  main: process.Subject(a),
  id: Int,
) -> Result(NodeSubject, actor.StartError) {
  actor.new(
    State(
      main: main,
      neighbours: [],
      s: float.from_int(id) *. scale,
      w: scale,
      history: [],
      active: False,
    ),
    loop,
  )
  |> actor.start
}

pub fn build(
  nodes: Int,
  topology: String,
  main: process.Subject(a),
) -> List(NodeSubject) {
  let subs =
    list.range(1, nodes)
    |> list.try_map(fn(i) { start(main, i) })
    |> result.unwrap([])

  list.indexed_map(subs, fn(i, sub) {
    let idx = i + 1
    let idxs = case topology {
      "line" -> line.find_neighbours(idx, nodes)
      "full" -> full_network.find_neighbours(idx, nodes)
      "3D" -> three_d.find_neighbours(idx, nodes)
      "imp3D" -> imperfect_three_d.find_neighbours(idx, nodes)
      _ -> []
    }
    let neighs = list.filter_map(idxs, fn(j) { list.get(subs, j - 1) })
    process.send(sub, SetNeighbours(neighs))
  })

  subs
}

// --------- loop --------------------------------------------------

fn loop(state: State, msg: Message) -> actor.Next(State, Message) {
  case msg {
    SetNeighbours(ns) -> actor.continue(State(..state, neighbours: ns))

    Start -> {
      send_after(Tick, 30)
      actor.continue(State(..state, active: True))
    }

    Pair(s, w) -> actor.continue(State(..state, s: state.s + s, w: state.w + w))

    Tick -> on_tick(state)
  }
}

fn on_tick(state: State) -> actor.Next(State, Message) {
  case state.active && !list.is_empty(state.neighbours) {
    False -> actor.continue(state)
    True -> {
      // choose neighbour
      let idx = random.int(0, list.length(state.neighbours) - 1)
      let neigh =
        result.unwrap(
          list.get(state.neighbours, idx),
          // idx is in range, but provide fallback to satisfy type checker
          result.unwrap(list.first(state.neighbours), panic("empty")),
        )

      let s_half = state.s / 2.0
      let w_half = state.w / 2.0
      let new_state = State(..state, s: state.s - s_half, w: state.w - w_half)

      process.send(neigh, Pair(s_half, w_half))

      case stable(new_state) {
        True -> {
          let ratio = new_state.s /. new_state.w
          process.send(state.main, Some(ratio))
          actor.stop()
        }
        False -> {
          send_after(Tick, 30)
          actor.continue(new_state)
        }
      }
    }
  }
}

// termination check: 3 consecutive ratios within 1e-10
fn stable(state: State) -> Bool {
  let r = state.s /. state.w
  let hist = [r, ..state.history] |> list.take(3)
  case hist {
    [a, b, c] ->
      float.absolute_value(a -. b) < 1.0e-10
      && float.absolute_value(b -. c) < 1.0e-10
    _ -> False
  }
}
