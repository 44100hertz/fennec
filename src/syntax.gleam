import gleam/list.{intersperse, map}
import gleam/option.{Some}
import gleam/regex
import gleam/result
import gleam/string

pub type Item {
  Num(String)
  Ident(String)
}

pub type Node {
  Parens(List(Node))
  Square(List(Node))
  Item(Item)
}

pub type Token {
  White(newline: Bool)
  LParen
  RParen
  LSquare
  RSquare
  TIdent(String)
  TNum(String)
}

pub fn lex(str) {
  [
    #("\\s+", fn(str) { White(newline: string.contains(str, "\n")) }),
    #("\\(", fn(_str) { LParen }),
    #("\\)", fn(_str) { RParen }),
    #("\\[", fn(_str) { LSquare }),
    #("\\]", fn(_str) { RSquare }),
    #("\\D\\S+", fn(str) { TIdent(str) }),
    #("\\d*.?\\d", fn(str) { TNum(str) }),
  ]
  |> map(fn(pair) {
    let assert Ok(re) = regex.from_string("^(" <> pair.0 <> ")(.*)$")
    #(re, pair.1)
  })
  |> do_lex(str)
}

pub fn do_lex(patterns: List(#(regex.Regex, fn(String) -> Token)), str) {
  list.find_map(patterns, fn(token) {
    case regex.scan(token.0, str) {
      [] -> Error(Nil)
      [regex.Match(_, [Some(tok)])] -> Ok([token.1(tok)])
      [regex.Match(_, [Some(tok), Some(rest)])] ->
        Ok([token.1(tok), ..do_lex(patterns, rest)])
      _ -> panic
    }
  })
  |> result.unwrap([])
}

pub fn to_string(syntax) {
  case syntax {
    Parens(content) -> "(" <> list_to_string(content) <> ")"
    Square(content) -> "[" <> list_to_string(content) <> "]"
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
