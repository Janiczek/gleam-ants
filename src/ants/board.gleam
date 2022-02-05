///// TODO: this would be nice to have in the stdlib

import ants/position.{Position}
import ants/config
import ants/cell.{Cell, FoodCell, HomeCell}
import gleam/bool
import gleam/set.{Set}
import gleam/map.{Map}
import gleam/io
import gleam/list
import gleam/otp/actor.{Continue, Next}

pub type Board {
  Board(cells: Map(Position, Cell))
}

pub fn new() -> Board {
  let all_positions = position.all_positions()
  let home_positions = position.home_positions()
  let possible_food_positions =
    set.from_list(all_positions)
    |> set_diff(without: set.from_list(home_positions))
    |> set.to_list

  let home_cells: List(#(Position, Cell)) =
    home_positions
    |> list.map(fn(position) { #(position, HomeCell) })

  let food_cells: List(#(Position, Cell)) =
    sample_n(n: config.food_places, from: possible_food_positions)
    |> list.map(fn(position) {
      #(position, FoodCell(random_int(config.food_range)))
    })

  io.debug(food_cells)

  let cells =
    [home_cells, food_cells]
    |> list.flatten
    |> map.from_list
  Board(cells: cells)
}

pub type Msg {
  Evaporate
}

pub fn update(msg: Msg, board: Board) -> Next(Board) {
  case msg {
    Evaporate -> evaporate(board)
  }
}

fn evaporate(board: Board) -> Next(Board) {
  io.debug(board)
  todo("evaporate board")
}

/// TODO: this would be nice to have in the stdlib
fn set_diff(original superset: Set(a), without to_delete: Set(a)) -> Set(a) {
  superset
  |> set.filter(fn(item) { bool.negate(set.contains(to_delete, item)) })
}

/// TODO I wish this worked. Instead we'll take first N items for now.
/// TODO: this would be nice to have in the stdlib
/// external fn sample_n(from: List(a), n: Int) -> List(a) =
///   "Elixir.Enum" "take_random"
fn sample_n(from list: List(a), n count: Int) -> List(a) {
  list
  |> list.take(count)
}

external fn random_int(n: Int) -> Int =
  "rand" "uniform"
