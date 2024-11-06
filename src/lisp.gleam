import gleam/list.{map}
import gleam/option.{type Option, None, Some}
import syntax.{Curly, Ident, Parens, Round, Square}

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
    Parens(
      Round,
      [
        syntax.Item(Ident("fn")),
        syntax.Item(Ident(name)),
        Parens(Square, alist),
        ..body
      ],
    ) -> Func(Some(name), parse_alist(alist), parse_list(body))

    Parens(Round, [syntax.Item(Ident("fn")), Parens(Square, alist), ..body]) ->
      Func(None, parse_alist(alist), parse_list(body))

    // Correct malformed functions by adding an empty arg list
    Parens(Round, [syntax.Item(Ident("fn")), syntax.Item(Ident(name)), ..rest]) ->
      Func(Some(name), [], parse_list(rest))
    Parens(Round, [syntax.Item(Ident("fn")), ..rest]) ->
      Func(None, [], parse_list(rest))

    Parens(Round, items) -> Call(parse_list(items))
    Parens(Square, items) -> Array(parse_list(items))
    Parens(Curly, items) -> todo
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
    Call(content) -> Parens(Round, unparse_list(content))
    Array(content) -> Parens(Square, unparse_list(content))
    Func(name, alist, body) ->
      Parens(
        Round,
        list.flatten([
          [syntax.Item(Ident("fn"))],
          case name {
            Some(name) -> [syntax.Item(Ident(name))]
            None -> []
          },
          [
            Parens(
              Square,
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
