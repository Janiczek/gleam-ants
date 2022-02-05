import ants/config

pub type Position =
  #(Int, Int)

fn plus(a: Position, b: Position) -> Position {
  let #(ax, ay) = a
  let #(bx, by) = b
  #(ax + bx, ay + by)
}

/// Returns the position on the board,
/// placed inside the home area in the middle.
pub fn from_int(n: Int) -> Position {
  from_int_generic(n, config.board_width, config.home_width)
}

fn from_int_generic(n: Int, board_width: Int, home_width: Int) -> Position {
  let home_nw_n: Int = board_width / 2 - home_width / 2
  let home_nw: Position = #(home_nw_n, home_nw_n)
  let dx = n % home_width
  let dy = n / home_width

  plus
  home_nw
  #(dx, dy)
}
