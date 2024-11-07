import gleam/list.{intersperse, map}
import gleam/option.{type Option, None, Some}
import gleam/regex
import gleam/result
import gleam/string

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
  Node(body: NodeBody, position: Position)
}

pub type NodeBody {
  Parens(paren: Paren, content: List(Node))
  Item(Item)
}

pub type Position {
  Position(row: Int, col: Int)
}

pub type TokenBody {
  LParen(Paren)
  RParen(Paren)
  TItem(Item)
}

pub type Token {
  Token(body: TokenBody, position: Position)
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
  |> do_lex(str, Position(1, 1))
}

fn do_lex(
  patterns: List(#(regex.Regex, fn(String) -> TokenBody)),
  str: String,
  pos: Position,
) -> List(Token) {
  list.find_map(patterns, fn(token_def) {
    let #(pattern, tokfn) = token_def
    case regex.scan(pattern, str) {
      [] -> Error(Nil)
      [regex.Match(_, [Some(tok)])] ->
        Ok([Token(body: tokfn(tok), position: pos)])
      [regex.Match(content, [Some(tok), Some(rest)])] -> {
        Ok([
          Token(body: tokfn(tok), position: pos),
          ..do_lex(patterns, rest, update_pos(pos, content))
        ])
      }
      _ -> panic
    }
  })
  |> result.unwrap([])
}

fn update_pos(pos: Position, content: String) -> Position {
  list.fold(string.to_graphemes(content), pos, fn(pos, char) {
    case char {
      "\n" -> Position(pos.row + 1, 1)
      "\r" -> pos
      _ -> Position(pos.row, pos.col + 1)
    }
  })
}

pub fn parse(tokens) {
  do_parse(tokens, None).nodes
}

type ParseResult {
  ParseResult(nodes: List(Node), remaining_tokens: List(Token))
}

fn do_parse(tokens: List(Token), terminator: Option(TokenBody)) -> ParseResult {
  case tokens {
    [Token(TItem(item), pos), ..tokens] -> {
      let ParseResult(nodes, tokens) = do_parse(tokens, terminator)
      ParseResult([Node(Item(item), pos), ..nodes], tokens)
    }
    [Token(LParen(paren), pos), ..tokens] -> {
      let ParseResult(inside, tokens) = do_parse(tokens, Some(RParen(paren)))
      let ParseResult(outside, tokens) = do_parse(tokens, terminator)
      ParseResult([Node(Parens(paren, inside), pos), ..outside], tokens)
    }
    [Token(other, _), ..tokens] if Some(other) == terminator ->
      ParseResult([], tokens)
    [] -> ParseResult([], [])
    _ -> panic
    // TODO: make it error correctly on unmatched parens
  }
}

pub fn to_string(node) {
  let Node(body, _) = node
  case body {
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
