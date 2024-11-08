import gleeunit
import gleeunit/should
import lexer
import syntax

pub fn main() {
  gleeunit.main()
}

// gleeunit test functions end in `_test`
pub fn lexer_test() {
  "(xavier123 some-thing 1 [2. .3] 4.0)"
  |> lexer.lex
  |> should.equal([
    lexer.LParen(lexer.Round),
    lexer.Item(lexer.Ident("xavier123")),
    lexer.Item(lexer.Ident("some-thing")),
    lexer.Item(lexer.Num("1")),
    lexer.LParen(lexer.Square),
    lexer.Item(lexer.Num("2.")),
    lexer.Item(lexer.Num(".3")),
    lexer.RParen(lexer.Square),
    lexer.Item(lexer.Num("4.0")),
    lexer.RParen(lexer.Round),
  ])
}

pub fn parser_test() {
  "(* x 4) (* x 4)"
  |> lexer.lex
  |> syntax.parse
  |> should.equal([
    syntax.Expr([
      syntax.Item(syntax.Ident("*")),
      syntax.Item(syntax.Ident("x")),
      syntax.Item(syntax.Num("4")),
    ]),
    syntax.Expr([
      syntax.Item(syntax.Ident("*")),
      syntax.Item(syntax.Ident("x")),
      syntax.Item(syntax.Num("4")),
    ]),
  ])
}
