import gleeunit
import gleeunit/should
import syntax

pub fn main() {
  gleeunit.main()
}

// gleeunit test functions end in `_test`
pub fn lexer_test() {
  "(x 1 2)"
  |> syntax.lex
  |> should.equal([
    syntax.LParen(syntax.Round),
    syntax.TIdent("x"),
    syntax.TNum("1"),
    syntax.TNum("2"),
    syntax.RParen(syntax.Round),
  ])
}
