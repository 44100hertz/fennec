import lisp
import lustre
import render
import syntax.{Ident, Item, Num, Parens, Square}

pub fn main() {
  let syntax_tree =
    Parens([
      Item(Ident("fn")),
      Square([Item(Ident("a"))]),
      Parens([
        syntax.Item(Ident("*")),
        syntax.Item(Num(4.0)),
        syntax.Item(Ident("a")),
      ]),
    ])

  let parse_tree = lisp.parse(syntax_tree)
  let app = lustre.element(render.render(parse_tree))
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}
