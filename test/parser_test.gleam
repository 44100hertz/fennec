import gleam/option.{None, Some}
import gleeunit/should
import lexer
import syntax.{
  Argument, ArgumentInvalid, Call, Document, Expr, Func, Ident, Item, Num,
}

pub fn expression_test() {
  "(* x 4) (* (+ x 2) 4)"
  |> lexer.lex
  |> syntax.parse
  |> should.equal(
    Expr(Document, [
      Expr(Call(Item(Ident("*"))), [Item(Ident("x")), Item(Num("4"))]),
      Expr(Call(Item(Ident("*"))), [
        Expr(Call(Item(Ident("+"))), [Item(Ident("x")), Item(Num("2"))]),
        Item(Num("4")),
      ]),
    ]),
  )
}

pub fn function_test() {
  "(fn [x] (* x x))"
  |> lexer.lex
  |> syntax.parse
  |> should.equal(
    Expr(Document, [
      Expr(Func(None, [Argument("x")]), [
        Expr(Call(Item(Ident("*"))), [Item(Ident("x")), Item(Ident("x"))]),
      ]),
    ]),
  )

  "(fn square [x] (* x x))"
  |> lexer.lex
  |> syntax.parse
  |> should.equal(
    Expr(Document, [
      Expr(Func(Some("square"), [Argument("x")]), [
        Expr(Call(Item(Ident("*"))), [Item(Ident("x")), Item(Ident("x"))]),
      ]),
    ]),
  )
}

pub fn bad_function_test() {
  "(fn 1)"
  |> lexer.lex
  |> syntax.parse
  |> should.equal(
    Expr(Document, [
      Expr(Func(None, []), [
        // inject an argument list if none exists
        Item(Num("1")),
      ]),
    ]),
  )

  "(fn [1])"
  |> lexer.lex
  |> syntax.parse
  |> should.equal(
    Expr(Document, [Expr(Func(None, [ArgumentInvalid(Item(Num("1")))]), [])]),
  )
}
