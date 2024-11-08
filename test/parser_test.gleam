import gleeunit/should
import lexer
import syntax.{Expr, Ident, Item, Num}

pub fn expression_test() {
  "(* x 4) (* (+ x 2) 4)"
  |> lexer.lex
  |> syntax.parse
  |> should.equal([
    Expr([Item(Ident("*")), Item(Ident("x")), Item(Num("4"))]),
    Expr([
      Item(Ident("*")),
      Expr([Item(Ident("+")), Item(Ident("x")), Item(Num("2"))]),
      Item(Num("4")),
    ]),
  ])
}

pub fn function_test() {
  "(fn [x] (* x x))"
  |> lexer.lex
  |> syntax.parse
  |> should.equal([
    Expr([
      Item(Ident("fn")),
      Expr([Item(syntax.Alist), Item(Ident("x"))]),
      Expr([Item(Ident("*")), Item(Ident("x")), Item(Ident("x"))]),
    ]),
  ])

  "(fn square [x] (* x x))"
  |> lexer.lex
  |> syntax.parse
  |> should.equal([
    Expr([
      Item(Ident("fn")),
      Item(Ident("square")),
      Expr([Item(syntax.Alist), Item(Ident("x"))]),
      Expr([Item(Ident("*")), Item(Ident("x")), Item(Ident("x"))]),
    ]),
  ])
}
