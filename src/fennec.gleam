import lustre
import model.{init, update}
import view

pub fn main() {
  let app = lustre.simple(init, update, view.render)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}
