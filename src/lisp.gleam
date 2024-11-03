import gleam/list.{map}
import gleam/option.{type Option, None, Some}
import syntax.{Ident, Parens, Square}

pub type Node {
  Call(List(Node))
  Array(List(Node))
  Func(name: Option(String), alist: List(AListItem), body: List(Node))
  Item(syntax.Item)
}

// arg list
pub type AListItem {
  ALArg(String)
  ALError(syntax.Node)
}

pub fn parse(syntax) {
  case syntax {
    // parse functions
    Parens([
      syntax.Item(Ident("fn")),
      syntax.Item(Ident(name)),
      Square(alist),
      ..body
    ]) -> Func(Some(name), parse_alist(alist), parse_list(body))

    Parens([syntax.Item(Ident("fn")), Square(alist), ..body]) ->
      Func(None, parse_alist(alist), parse_list(body))

    // Correct malformed functions by adding an empty arg list
    Parens([syntax.Item(Ident("fn")), syntax.Item(Ident(name)), ..rest]) ->
      Func(Some(name), [], parse_list(rest))
    Parens([syntax.Item(Ident("fn")), ..rest]) ->
      Func(None, [], parse_list(rest))

    Parens(items) -> Call(parse_list(items))
    Square(items) -> Array(parse_list(items))
    syntax.Item(it) -> Item(it)
  }
}

pub fn parse_alist(syntax) {
  map(syntax, fn(arg) {
    case arg {
      syntax.Item(Ident(name)) -> ALArg(name)
      _ -> ALError(arg)
    }
  })
}

pub fn parse_list(syntax) {
  map(syntax, parse)
}

pub fn unparse(structure) {
  case structure {
    Call(content) -> Parens(unparse_list(content))
    Array(content) -> Square(unparse_list(content))
    Func(name, alist, body) ->
      Parens(
        list.flatten([
          [syntax.Item(Ident("fn"))],
          case name {
            Some(name) -> [syntax.Item(Ident(name))]
            None -> []
          },
          [
            Square(
              map(alist, fn(arg) {
                case arg {
                  ALArg(arg) -> syntax.Item(Ident(arg))
                  ALError(syn) -> syn
                }
              }),
            ),
          ],
          unparse_list(body),
        ]),
      )
    Item(item) -> syntax.Item(item)
  }
}

pub fn unparse_list(structures) {
  map(structures, unparse)
}
