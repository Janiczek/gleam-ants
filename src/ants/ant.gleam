import ants/direction.{Direction}
import ants/position.{Position}
import ants/cell.{Cell, FoodCell}
import ants/board
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
    AntWithFood -> behave_with_food(ant)
    AntWithoutFood -> behave_without_food(board_msg_chan, ant)
  }
}

fn give_ant(chan: Sender(Ant), ant: Ant) -> Next(Ant) {
  actor.send(chan, ant)
  Continue(ant)
}

fn behave_with_food(ant: Ant) -> Next(Ant) {
  todo("behave with food")
}

fn behave_without_food(board: Sender(board.Msg), ant: Ant) -> Next(Ant) {
  let cell = get_cell(board, ant.position)
  case cell {
    Some(FoodCell(_)) -> take_food(board, ant)
    _ -> search_for_food(board, ant)
  }
}

fn take_food(board: Sender(board.Msg), ant: Ant) -> Next(Ant) {
  io.println("TODO take food")
  Continue(ant)
}

fn go_to_cell(candidate: Candidate, ant: Ant) -> Next(Ant) {
  let new_ant: Ant =
    Ant(..ant, direction: candidate.direction, position: candidate.position)
  Continue(new_ant)
}

fn turn_opposite(ant: Ant) -> Next(Ant) {
  let new_ant: Ant =
    Ant(..ant, direction: direction.turn_opposite(ant.direction))
  Continue(new_ant)
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
    None -> turn_opposite(ant)
  }
}

fn best_food(candidates: List(Candidate)) -> Option(Candidate) {
  candidates
  |> list.filter_map(fn(candidate: Candidate) {
    case candidate.cell {
      Some(FoodCell(food_count)) -> Ok(#(food_count, candidate))
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
  io.println("TODO best pheromone")
  None
}

fn random_candidate(candidates: List(Candidate)) -> Option(Candidate) {
  candidates
  |> pick_random
  |> option.from_result
}

fn get_cell(board: Sender(board.Msg), position: Position) -> Option(Cell) {
  actor.call(board, fn(chan) { board.GiveCellInfo(position, chan) }, 50)
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
