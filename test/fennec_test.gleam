import gleeunit
import gleeunit/should
import syntax.{Curly, LParen, Node, RParen, Round, Square}

pub fn main() {
  gleeunit.main()
}

// gleeunit test functions end in `_test`
pub fn lexer_test() {
  "(xavier123 some-thing 1 [2. .3] 4.0)"
  |> syntax.lex
  |> fn(tok) { tok.body }
  |> should.equal([
    LParen(Round),
    TItem(Ident("xavier123")),
    TItem(Ident("some-thing")),
    TItem(Num("1")),
    LParen(Square),
    TItem(Num("2.")),
    TItem(Num(".3")),
    RParen(Square),
    TItem(Num("4.0")),
    RParen(Round),
  ])
}

pub fn parser_test() {
  "(* x 4) (* x 4)"
  |> syntax.lex
  |> syntax.parse
  |> fn(node) { node.body }
  |> should.equal([
    Parens(Round, [Item(Ident("*")), Item(Ident("x")), Item(Num("4"))]),
    Parens(Round, [Item(Ident("*")), Item(Ident("x")), Item(Num("4"))]),
  ])
}
