import ants/direction.{Direction}
import ants/position.{Position}
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
}

pub fn update(msg: Msg, ant: Ant) -> Next(Ant) {
  case msg {
    Tick -> tick(ant)
  }
}

fn tick(ant: Ant) -> Next(Ant) {
  io.debug(ant)
  case ant.status {
    AntWithFood -> behave_with_food(ant)
    AntWithoutFood -> behave_without_food(ant)
  }
}

fn behave_with_food(ant: Ant) -> Next(Ant) {
  todo("behave with food")
  Continue(ant)
}

fn behave_without_food(ant: Ant) -> Next(Ant) {
  todo("behave without food")
  Continue(ant)
}
