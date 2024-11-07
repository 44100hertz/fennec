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
  do_parse(tokens, EOF).0
}

pub fn do_parse(tokens: List(Token), terminator: Token) -> #(List(Node), List(Token)) {
  case tokens {
    [TItem(item), ..tokens] -> {
      let #(nodes, tokens) = do_parse(tokens, terminator)
      #([Item(item), ..nodes], tokens)
    }
    [LParen(paren), ..tokens] -> {
      let #(inside, tokens) = do_parse(tokens, RParen(paren))
      let #(outside, tokens) = do_parse(tokens, terminator)
      #([Parens(paren, inside), ..outside], tokens)
    }
    [other, ..tokens] if other == terminator -> #([], tokens)
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
