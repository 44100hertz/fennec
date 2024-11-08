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
  Alist
}

pub fn parse(tokens) {
  do_parse(tokens, None).nodes
}

type ParseResult {
  ParseResult(nodes: List(Node), remaining_tokens: List(Token))
}

fn do_parse(tokens: List(Token), terminator: Option(Token)) -> ParseResult {
  case tokens {
    // named function
    [
      LParen(Round),
      lexer.Item(lexer.Ident("fn")),
      lexer.Item(lexer.Ident(name)),
      ..tokens
    ] -> parse_fn(Some(name), tokens, terminator)

    // anonymous function
    [LParen(Round), lexer.Item(lexer.Ident("fn")), ..tokens] ->
      parse_fn(None, tokens, terminator)

    // standard item
    [lexer.Item(item), ..tokens] -> {
      let ParseResult(nodes, tokens) = do_parse(tokens, terminator)
      ParseResult([convert_item(item), ..nodes], tokens)
    }

    // expression
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

    // terminator
    [other, ..tokens] if Some(other) == terminator -> ParseResult([], tokens)
    [] -> ParseResult([], [])
    _ -> panic
    // TODO: make it error correctly on unmatched parens
    // TODO: parse function argument list into "alist"
  }
}

fn parse_fn(
  name: Option(String),
  tokens: List(Token),
  terminator: Option(Token),
) -> ParseResult {
  let ParseResult(alist, tokens) = case tokens {
    // Found argument list...Good!
    [LParen(Square), ..tokens] -> do_parse(tokens, Some(RParen(Square)))
    // Guess we'll make one...
    _ -> ParseResult([], tokens)
  }
  let alist = Expr([Item(Alist), ..alist])
  // parse function body
  let ParseResult(inside, tokens) = do_parse(tokens, Some(RParen(Round)))
  let ParseResult(outside, tokens) = do_parse(tokens, terminator)
  let expr = case name {
    Some(name) -> Expr([Item(Ident("fn")), Item(Ident(name)), alist, ..inside])
    None -> Expr([Item(Ident("fn")), alist, ..inside])
  }
  ParseResult([expr, ..outside], tokens)
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
