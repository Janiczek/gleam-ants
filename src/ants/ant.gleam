import ants/direction.{Direction}
import ants/position.{Position}
import ants/cell.{Cell}
import ants/board
import gleam/float
import gleam/int
import gleam/order
import gleam/string
import gleam/list
import gleam/otp/process.{Sender}
import gleam/option.{None, Option, Some}
import gleam/io
import gleam/otp/actor.{Continue, Next}

pub type Ant {
  Ant(status: AntStatus, direction: Direction, position: Position)
}

pub type AntStatus {
  AntWithFood
  AntWithoutFood
}

pub fn new(direction: Direction, position: Position) -> Ant {
  Ant(status: AntWithoutFood, direction: direction, position: position)
}

pub type Msg {
  Tick
  GiveAnt(to: Sender(Ant))
}

pub fn update(board: Sender(board.Msg), msg: Msg, ant: Ant) -> Next(Ant) {
  case msg {
    Tick -> tick(board, ant)
    GiveAnt(chan) -> give_ant(chan, ant)
  }
}

fn tick(board_msg_chan: Sender(board.Msg), ant: Ant) -> Next(Ant) {
  case ant.status {
    AntWithFood -> behave_with_food(board_msg_chan, ant)
    AntWithoutFood -> behave_without_food(board_msg_chan, ant)
  }
}

fn give_ant(chan: Sender(Ant), ant: Ant) -> Next(Ant) {
  actor.send(chan, ant)
  Continue(ant)
}

fn behave_with_food(board: Sender(board.Msg), ant: Ant) -> Next(Ant) {
  let cell = get_cell(board, ant.position)
  case cell {
    Some(cell.HomeCell) -> drop_food(cell, ant)
    _ -> return_home(board, ant)
  }
}

fn drop_food(cell: Option(Cell), ant: Ant) -> Next(Ant) {
  assert AntWithFood = ant.status
  assert Some(cell.HomeCell) = cell

  Continue(Ant(..ant, status: AntWithoutFood))
}

fn return_home(board: Sender(board.Msg), ant: Ant) -> Next(Ant) {
  let candidates: List(Candidate) =
    direction.visible(for: ant.direction, at: ant.position)
    |> list.map(fn(candidate) {
      let #(direction, position) = candidate
      let cell = get_cell(board, position)
      Candidate(direction, position, cell)
    })

  mark_board_with_pheromone(board, ant.position)

  let next: Option(Candidate) =
    home_candidate(candidates)
    |> option.lazy_or(fn() { best_pheromone(candidates) })
    |> option.lazy_or(fn() { random_candidate(candidates) })

  case next {
    Some(chosen) -> go_to_cell(chosen, ant)
    None -> Continue(turn_opposite(ant))
  }
}

fn behave_without_food(board: Sender(board.Msg), ant: Ant) -> Next(Ant) {
  let cell = get_cell(board, ant.position)
  case cell {
    Some(cell.FoodCell(_)) -> take_food(board, cell, ant)
    _ -> search_for_food(board, ant)
  }
}

fn take_food(
  board: Sender(board.Msg),
  cell: Option(Cell),
  ant: Ant,
) -> Next(Ant) {
  assert AntWithoutFood = ant.status
  assert Some(cell.FoodCell(_)) = cell

  take_food_from_board(board, ant.position)
  let new_ant: Ant = Ant(..ant, status: AntWithFood)
  let new_ant: Ant = turn_opposite(new_ant)
  Continue(new_ant)
}

fn go_to_cell(candidate: Candidate, ant: Ant) -> Next(Ant) {
  // TODO can't go out of bounds
  // TODO can't go where another ant already is
  let new_ant: Ant =
    Ant(..ant, direction: candidate.direction, position: candidate.position)
  Continue(new_ant)
}

fn turn_opposite(ant: Ant) -> Ant {
  Ant(..ant, direction: direction.turn_opposite(ant.direction))
}

type Candidate {
  Candidate(direction: Direction, position: Position, cell: Option(Cell))
}

fn search_for_food(board: Sender(board.Msg), ant: Ant) -> Next(Ant) {
  let candidates: List(Candidate) =
    direction.visible(for: ant.direction, at: ant.position)
    |> list.map(fn(candidate) {
      let #(direction, position) = candidate
      let cell = get_cell(board, position)
      Candidate(direction, position, cell)
    })

  let next: Option(Candidate) =
    best_food(candidates)
    |> option.lazy_or(fn() { best_pheromone(candidates) })
    |> option.lazy_or(fn() { random_candidate(candidates) })

  case next {
    Some(chosen) -> go_to_cell(chosen, ant)
    None -> Continue(turn_opposite(ant))
  }
}

fn home_candidate(candidates: List(Candidate)) -> Option(Candidate) {
  candidates
  |> list.find(fn(candidate: Candidate) {
    case candidate.cell {
      Some(cell.HomeCell) -> True
      _ -> False
    }
  })
  |> option.from_result
}

fn best_food(candidates: List(Candidate)) -> Option(Candidate) {
  candidates
  |> list.filter_map(fn(candidate: Candidate) {
    case candidate.cell {
      Some(cell.FoodCell(food_count)) -> Ok(#(food_count, candidate))
      _ -> Error(Nil)
    }
  })
  |> list.sort(by: fn(a: #(Int, Candidate), b: #(Int, Candidate)) {
    int.compare(b.0, a.0)
  })
  |> list.first
  |> option.from_result
  |> option.map(fn(x: #(Int, Candidate)) { x.1 })
}

fn best_pheromone(candidates: List(Candidate)) -> Option(Candidate) {
  candidates
  |> list.filter_map(fn(candidate: Candidate) {
    case candidate.cell {
      Some(cell.PheromoneCell(pheromone_amount)) ->
        Ok(#(pheromone_amount, candidate))
      _ -> Error(Nil)
    }
  })
  |> list.sort(by: fn(a: #(Float, Candidate), b: #(Float, Candidate)) {
    float.compare(b.0, a.0)
  })
  |> list.first
  |> option.from_result
  |> option.map(fn(x: #(Float, Candidate)) { x.1 })
}

fn random_candidate(candidates: List(Candidate)) -> Option(Candidate) {
  candidates
  |> pick_random
  |> option.from_result
}

fn get_cell(board: Sender(board.Msg), position: Position) -> Option(Cell) {
  actor.call(board, fn(chan) { board.GiveCellInfo(position, chan) }, 100)
}

fn take_food_from_board(board: Sender(board.Msg), position: Position) {
  actor.send(board, board.TakeFood(position))
}

fn mark_board_with_pheromone(board: Sender(board.Msg), position: Position) {
  actor.send(board, board.MarkWithPheromone(position))
}

/// TODO: this would be nice to have in the stdlib
fn list_nth(list list: List(a), nth n: Int) -> Result(a, Nil) {
  list
  |> list.drop(n)
  |> list.first
}

/// TODO: this would be nice to have in the stdlib
fn pick_random(from list: List(a)) -> Result(a, Nil) {
  let n: Int = random_int(list.length(list))
  list_nth(list, n)
}

/// TODO: this would be nice to have in the stdlib
external fn random_int(n: Int) -> Int =
  "rand" "uniform"
