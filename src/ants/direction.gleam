import gleam/list
import ants/position.{Position}

pub type Direction {
  N
  NE
  E
  SE
  S
  SW
  W
  NW
}

pub const count = 8

pub fn random() -> Direction {
  random_int(count)
  |> from_int
}

fn to_int(for dir: Direction) -> Int {
  case dir {
    N -> 0
    NE -> 1
    E -> 2
    SE -> 3
    S -> 4
    SW -> 5
    W -> 6
    NW -> 7
  }
}

fn from_int(for n: Int) -> Direction {
  case n {
    0 -> N
    1 -> NE
    2 -> E
    3 -> SE
    4 -> S
    5 -> SW
    6 -> W
    7 -> NW
    _ if n < 0 -> from_int(n + count)
    _ -> from_int(n - count)
  }
  // num >= 8
}

fn turn(dir: Direction, amount: Int) -> Direction {
  dir
  |> to_int
  |> fn(n) { n + amount }
  |> from_int
}

pub fn turn_opposite(dir: Direction) -> Direction {
  turn(dir, 4)
}

fn delta(for dir: Direction) -> Position {
  case dir {
    N -> #(0, -1)
    NE -> #(1, -1)
    E -> #(1, 0)
    SE -> #(1, 1)
    S -> #(0, 1)
    SW -> #(-1, 1)
    W -> #(-1, 0)
    NW -> #(-1, -1)
  }
}

pub fn visible(
  for dir: Direction,
  at pos: Position,
) -> List(#(Direction, Position)) {
  let n = to_int(dir)
  [n, n - 1, n + 1]
  |> list.map(from_int)
  |> list.map(fn(new_dir) {
    let new_pos = position.bounded_add(pos, delta(new_dir))
    #(new_dir, new_pos)
  })
}

/// TODO: this would be nice to have in the stdlib
external fn random_int(n: Int) -> Int =
  "rand" "uniform"
