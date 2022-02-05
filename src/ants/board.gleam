import ants/position.{Position}
import ants/config
import ants/cell.{Cell}
import gleam/bool
import gleam/option.{Option}
import gleam/set.{Set}
import gleam/map.{Map}
import gleam/io
import gleam/list
import gleam/otp/actor.{Continue, Next}
import gleam/otp/process.{Sender}

pub type Board {
  Board(cells: Map(Position, Cell))
}

pub fn get_cell(board: Board, position: Position) -> Option(Cell) {
  board.cells
  |> map.get(position)
  |> option.from_result
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
    |> list.map(fn(position) { #(position, cell.HomeCell) })

  let food_cells: List(#(Position, Cell)) =
    sample_n(n: config.food_places, from: possible_food_positions)
    |> list.map(fn(position) {
      #(position, cell.FoodCell(random_int(config.food_range + 1) - 1))
    })

  let cells =
    [home_cells, food_cells]
    |> list.flatten
    |> map.from_list

  Board(cells: cells)
}

pub type Msg {
  Evaporate
  TakeFood(position: Position)
  MarkWithPheromone(position: Position)
  GiveCellInfo(position: Position, to: Sender(Option(Cell)))
  GiveBoard(to: Sender(Board))
}

pub fn update(msg: Msg, board: Board) -> Next(Board) {
  case msg {
    Evaporate -> evaporate(board)
    TakeFood(position) -> take_food(position, board)
    MarkWithPheromone(position) -> mark_with_pheromone(position, board)
    GiveCellInfo(position, chan) -> give_cell_info(position, chan, board)
    GiveBoard(chan) -> give_board(chan, board)
  }
}

fn evaporate(board: Board) -> Next(Board) {
  Continue(
    Board(
      ..board,
      cells: board.cells
      |> map.map_values(fn(_, cell) {
        case cell {
          cell.PheromoneCell(amount) ->
            cell.PheromoneCell(amount *. config.evaporation_rate)
          _ -> cell
        }
      }),
    ),
  )
}

fn take_food(position: Position, board: Board) -> Next(Board) {
  todo("take_food board")
}

fn mark_with_pheromone(position: Position, board: Board) -> Next(Board) {
  todo("mark_with_pheromone board")
}

fn give_cell_info(
  position: Position,
  reply_chan: Sender(Option(Cell)),
  board: Board,
) -> Next(Board) {
  let cell = get_cell(board, position)
  actor.send(reply_chan, cell)
  Continue(board)
}

fn give_board(reply_chan: Sender(Board), board: Board) -> Next(Board) {
  actor.send(reply_chan, board)
  Continue(board)
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
