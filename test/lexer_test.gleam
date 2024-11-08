import gleeunit/should
import lexer.{Ident, Item, LParen, Num, RParen, Round, Square}

pub fn lexer_test() {
  "(xavier123 some-thing 1 [2. .3] 4.0)"
  |> lexer.lex
  |> should.equal([
    LParen(Round),
    Item(Ident("xavier123")),
    Item(Ident("some-thing")),
    Item(Num("1")),
    LParen(Square),
    Item(Num("2.")),
    Item(Num(".3")),
    RParen(Square),
    Item(Num("4.0")),
    RParen(Round),
  ])
}

pub fn dense_lexer_test() {
  "w(x[y]z)"
  |> lexer.lex
  |> should.equal([
    Item(Ident("w")),
    LParen(Round),
    Item(Ident("x")),
    LParen(Square),
    Item(Ident("y")),
    RParen(Square),
    Item(Ident("z")),
    RParen(Round),
  ])
}
