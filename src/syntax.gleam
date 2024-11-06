import gleam/list.{intersperse, map}
import gleam/option.{Some}
import gleam/regex
import gleam/result
import gleam/string
import gleam/io

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
  EOF
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
    let #(pat, tokfn) = token
    case regex.scan(token.0, str) {
      [] -> Error(Nil)
      [regex.Match(_, [Some(tok)])] -> Ok([tokfn(tok), EOF])
      [regex.Match(_, [Some(tok), Some(rest)])] ->
        Ok([tokfn(tok), ..do_lex(patterns, rest)])
      _ -> panic
    }
  })
  |> result.unwrap([])
}

pub fn parse(tokens) {
  do_parse(EOF, tokens).0
}

pub fn do_parse(terminator: Token, tokens: List(Token)) -> #(List(Node), List(Token)) {
  io.debug(terminator)
  io.debug(tokens)
  case tokens {
    [TItem(it), ..rest] -> {
      let #(result, rest) = do_parse(terminator, rest)
      #([Item(it), ..result], rest)
    }
    [LParen(paren), ..rest] -> {
      let #(lresult, lrest) = do_parse(RParen(paren), rest)
      let #(rresult, rrest) = do_parse(terminator, lrest)
      #([Parens(paren, lresult), ..rresult], rrest)
    }
    [other, ..rest] if other == terminator -> #([], rest)
    [] -> #([], [])
    _ -> panic // TODO: make it error correctly on unmatched parens
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
