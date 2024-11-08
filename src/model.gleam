import syntax.{Expr, Ident, Item, Num}

pub type Model {
  Model(select_path: List(Int), parse_tree: syntax.Node)
}

pub type Msg {
  SelectPath(List(Int))
}

pub fn init(_flags) {
  let syntax_tree =
    Expr([
      Item(Ident("fn")),
      Expr([Item(syntax.Array), Item(Ident("a"))]),
      Expr([
        Item(syntax.Array),
        Item(Ident("*")),
        Item(Num("8.0")),
        Item(Ident("a")),
      ]),
    ])

  Model([], syntax_tree)
}

pub fn update(model: Model, msg: Msg) {
  case msg {
    SelectPath(select_path) -> Model(..model, select_path:)
  }
}
