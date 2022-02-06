import ants/direction.{Direction}
import ants/position.{Position}
import ants/cell.{Cell}
import ants/board
import gleam/pair
import gleam/float
import gleam/bool
import gleam/int
import gleam/order
import gleam/map.{Map}
import gleam/string
import gleam/list
import gleam/otp/process.{Sender}
import gleam/option
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
  case cell.is_home {
    True -> drop_food(cell, ant)
    False -> return_home(board, ant)
  }
}

fn drop_food(cell: Cell, ant: Ant) -> Next(Ant) {
  assert AntWithFood = ant.status
  assert True = cell.is_home

  io.println("dropped food at home")

  Continue(Ant(..ant, status: AntWithoutFood))
}

fn behave_without_food(board: Sender(board.Msg), ant: Ant) -> Next(Ant) {
  let cell = get_cell(board, ant.position)
  case cell.food >= 1 {
    True -> take_food(board, cell, ant)
    False -> search_for_food(board, ant)
  }
}

fn take_food(board: Sender(board.Msg), cell: Cell, ant: Ant) -> Next(Ant) {
  assert AntWithoutFood = ant.status
  assert True = cell.food >= 1

  io.println(string.concat(["took food from ", position.to_string(ant.position)]))

  take_food_from_board(board, ant.position)
  let new_ant: Ant =
    Ant(..ant, status: AntWithFood)
    |> turn_opposite
  Continue(new_ant)
}

fn run_action(
  board: Sender(board.Msg),
  candidate: Candidate,
  ant: Ant,
) -> Next(Ant) {
  case candidate.cell.has_ant {
    True -> Continue(ant)
    False -> {
      let new_dir = apply_action(ant.direction, candidate.action)
      case candidate.action {
        MoveForward -> {
          let new_pos = direction.step(ant.position, new_dir)
          mark_board_with_pheromone(board, ant.position)
          notify_board_of_move(board, from: ant.position, to: new_pos)
          Continue(Ant(..ant, position: new_pos))
        }
        TurnClockwise -> Continue(Ant(..ant, direction: new_dir))
        TurnCounterclockwise -> Continue(Ant(..ant, direction: new_dir))
      }
    }
  }
}

fn turn_opposite(ant: Ant) -> Ant {
  Ant(..ant, direction: direction.turn_opposite(ant.direction))
}

type CandidateAction {
  MoveForward
  TurnClockwise
  TurnCounterclockwise
}

type Candidate {
  Candidate(action: CandidateAction, cell: Cell)
}

fn return_home(board: Sender(board.Msg), ant: Ant) -> Next(Ant) {
  case find_candidates(board, ant) {
    [] -> Continue(ant)
    candidates -> {
      let ranks_pheromone =
        rank(candidates, fn(candidate: Candidate) { candidate.cell.pheromone })
      let ranks_home =
        rank(
          candidates,
          fn(candidate: Candidate) {
            case candidate.cell.is_home {
              True -> 1.
              False -> 0.
            }
          },
        )
      let ranks = combine_ranks(ranks_pheromone, ranks_home)
      case pick_random_wheel(ranks) {
        Ok(chosen) -> run_action(board, chosen, ant)
        Error(Nil) -> Continue(ant)
      }
    }
  }
}

fn search_for_food(board: Sender(board.Msg), ant: Ant) -> Next(Ant) {
  let pos_ahead = direction.step(ant.position, ant.direction)
  let cell_ahead = get_cell(board, pos_ahead)
  case cell_ahead.food > 0 && bool.negate(cell_ahead.has_ant) {
    True -> run_action(board, Candidate(MoveForward, cell_ahead), ant)
    False ->
      case find_candidates(board, ant) {
        [] -> Continue(turn_opposite(ant))
        candidates -> {
          let ranks_pheromone =
            rank(
              candidates,
              fn(candidate: Candidate) { candidate.cell.pheromone },
            )
          let ranks_food =
            rank(
              candidates,
              fn(candidate: Candidate) { int.to_float(candidate.cell.food) },
            )
          let ranks = combine_ranks(ranks_pheromone, ranks_food)
          case pick_random_wheel(ranks) {
            Ok(chosen) -> run_action(board, chosen, ant)
            Error(Nil) -> Continue(turn_opposite(ant))
          }
        }
      }
  }
}

fn find_candidates(board: Sender(board.Msg), ant: Ant) {
  [MoveForward, TurnClockwise, TurnCounterclockwise]
  |> list.filter_map(fn(action) {
    let dir_after_action = apply_action(ant.direction, action)
    let pos_in_front = direction.step(ant.position, dir_after_action)
    let cell = get_cell(board, pos_in_front)
    case cell.has_ant {
      True -> Error(Nil)
      False -> Ok(Candidate(action, cell))
    }
  })
}

fn apply_action(dir: Direction, action: CandidateAction) -> Direction {
  case action {
    MoveForward -> dir
    TurnClockwise -> direction.turn_clockwise(dir)
    TurnCounterclockwise -> direction.turn_counterclockwise(dir)
  }
}

fn get_cell(board: Sender(board.Msg), position: Position) -> Cell {
  actor.call(board, fn(chan) { board.GiveCellInfo(position, chan) }, 100)
}

fn take_food_from_board(board: Sender(board.Msg), position: Position) {
  actor.send(board, board.TakeFood(position))
}

fn mark_board_with_pheromone(board: Sender(board.Msg), position: Position) {
  actor.send(board, board.MarkWithPheromone(position))
}

fn notify_board_of_move(
  board: Sender(board.Msg),
  from old: Position,
  to new: Position,
) {
  actor.send(board, board.AntMovedFromTo(old, new))
}

/// TODO: maybe a bit situational but still general purpose
fn rank(list: List(a), by key: fn(a) -> Float) -> Map(a, Int) {
  // TODO is this the correct way round? Are we then applying it the correct
  // way round in the roulette wheel?
  let sorted = list.sort(list, fn(a, b) { float.compare(key(a), key(b)) })
  let range = list.range(1, list.length(list) + 1)
  list.zip(sorted, range)
  |> map.from_list
}

fn combine_ranks(ranks1: Map(a, Int), ranks2: Map(a, Int)) -> List(#(a, Int)) {
  ranks1
  |> map.to_list
  |> list.map(fn(i1) {
    let #(item1, rank1) = i1
    case map.get(ranks2, item1) {
      Ok(rank2) -> #(item1, rank1 + rank2)
      Error(Nil) -> i1
    }
  })
}

/// TODO: maybe a bit situational but maybe good for a PRNG lib
fn pick_random_wheel(from list: List(#(a, Int))) -> Result(a, Nil) {
  let total: Int =
    list
    |> list.map(pair.second)
    |> list.fold(0, fn(a, b) { a + b })
  let rand: Int = random_int(total)
  pick_random_wheel_help(0, rand, list)
}

fn pick_random_wheel_help(
  sum: Int,
  rand: Int,
  items: List(#(a, Int)),
) -> Result(a, Nil) {
  case items {
    [] -> Error(Nil)
    [x] -> Ok(x.0)
    [x, ..xs] -> {
      let new_sum = sum + x.1
      case rand < new_sum {
        True -> Ok(x.0)
        False -> pick_random_wheel_help(new_sum, rand, xs)
      }
    }
  }
}

/// TODO: this would be nice to have in the stdlib
external fn random_int(n: Int) -> Int =
  "rand" "uniform"
