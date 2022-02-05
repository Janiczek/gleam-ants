import gleam/io
import gleam/string
import gleam/int
import gleam/http/elli
import gleam/http/response.{Response}
import gleam/http/request.{Request}
import gleam/bit_builder.{BitBuilder}

const port: Int = 3000

pub fn start() {
  elli.start(http_server, on_port: port)
  io.println(string.concat(["Started listening on port ", int.to_string(port)]))
}

fn http_server(req: Request(BitString)) -> Response(BitBuilder) {
  let body = bit_builder.from_string("Hello, world!")

  response.new(200)
  |> response.prepend_header("Access-Control-Allow-Origin","*")
  |> response.set_body(body)
}
