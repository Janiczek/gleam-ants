import gleam/list
import ants/position.{Position}

external fn random_int(n: Int) -> Int = "rand" "uniform"

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
    N  -> 0
    NE -> 1
    E  -> 2
    SE -> 3
    S  -> 4
    SW -> 5
    W  -> 6
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
    _ -> from_int(n - count) // num >= 8
  }
}

fn advance(dir: Direction, amount: Int) -> Direction {
  dir
  |> to_int
  |> fn(n) { n + amount }
  |> from_int
}

fn previous(dir: Direction) -> Direction { advance(dir, -1) }
fn next    (dir: Direction) -> Direction { advance(dir,  1) }
fn opposite(dir: Direction) -> Direction { advance(dir,  4) }

fn delta(for dir: Direction) -> Position {
  case dir {
    N  -> #( 0, 1)
    NE -> #( 1, 1)
    E  -> #( 1, 0)
    SE -> #( 1,-1)
    S  -> #( 0,-1)
    SW -> #(-1,-1)
    W  -> #(-1, 0)
    NW -> #(-1, 1)
  }
}

pub fn visible_directions(for dir: Direction) -> List(Direction) {
  let n = to_int(dir)
  [n-1, n, n+1]
  |> list.map(from_int)
}
