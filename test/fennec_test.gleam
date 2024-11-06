import gleeunit
import gleeunit/should
import syntax

pub fn main() {
  gleeunit.main()
}

// gleeunit test functions end in `_test`
pub fn lexer_test() {
  "(xavier123 some-thing 1 2. .3 4.0)"
  |> syntax.lex
  |> should.equal([
    syntax.LParen(syntax.Round),
    syntax.TItem(syntax.Ident("xavier123")),
    syntax.TItem(syntax.Ident("some-thing")),
    syntax.TItem(syntax.Num("1")),
    syntax.TItem(syntax.Num("2.")),
    syntax.TItem(syntax.Num(".3")),
    syntax.TItem(syntax.Num("4.0")),
    syntax.RParen(syntax.Round),
    syntax.EOF
  ])
}

pub fn parser_test() {
  "(* x 4) (* x 4)"
  |> syntax.lex
  |> syntax.parse
  |> should.equal([
    syntax.Parens(syntax.Round, [
      syntax.Item(syntax.Ident("*")),
      syntax.Item(syntax.Ident("x")),
      syntax.Item(syntax.Num("4")),
    ]),
    syntax.Parens(syntax.Round, [
      syntax.Item(syntax.Ident("*")),
      syntax.Item(syntax.Ident("x")),
      syntax.Item(syntax.Num("4")),
    ])
  ])
}
