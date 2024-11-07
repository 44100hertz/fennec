import gleam/list.{intersperse, map}
import gleam/option.{type Option, None, Some}
import gleam/regex
import gleam/result
import gleam/string

pub type Item {
  Num(String)
  Ident(String)
}

pub type Paren {
  Round
  Square
  Curly
}

pub type Node {
  Parens(paren: Paren, content: List(Node))
  Item(Item)
}

pub type Token {
  LParen(Paren)
  RParen(Paren)
  TItem(Item)
}

pub fn lex(str) {
  [
    #("\\(", fn(_str) { LParen(Round) }),
    #("\\)", fn(_str) { RParen(Round) }),
    #("\\[", fn(_str) { LParen(Square) }),
    #("\\]", fn(_str) { RParen(Square) }),
    #("\\d+[.]?\\d*", fn(str) { TItem(Num(str)) }),
    #("\\d*[.]?\\d+", fn(str) { TItem(Num(str)) }),
    #("\\D\\S*", fn(str) { TItem(Ident(str)) }),
  ]
  |> map(fn(pair) {
    let assert Ok(re) = regex.from_string("^\\s*(" <> pair.0 <> ")\\s*(.*)$")
    #(re, pair.1)
  })
  |> do_lex(str)
}

fn do_lex(patterns: List(#(regex.Regex, fn(String) -> Token)), str) {
  list.find_map(patterns, fn(token) {
    let #(pattern, tokfn) = token
    case regex.scan(pattern, str) {
      [] -> Error(Nil)
      [regex.Match(_, [Some(tok)])] -> Ok([tokfn(tok)])
      [regex.Match(_, [Some(tok), Some(rest)])] ->
        Ok([tokfn(tok), ..do_lex(patterns, rest)])
      _ -> panic
    }
  })
  |> result.unwrap([])
}

pub fn parse(tokens) {
  do_parse(tokens, None).nodes
}

type ParseResult {
  ParseResult(nodes: List(Node), remaining_tokens: List(Token))
}

fn do_parse(tokens: List(Token), terminator: Option(Token)) -> ParseResult {
  case tokens {
    [TItem(item), ..tokens] -> {
      let ParseResult(nodes, tokens) = do_parse(tokens, terminator)
      ParseResult([Item(item), ..nodes], tokens)
    }
    [LParen(paren), ..tokens] -> {
      let ParseResult(inside, tokens) = do_parse(tokens, Some(RParen(paren)))
      let ParseResult(outside, tokens) = do_parse(tokens, terminator)
      ParseResult([Parens(paren, inside), ..outside], tokens)
    }
    [other, ..tokens] if Some(other) == terminator -> ParseResult([], tokens)
    [] -> ParseResult([], [])
    _ -> panic
    // TODO: make it error correctly on unmatched parens
  }
}

pub fn to_string(syntax) {
  case syntax {
    Parens(Round, content) -> "(" <> list_to_string(content) <> ")"
    Parens(Square, content) -> "[" <> list_to_string(content) <> "]"
    Parens(Curly, content) -> "{" <> list_to_string(content) <> "}"
    Item(item) -> item_to_string(item)
  }
}

pub fn item_to_string(item) {
  case item {
    Num(n) -> n
    Ident(i) -> i
  }
}

pub fn list_to_string(syntax) {
  syntax
  |> map(to_string)
  |> intersperse(" ")
  |> string.concat
}
