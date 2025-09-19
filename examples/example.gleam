import gleam/erlang/process
import gleam/int
//import gleam/io
import gleam/list
import gleam/otp/actor
import gleam/result
//import gleam/string

// Message from worker -> boss
pub type BossMsg {
  WorkerReady(process.Subject(WorkerMsg))
  WorkerDone(results: List(Int), from: process.Subject(WorkerMsg))
}

// Message from boss -> worker
pub type WorkerMsg {
  Work(start: Int, end_: Int, k: Int)
  Shutdown
}

pub type State {
  State(
    next: Int,
    n: Int,
    k: Int,
    chunk: Int,
    pending: Int,
    acc: List(Int),
    reply: process.Subject(List(Int)),
  )
}

pub fn start(
  n: Int,
  k: Int,
  chunk: Int,
  workers: Int,
  reply_to: process.Subject(List(Int)),
) -> Result(process.Subject(BossMsg), actor.StartError) {
  let init = State(1, n, k, chunk, workers, [], reply_to)

  actor.new(init)
  |> actor.on_message(handle)
  |> actor.start
  |> result.map(fn(started) { started.data })
}

fn handle(state: State, msg: BossMsg) -> actor.Next(State, BossMsg) {
  let State(next, n, k, chunk, pending, acc, reply_to) = state
  case msg {
    WorkerReady(worker) -> {
      case next <= n {
        True -> {
          let start = next
          let end_ = int.min(start + chunk - 1, n)
          // send work
          //let assert Ok(pid) = process.subject_owner(worker)
          //let pid_str = string.inspect(pid)
          //io.println("Boss: assigning " <> int.to_string(start) <> "-" <> int.to_string(end_) <> " to " <> pid_str)
          process.send(worker, Work(start, end_, k))
          let new_state = State(end_ + 1, n, k, chunk, pending, acc, reply_to)
          actor.continue(new_state)
        }
        False -> {
          process.send(worker, Shutdown)
          let new_state = State(next, n, k, chunk, pending - 1, acc, reply_to)
          case pending - 1 == 0 {
            True -> {
              let sorted = list.sort(acc, int.compare)
              process.send(reply_to, sorted)
              actor.stop()
            }
            False -> actor.continue(new_state)
          }
        }
      }
    }
    WorkerDone(res, _worker) -> {
      let new_acc = list.append(res, acc)
      let new_state = State(next, n, k, chunk, pending, new_acc, reply_to)
      actor.continue(new_state)
    }
  }
}


pub type State2 {
  State2(boss: process.Subject(BossMsg), self: process.Subject(WorkerMsg))
}

/// Start a worker linked to the given boss subject.
pub fn start(
  boss: process.Subject(BossMsg),
) -> Result(process.Subject(WorkerMsg), actor.StartError) {
  // Initialiser sends WorkerReady to boss and returns state containing boss + self
  actor.new_with_initialiser(100, fn(self_subject) {
    process.send(boss, WorkerReady(self_subject))
    let state = State2(boss, self_subject)
    let init = actor.initialised(state)
    let init2 = actor.returning(init, self_subject)
    Ok(init2)
  })
  |> actor.on_message(handle)
  |> actor.start
  |> result.map(fn(started) { started.data })
}

fn handle(state: State2, msg: WorkerMsg) -> actor.Next(State2, WorkerMsg) {
  let State2(boss, self) = state
  case msg {
    Work(start, end_, k) -> {
      //let pid_str = string.inspect(process.self())
      //io.println("Worker " <> pid_str <> " processing " <> int.to_string(start) <> ".." <> int.to_string(end_))
      let solutions = squares.scan_range(start, end_, k)
      process.send(boss, WorkerDone(solutions, self))
      // ask for more work
      process.send(boss, WorkerReady(self))
      actor.continue(state)
    }
    Shutdown -> actor.stop()
  }
}