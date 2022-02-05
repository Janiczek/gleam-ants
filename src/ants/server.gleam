import ants/config
import ants/position.{Position}
import ants/cell.{Cell}
import ants/ant.{Ant}
import ants/direction
import ants/simulation
import gleam/io
import gleam/list
import gleam/map.{Map}
import gleam/string
import gleam/int
import gleam/http/elli
import gleam/http/response.{Response}
import gleam/http/request.{Request}
import gleam/bit_builder.{BitBuilder}
import gleam/otp/process.{Sender}
import gleam/otp/actor
import gleam/json.{Json}

const port: Int = 3000

pub fn start(sim: Sender(simulation.Msg)) {
  let _ = elli.start(fn(req) { http_server(sim, req) }, on_port: port)
  io.println(string.concat(["Started listening on port ", int.to_string(port)]))
}

fn http_server(
  sim: Sender(simulation.Msg),
  _req: Request(BitString),
) -> Response(BitBuilder) {
  let body =
    get_state(sim)
    |> state_to_json
    |> json.to_string_builder
    |> bit_builder.from_string_builder

  response.new(200)
  |> response.prepend_header("Access-Control-Allow-Origin", "*")
  |> response.prepend_header("Content-Type", "application/json")
  |> response.set_body(body)
}

fn get_state(sim: Sender(simulation.Msg)) -> simulation.State {
  actor.call(sim, simulation.GiveState, 50)
}

fn state_to_json(state: simulation.State) -> Json {
  json.object([
    #("size", json.int(config.board_width)),
    #(
      "cells",
      map_to_json(state.board.cells, key: position_to_json, val: cell_to_json),
    ),
    #(
      "ants",
      state.ants
      |> list.map(fn(ant: Ant) { #(ant.position, ant) })
      |> map.from_list
      |> map_to_json(key: position_to_json, val: ant_to_json),
    ),
  ])
}

fn position_to_json(position: Position) -> Json {
  json.array([position.0, position.1], of: json.int)
}

fn cell_to_json(cell: Cell) -> Json {
  case cell {
    cell.HomeCell -> json.object([#("type", json.string("home"))])
    cell.FoodCell(food_count) ->
      json.object([
        #("type", json.string("food")),
        #("count", json.int(food_count)),
      ])
    cell.PheromoneCell(pheromone_amount) ->
      json.object([
        #("type", json.string("pheromone")),
        #("amount", json.float(pheromone_amount)),
      ])
  }
}

fn ant_to_json(ant: Ant) -> Json {
  json.object([
    #(
      "status",
      case ant.status {
        ant.AntWithFood -> "with-food"
        ant.AntWithoutFood -> "without-food"
      }
      |> json.string,
    ),
    #(
      "direction",
      case ant.direction {
        direction.N -> "n"
        direction.NE -> "ne"
        direction.E -> "e"
        direction.SE -> "se"
        direction.S -> "s"
        direction.SW -> "sw"
        direction.W -> "w"
        direction.NW -> "nw"
      }
      |> json.string,
    ),
  ])
}

fn map_to_json(
  map: Map(k, v),
  key key_to_json: fn(k) -> Json,
  val val_to_json: fn(v) -> Json,
) -> Json {
  json.array(
    map.to_list(map),
    of: fn(pair) {
      let #(key, val) = pair
      json.preprocessed_array([key_to_json(key), val_to_json(val)])
    },
  )
}
