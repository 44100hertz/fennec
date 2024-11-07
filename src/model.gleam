import lisp
import syntax

pub type Model {
  Model(select_path: List(Int), parse_tree: lisp.Node)
}

pub type Msg {
  SelectPath(List(Int))
}

pub fn init(_flags) {
  let parse_tree =
    "(fn [x] (* 8 x))" |> syntax.lex |> syntax.parse |> lisp.parse_root
  Model([], parse_tree)
}

pub fn update(model: Model, msg: Msg) {
  case msg {
    SelectPath(select_path) -> Model(..model, select_path:)
  }
}
