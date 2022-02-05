import ants/config
import gleam/list
import gleam/string
import gleam/int

pub type Position =
  #(Int, Int)

pub fn add(a: Position, b: Position) -> Position {
  let #(ax, ay) = a
  let #(bx, by) = b
  #(ax + bx, ay + by)
}

/// Returns the position on the board,
/// placed inside the home area in the middle.
pub fn from_int(n: Int) -> Position {
  let home_nw = get_home_nw()
  let dx = n % config.home_width
  let dy = n / config.home_width

  add(home_nw, #(dx, dy))
}

fn get_home_nw() -> Position {
  let home_nw_n: Int = config.board_width / 2 - config.home_width / 2
  #(home_nw_n, home_nw_n)
}

pub fn home_positions() -> List(Position) {
  let #(home_nw_x, _) = get_home_nw()
  let range = list.range(home_nw_x, home_nw_x + config.home_width)
  cartesian_product(range, range)
}

pub fn all_positions() -> List(Position) {
  let range = list.range(0, config.board_width)
  cartesian_product(range, range)
}

pub fn to_string(position: Position) -> String {
  let #(x, y) = position
  string.concat(["(", int.to_string(x), ",", int.to_string(y), ")"])
}

/// TODO: this would be nice to have in the stdlib
fn cartesian_product(xs: List(a), ys: List(b)) -> List(#(a, b)) {
  list.flat_map(xs, fn(x) { list.map(ys, fn(y) { #(x, y) }) })
}
