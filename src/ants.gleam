import gleam/erlang
import ants/server
import ants/simulation

pub fn main() {
  simulation.start()
  server.start()

  erlang.sleep_forever()
}
