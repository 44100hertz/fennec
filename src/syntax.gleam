import gleam/float
import gleam/list.{intersperse, map}
import gleam/string

pub type Item {
  Num(Float)
  Ident(String)
}

pub type Node {
  Parens(List(Node))
  Square(List(Node))
  Item(Item)
}

pub fn to_string(syntax) {
  case syntax {
    Parens(content) -> "(" <> list_to_string(content) <> ")"
    Square(content) -> "[" <> list_to_string(content) <> "]"
    Item(item) -> item_to_string(item)
  }
}

pub fn item_to_string(item) {
  case item {
    Num(n) -> float.to_string(n)
    Ident(i) -> i
  }
}

pub fn list_to_string(syntax) {
  syntax
  |> map(to_string)
  |> intersperse(" ")
  |> string.concat
}
