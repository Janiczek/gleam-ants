import ants/direction.{Direction}
import ants/position.{Position}
import gleam/dynamic
import gleam/otp/actor.{Next}

pub type Ant {
  Ant(
    status: AntStatus,
    direction: Direction,
    position: Position
  )
}

pub type AntStatus {
  AntWithFood
  AntWithoutFood
}

pub fn new(direction: Direction, position: Position) -> Ant {
  Ant(
    status: AntWithoutFood,
    direction: direction,
    position: position
  )
}

pub type Msg {
  Tick
}

pub fn update(msg: Msg, ant: Ant) -> Next(Ant) {
  case msg {
    Tick -> todo
  }
}

fn behave(ant: Ant) -> Ant {
  case ant.status {
    AntWithFood    -> behave_with_food(ant)
    AntWithoutFood -> behave_without_food(ant)
  }
}

fn behave_with_food(ant: Ant) -> Ant {
  // TODO do something
  ant
}

fn behave_without_food(ant: Ant) -> Ant {
  // TODO do something
  ant
}
