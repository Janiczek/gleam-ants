import ants/server
import ants/simulation
import gleam/erlang
import gleam/otp/actor.{Spec}

pub fn main() {
  assert Ok(sim_chan) =
    actor.start_spec(Spec(
      init: simulation.init,
      loop: simulation.update,
      init_timeout: 50,
    ))
  server.start(sim_chan)

  erlang.sleep_forever()
}
