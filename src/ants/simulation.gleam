import ants/config
import ants/direction
import ants/position.{Position}
import ants/board.{Board}
import ants/ant.{Ant}
import gleam/io
import gleam/pair
import gleam/list
import gleam/option.{None, Some}
import gleam/otp/actor.{Continue, InitResult, Next, Ready, Spec, StartError}
import gleam/otp/process.{Sender}

pub fn init() -> InitResult(Simulation, Msg) {
  io.println("Spawning ants")

  let board = spawn_board()
  let ants = spawn_ants(board)
  io.println("Simulation started!")

  let simulation = Simulation(board: board, ants: ants)
  Ready(simulation, receiver: None)
}

pub type Simulation {
  Simulation(board: Sender(board.Msg), ants: List(Sender(ant.Msg)))
}

pub type State {
  State(board: Board, ants: List(Ant))
}

pub type Msg {
  GiveState(to: Sender(State))
}

pub fn update(msg: Msg, sim: Simulation) -> Next(Simulation) {
  case msg {
    GiveState(chan) -> give_state(chan, sim)
  }
}

fn give_state(chan: Sender(State), sim: Simulation) -> Next(Simulation) {
  let board: Board = actor.call(sim.board, board.GiveBoard, 100)
  let ants: List(Ant) =
    sim.ants
    |> list.map(fn(ant) { actor.call(ant, ant.GiveAnt, 100) })
  let state: State = State(board: board, ants: ants)
  actor.send(chan, state)
  Continue(sim)
}

fn spawn_board() -> Sender(board.Msg) {
  let new_board: Board = board.new()
  assert Ok(sender) = actor.start(new_board, board.update)
  start_evaporation_timer(sender)
  sender
}

fn spawn_ants(board) -> List(Sender(ant.Msg)) {
  let ants =
    list.range(0, config.ants_count)
    |> list.map(fn(i) {
      let direction = direction.random()
      let position = position.from_int(i)
      let new_ant: Ant = ant.new(direction, position)
      assert Ok(sender) =
        actor.start(new_ant, fn(msg, ant) { ant.update(board, msg, ant) })
      start_ant_timer(sender)
      #(sender, position)
    })
  ants
  |> list.each(fn(ant: #(Sender(ant.Msg), Position)) {
    let position = ant.1
    actor.send(board, board.AntStartsAt(position))
  })

  list.map(ants, pair.first)
}

fn start_ant_timer(ant: Sender(ant.Msg)) {
  run_periodically(
    every: config.ant_tick_ms,
    run: fn() { actor.send(ant, ant.Tick) },
  )
}

fn start_evaporation_timer(board: Sender(board.Msg)) {
  run_periodically(
    every: config.evaporation_tick_ms,
    run: fn() { actor.send(board, board.Evaporate) },
  )
}

/// Taken from:
/// https://github.com/gleam-lang/otp/blob/main/test/gleam/periodic_actor.gleam
fn run_periodically(
  every period_milliseconds: Int,
  run callback: fn() -> a,
) -> Result(Sender(Nil), StartError) {
  let init = fn() {
    let #(sender, receiver) = process.new_channel()
    process.send(sender, Nil)
    Ready(sender, Some(receiver))
  }

  let loop = fn(_msg, sender) {
    process.send_after(sender, period_milliseconds, Nil)
    callback()
    Continue(sender)
  }

  actor.start_spec(Spec(init: init, loop: loop, init_timeout: 100))
}
