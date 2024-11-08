import gleam/list.{map}
import gleam/option.{Some}
import gleam/regex

pub type Token {
  LParen(Paren)
  RParen(Paren)
  Item(Item)
}

pub type Item {
  Num(String)
  Ident(String)
}

pub type Paren {
  Round
  Square
  Curly
}

pub fn lex(str) {
  [
    #("\\(", fn(_str) { LParen(Round) }),
    #("\\)", fn(_str) { RParen(Round) }),
    #("\\[", fn(_str) { LParen(Square) }),
    #("\\]", fn(_str) { RParen(Square) }),
    #("\\d+[.]?\\d*", fn(str) { Item(Num(str)) }),
    #("\\d*[.]?\\d+", fn(str) { Item(Num(str)) }),
    #("\\D[^()\\[\\]{} \\t\\r\\n]*", fn(str) { Item(Ident(str)) }),
  ]
  |> map(fn(pair) {
    let assert Ok(re) = regex.from_string("^\\s*(" <> pair.0 <> ")\\s*(.*)$")
    #(re, pair.1)
  })
  |> do_lex(str)
}

fn do_lex(patterns: List(#(regex.Regex, fn(String) -> Token)), str) {
  let assert Ok(match) =
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
  match
}
