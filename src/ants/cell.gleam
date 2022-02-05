pub type Cell {
  Cell(kind: CellKind)
}

pub type CellKind {
  HomeCell
  FoodCell(food_count: Int)
  PheromoneCell(pheromone_amount: Float)
}
