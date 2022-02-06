import ants/position.{Position}
import ants/config
import ants/cell.{Cell}
import gleam/bool
import gleam/set.{Set}
import gleam/map.{Map}
import gleam/result
import gleam/io
import gleam/list
import gleam/otp/actor.{Continue, Next}
import gleam/otp/process.{Sender}

pub type Board {
  Board(cells: Map(Position, Cell))
}

pub fn get_cell(board: Board, position: Position) -> Cell {
  board.cells
  |> map.get(position)
  |> result.unwrap(cell.empty)
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
    |> list.map(fn(position) {
      #(position, Cell(pheromone: 0., is_home: True, food: 0, has_ant: False))
    })

  let food_cells: List(#(Position, Cell)) =
    sample_n(n: config.food_places, from: possible_food_positions)
    |> list.map(fn(position) {
      #(
        position,
        Cell(
          pheromone: 0.,
          is_home: False,
          food: random_int(config.food_range + 1) - 1,
          has_ant: False,
        ),
      )
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
  GiveCellInfo(position: Position, to: Sender(Cell))
  GiveBoard(to: Sender(Board))
  AntMovedFromTo(old: Position, new: Position)
  AntStartsAt(position: Position)
}

pub fn update(msg: Msg, board: Board) -> Next(Board) {
  case msg {
    Evaporate -> evaporate(board)
    TakeFood(position) -> take_food(position, board)
    MarkWithPheromone(position) -> mark_with_pheromone(position, board)
    GiveCellInfo(position, chan) -> give_cell_info(position, chan, board)
    GiveBoard(chan) -> give_board(chan, board)
    AntMovedFromTo(old, new) -> ant_moved_from_to(old, new, board)
    AntStartsAt(position) -> ant_starts_at(position, board)
  }
}

fn evaporate(board: Board) -> Next(Board) {
  Continue(Board(
    cells: board.cells
    |> map.map_values(fn(_, cell) {
      Cell(..cell, pheromone: cell.pheromone *. config.evaporation_rate)
    }),
  ))
}

fn take_food(position: Position, board: Board) -> Next(Board) {
  let Ok(cell) = map.get(board.cells, position)
  case cell.food < 1 {
    True -> {
      assert True = False
      Continue(board)
    }
    False ->
      Continue(Board(
        cells: board.cells
        |> map.insert(position, Cell(..cell, food: cell.food - 1)),
      ))
  }
}

fn mark_with_pheromone(position: Position, board: Board) -> Next(Board) {
  Continue(Board(cells: case map.get(board.cells, position) {
    Ok(cell) -> {
      let new_cell = Cell(..cell, pheromone: cell.pheromone +. 1.)
      board.cells
      |> map.insert(position, new_cell)
    }
    Error(Nil) -> {
      let new_cell = Cell(..cell.empty, pheromone: 1.)
      board.cells
      |> map.insert(position, new_cell)
    }
  }))
}

fn ant_moved_from_to(old: Position, new: Position, board: Board) -> Next(Board) {
  assert Ok(old_cell) = map.get(board.cells, old)
  let old_cell_2 = Cell(..old_cell, has_ant: False)

  let new_cell_2 = case map.get(board.cells, new) {
    Error(Nil) -> Cell(..cell.empty, has_ant: True)
    Ok(new_cell) -> Cell(..new_cell, has_ant: True)
  }

  Continue(Board(
    cells: board.cells
    |> map.insert(old, old_cell_2)
    |> map.insert(new, new_cell_2),
  ))
}

fn ant_starts_at(position: Position, board: Board) -> Next(Board) {
  let new_cell: Cell = case map.get(board.cells, position) {
    Error(Nil) -> Cell(..cell.empty, has_ant: True)
    Ok(cell) -> Cell(..cell, has_ant: True)
  }

  Continue(Board(
    cells: board.cells
    |> map.insert(position, new_cell),
  ))
}

fn give_cell_info(
  position: Position,
  reply_chan: Sender(Cell),
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
