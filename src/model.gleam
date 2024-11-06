import lisp
import syntax.{Ident, Item, Num, Parens, Round, Square}

pub type Model {
  Model(select_path: List(Int), parse_tree: lisp.Node)
}

pub type Msg {
  SelectPath(List(Int))
}

pub fn init(_flags) {
  let syntax_tree =
    Parens(Round, [
      Item(Ident("fn")),
      Parens(Square, [Item(Ident("a"))]),
      Parens(Round, [
        syntax.Item(Ident("*")),
        syntax.Item(Num("8.0")),
        syntax.Item(Ident("a")),
      ]),
    ])

  let parse_tree = lisp.parse(syntax_tree)
  Model([], parse_tree)
}

pub fn update(model: Model, msg: Msg) {
  case msg {
    SelectPath(select_path) -> Model(..model, select_path:)
  }
}
