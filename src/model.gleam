import syntax

pub type Model {
  Model(select_path: List(Int), parse_tree: syntax.Node)
}

pub type Msg {
  SelectPath(List(Int))
}

pub fn init(_flags) {
  let code = "(fn print_square [x] (print (* x x)) (print_square 100)"
  Model([], code |> syntax.parse_string)
}

pub fn update(model: Model, msg: Msg) {
  case msg {
    SelectPath(select_path) -> Model(..model, select_path:)
  }
}
