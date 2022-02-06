pub type Cell {
  Cell(pheromone: Float, is_home: Bool, food: Int)
}

pub const empty: Cell = Cell(pheromone: 0., is_home: False, food: 0)
