import ants/config
import ants/direction
import ants/position
import ants/ant.{Ant}
import gleam/io
import gleam/list
import gleam/option.{Some}
import gleam/otp/actor.{Continue, Ready, Spec, StartError}
import gleam/otp/process.{Sender}

pub fn start() {
  io.println("Spawning ants")

  spawn_ants()
  start_evaporation_timer()
  io.println("Simulation started!")
}

fn spawn_ants() {
  list.range(0, config.ants_count)
  |> list.each(fn(i) {
    let direction = direction.random()
    // TODO make the positions random instead of sequential
    let position = position.from_int(i)
    let new_ant: Ant = ant.new(direction, position)
    assert Ok(sender) = actor.start(new_ant, ant.update)
    start_ant_timer(sender)
  })
}

fn start_ant_timer(ant) {
  run_periodically(
    every: config.ant_tick_ms,
    run: fn() { io.println("TODO: send Tick to the ant") },
  )
  //run: fn() { process.send(ant, ant.Tick) }
}

fn start_evaporation_timer() {
  run_periodically(
    every: config.evaporation_tick_ms,
    run: fn() { io.println("TODO: evaporate a little") },
  )
}

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

  actor.start_spec(Spec(init: init, loop: loop, init_timeout: 50))
}
