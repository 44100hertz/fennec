import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

import lexer.{type Paren, type Token, Curly, LParen, RParen, Round, Square}

type Path =
  List(Int)

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
  Func(name: Option(String), args: List(Argument))
  Array
  Table
}

pub type Argument {
  Argument(String)
  ArgumentInvalid(content: LispNode)
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
    _ -> #([], nodes)
  }

  Expr(Func(name, args), list.map(nodes, construct))
}

fn construct_function_args(args: List(SyntaxNode)) -> List(Argument) {
  list.map(args, fn(arg) {
    case arg {
      Item(Ident(arg)) -> Argument(arg)
      other -> ArgumentInvalid(construct(other))
    }
  })
}

pub fn get_node(root: Node(a), selection: Path) -> Option(Node(a)) {
  do_get_node(root, list.reverse(selection))
}

fn do_get_node(root: Node(a), selection: Path) -> Option(Node(a)) {
  case root, selection {
    _, [] -> Some(root)
    Expr(_, [car, ..]), [0, ..selection] -> do_get_node(car, selection)
    Expr(kind, [_, ..cdr]), [index, ..selection] if index > 0 ->
      do_get_node(Expr(kind, cdr), [index - 1, ..selection])
    _, _ -> None
  }
}

pub type NodeOperation(a) {
  NodeDelete
  NodeReplace(new: Node(a))
  NodeInsert(new: Node(a))
  NodeAppend(new: Node(a))
}

pub type LispNodeOperation =
  NodeOperation(LispNodeKind)

pub type SyntaxNodeOperation =
  NodeOperation(Paren)

pub fn node_operation(
  operation: NodeOperation(a),
  root: Node(a),
  selection: Path,
) -> Option(Node(a)) {
  do_node_operation(operation, root, list.reverse(selection))
}

fn do_node_operation(
  operation: NodeOperation(a),
  root: Node(a),
  path: Path,
) -> Option(Node(a)) {
  case operation, root, path {
    NodeReplace(new), _, [] -> Some(new)
    NodeDelete(..), _, [] -> None
    NodeDelete, Expr(k, [_, ..cdr]), [0] -> Some(Expr(k, cdr))
    NodeInsert(new), Expr(k, content), [0] -> Some(Expr(k, [new, ..content]))
    NodeAppend(new), Expr(k, [car, ..cdr]), [0] ->
      Some(Expr(k, [car, new, ..cdr]))
    NodeAppend(new), Expr(k, []), [0] -> Some(Expr(k, [new]))
    _, Expr(k, [car, ..cdr]), [0, ..rest] ->
      do_node_operation(operation, car, rest)
      |> option.map(fn(node) { Expr(k, [node, ..cdr]) })
    _, Expr(k, [car, ..cdr]), [n, ..rest] if n > 0 ->
      do_node_operation(operation, Expr(k, cdr), [n - 1, ..rest])
      |> option.map(fn(node) {
        let assert Expr(k, values) = node
        Expr(k, [car, ..values])
      })
    _, _, _ -> None
  }
}

// TODO: clean this up, create a real formatter. Sigh
pub fn to_string(syntax) {
  case syntax {
    Expr(Document, content) -> list_to_string(content, "\n")
    Expr(Array, content) -> "[" <> list_to_string(content, " ") <> "]"
    Expr(Table, content) -> "{" <> list_to_string(content, " ") <> "}"
    Expr(Call, content) -> "(" <> list_to_string(content, " ") <> ")"
    Expr(Func(None, args), content) ->
      ["(fn ", args_to_string(args), " ", list_to_string(content, " "), ")"]
      |> string.concat
    Expr(Func(Some(name), args), content) ->
      [
        "(fn ",
        name,
        " ",
        args_to_string(args),
        " ",
        list_to_string(content, " "),
        ")",
      ]
      |> string.concat
    Item(item) -> item_to_string(item)
    Error(err, node) ->
      "!!ERROR: " <> error_to_string(err) <> " (" <> to_string(node) <> ") !!"
  }
}

pub fn args_to_string(args: List(Argument)) -> String {
  let inner =
    args
    |> list.map(fn(arg) {
      case arg {
        Argument(arg) -> arg
        ArgumentInvalid(content) -> to_string(content)
      }
    })
    |> list.intersperse(" ")
    |> string.concat
  "[ " <> inner <> " ]"
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
