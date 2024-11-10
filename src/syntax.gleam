import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

import lexer.{type Paren, type Token, Curly, LParen, RParen, Round, Square}

pub type Node(kind) {
  Expr(kind: kind, content: List(Node(kind)))
  Error(kind: ErrorKind, content: Node(kind))
  Item(Item)
}

pub type LispNode =
  Node(LispNodeKind)

pub type SyntaxNode =
  Node(Paren)

pub type LispNodeKind {
  Document
  Call
  Func(name: Option(String))
  Array
  Table
  ArgumentList
}

pub type ErrorKind {
  InvalidArgument
}

pub type Item {
  Num(String)
  Ident(String)
}

pub fn parse_string(str) -> LispNode {
  str |> lexer.lex |> parse
}

pub fn parse(tokens) -> LispNode {
  tokens
  |> parse_syntax(None)
  |> fn(res) { list.map(res.nodes, construct) }
  |> Expr(Document, _)
}

type ParseResult {
  ParseResult(nodes: List(SyntaxNode), remaining_tokens: List(Token))
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
      ParseResult([Expr(paren, inside), ..outside], tokens)
    }

    // terminator
    [other, ..tokens] if Some(other) == terminator -> ParseResult([], tokens)
    [] -> ParseResult([], [])
    _ -> panic
    // TODO: make it error correctly on unmatched parens
  }
}

fn convert_item(item: lexer.Item) -> Node(a) {
  case item {
    lexer.Num(n) -> Item(Num(n))
    lexer.Ident(i) -> Item(Ident(i))
  }
}

fn construct(node: SyntaxNode) -> LispNode {
  case node {
    Expr(Round, [Item(Ident("fn")), ..content]) -> construct_function(content)
    Expr(paren, content) ->
      Expr(paren_to_lisp(paren), list.map(content, construct))
    Item(item) -> Item(item)
    Error(kind, content) -> Error(kind, construct(content))
  }
}

fn paren_to_lisp(paren: Paren) -> LispNodeKind {
  case paren {
    Round -> Call
    Square -> Array
    Curly -> Table
  }
}

fn construct_function(nodes: List(SyntaxNode)) -> LispNode {
  let #(name, nodes) = case nodes {
    [Item(Ident(name)), ..nodes] -> #(Some(name), nodes)
    other -> #(None, other)
  }

  let #(args, nodes) = case nodes {
    [Expr(Square, args), ..nodes] -> #(construct_function_args(args), nodes)
    _ -> #(Expr(ArgumentList, []), nodes)
  }

  Expr(Func(name), [args, ..list.map(nodes, construct)])
}

fn construct_function_args(args: List(SyntaxNode)) -> LispNode {
  Expr(
    ArgumentList,
    list.map(args, fn(arg) {
      case arg {
        Item(Ident(arg)) -> Item(Ident(arg))
        other -> Error(InvalidArgument, construct(other))
      }
    }),
  )
}

pub fn get_node(node: LispNode, selection: List(Int)) -> Option(LispNode) {
  do_get_node(node, list.reverse(selection))
}

fn do_get_node(node: LispNode, selection: List(Int)) -> Option(LispNode) {
  case node, selection {
    _, [] -> Some(node)
    Expr(_, [car, ..]), [0, ..selection] -> do_get_node(car, selection)
    Expr(kind, [_, ..cdr]), [index, ..selection] if index > 0 ->
      do_get_node(Expr(kind, cdr), [index - 1, ..selection])
    _, _ -> None
  }
}

// TODO: clean this up, create a real formatter. Sigh
pub fn to_string(syntax) {
  case syntax {
    Expr(Document, content) -> list_to_string(content, "\n")
    Expr(Array, content) -> "[" <> list_to_string(content, " ") <> "]"
    Expr(ArgumentList, content) -> "[" <> list_to_string(content, " ") <> "]"
    Expr(Table, content) -> "{" <> list_to_string(content, " ") <> "}"
    Expr(Call, content) -> "(" <> list_to_string(content, " ") <> ")"
    Expr(Func(None), content) -> "(fn " <> list_to_string(content, " ") <> ")"
    Expr(Func(Some(name)), content) ->
      "(fn " <> name <> " " <> list_to_string(content, " ") <> ")"
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
  }
}

pub fn list_to_string(syntax, delim) {
  syntax
  |> list.map(to_string)
  |> list.intersperse(delim)
  |> string.concat
}
