pub type Cell {
  Cell(pheromone: Float, is_home: Bool, food: Int, has_ant: Bool)
}

pub const empty: Cell = Cell(
  pheromone: 0.,
  is_home: False,
  food: 0,
  has_ant: False,
)
