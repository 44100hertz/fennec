import gleam/list.{intersperse, map}
import gleam/option.{type Option, None, Some}
import gleam/string

import lexer.{type Token, Curly, LParen, RParen, Round, Square}

pub type Node {
  Expr(content: List(Node))
  Error(error_kind: ErrorKind, content: Node)
  Item(Item)
}

pub type ErrorKind {
  InvalidArgument
}

pub type Item {
  Num(String)
  Ident(String)
  Document
  Array
  Table
  ArgumentList
}

pub fn parse(tokens) {
  tokens
  |> parse_syntax(None)
  |> fn(res) { construct(Expr([Item(Document), ..res.nodes])) }
}

type ParseResult {
  ParseResult(nodes: List(Node), remaining_tokens: List(Token))
}

fn parse_syntax(tokens: List(Token), terminator: Option(Token)) -> ParseResult {
  case tokens {
    // standard item
    [lexer.Item(item), ..tokens] -> {
      let ParseResult(nodes, tokens) = parse_syntax(tokens, terminator)
      ParseResult([convert_item(item), ..nodes], tokens)
    }

    // expression
    [LParen(paren), ..tokens] -> {
      let ParseResult(inside, tokens) =
        parse_syntax(tokens, Some(RParen(paren)))
      let ParseResult(outside, tokens) = parse_syntax(tokens, terminator)
      let expr = case paren {
        Round -> Expr(inside)
        Square -> Expr([Item(Array), ..inside])
        Curly -> Expr([Item(Table), ..inside])
      }
      ParseResult([expr, ..outside], tokens)
    }

    // terminator
    [other, ..tokens] if Some(other) == terminator -> ParseResult([], tokens)
    [] -> ParseResult([], [])
    _ -> panic
    // TODO: make it error correctly on unmatched parens
  }
}

pub fn convert_item(item: lexer.Item) -> Node {
  case item {
    lexer.Num(n) -> Item(Num(n))
    lexer.Ident(i) -> Item(Ident(i))
  }
}

pub fn construct(node: Node) -> Node {
  case node {
    Expr([Item(Ident("fn")), ..content]) -> construct_function(content)
    Expr(content) -> Expr(map(content, construct))
    Item(item) -> Item(item)
    Error(..) -> node
  }
}

pub fn construct_function(nodes: List(Node)) -> Node {
  let #(name, nodes) = case nodes {
    [Item(Ident(_)) as name, ..nodes] -> #(Some(name), nodes)
    other -> #(None, other)
  }

  let #(args, nodes) = case nodes {
    [Expr([Item(Array), ..args]), ..nodes] -> #(
      Some(construct_function_args(args)),
      nodes,
    )
    _ -> #(None, nodes)
  }

  Expr(
    list.flatten([
      [Item(Ident("fn"))],
      // if name, [name], else []
      name |> option.then(fn(x) { Some([x]) }) |> option.unwrap([]),
      // if invalid args, create an empty argument list instead
      [args |> option.unwrap(Expr([Item(ArgumentList)]))],
      map(nodes, construct),
    ]),
  )
}

pub fn construct_function_args(args: List(Node)) -> Node {
  Expr([
    Item(ArgumentList),
    ..list.map(args, fn(arg) {
      case arg {
        Item(Ident(_)) as arg -> arg
        other -> Error(InvalidArgument, other)
      }
    })
  ])
}

pub fn to_string(syntax) {
  case syntax {
    Expr([Item(Array), ..content]) -> "[" <> list_to_string(content) <> "]"
    Expr([Item(Table), ..content]) -> "{" <> list_to_string(content) <> "}"
    Expr(content) -> "(" <> list_to_string(content) <> ")"
    Item(item) -> item_to_string(item)
    Error(err, node) ->
      "!!ERROR: " <> error_to_string(err) <> " (" <> to_string(node) <> ") !!"
  }
}

pub fn error_to_string(error: ErrorKind) -> String {
  case error {
    InvalidArgument -> "Invalid Argument"
  }
}

pub fn item_to_string(item) {
  case item {
    Num(n) -> n
    Ident(i) -> i
    _ -> panic
  }
}

pub fn list_to_string(syntax) {
  syntax
  |> map(to_string)
  |> intersperse(" ")
  |> string.concat
}
