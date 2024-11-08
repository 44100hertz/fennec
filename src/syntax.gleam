import gleam/list.{intersperse, map}
import gleam/option.{type Option, None, Some}
import gleam/string

import lexer.{type Token, Curly, LParen, RParen, Round, Square}

pub type Node {
  Expr(content: List(Node))
  Item(Item)
}

pub type Item {
  Num(String)
  Ident(String)
  Array
  Table
}

pub fn parse(tokens) {
  do_parse(tokens, None).nodes
}

type ParseResult {
  ParseResult(nodes: List(Node), remaining_tokens: List(Token))
}

fn do_parse(tokens: List(Token), terminator: Option(Token)) -> ParseResult {
  case tokens {
    [lexer.Item(item), ..tokens] -> {
      let ParseResult(nodes, tokens) = do_parse(tokens, terminator)
      ParseResult([convert_item(item), ..nodes], tokens)
    }
    [LParen(paren), ..tokens] -> {
      let ParseResult(inside, tokens) = do_parse(tokens, Some(RParen(paren)))
      let ParseResult(outside, tokens) = do_parse(tokens, terminator)
      let expr = case paren {
        Round -> Expr(inside)
        Square -> Expr([Item(Array), ..inside])
        Curly -> Expr([Item(Table), ..inside])
      }
      ParseResult([expr, ..outside], tokens)
    }
    [other, ..tokens] if Some(other) == terminator -> ParseResult([], tokens)
    [] -> ParseResult([], [])
    _ -> panic
    // TODO: make it error correctly on unmatched parens
    // TODO: parse function argument list into "alist"
  }
}

pub fn convert_item(item: lexer.Item) -> Node {
  case item {
    lexer.Num(n) -> Item(Num(n))
    lexer.Ident(i) -> Item(Ident(i))
  }
}

pub fn to_string(syntax) {
  case syntax {
    Expr([Item(Array), ..content]) -> "[" <> list_to_string(content) <> "]"
    Expr([Item(Table), ..content]) -> "{" <> list_to_string(content) <> "}"
    Expr(content) -> "(" <> list_to_string(content) <> ")"
    Item(item) -> item_to_string(item)
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
