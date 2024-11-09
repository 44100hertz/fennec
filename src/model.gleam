import syntax

pub type Model {
  Model(selection: List(Int), parse_tree: syntax.Node)
}

pub type Msg {
  SelectPath(List(Int))
  Leave
  Nop
}

pub fn init(_flags) {
  let code = "(fn print_square [x] (print (* x x)) (print_square 100)"
  Model([], code |> syntax.parse_string)
}

pub fn update(model: Model, msg: Msg) {
  case msg {
    SelectPath(selection) -> Model(..model, selection:)
    Leave ->
      Model(
        ..model,
        selection: case model.selection {
          [_, ..rest] -> rest
          [] -> []
        },
      )
    Nop -> model
  }
}
