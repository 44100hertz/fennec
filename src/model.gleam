import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}

import syntax

pub type Model {
  Model(document: List(syntax.Node), selection: List(Int))
}

pub type Msg {
  SelectPath(List(Int))
  Leave
  Enter
  Nop
}

pub fn init(_flags) {
  let code = "(fn print_square [x] (print (* x x)) (print_square 100)"
  Model(code |> syntax.parse_string, [])
}

pub fn update(model: Model, msg: Msg) {
  case msg {
    SelectPath(selection) -> Model(..model, selection:)
    Leave ->
      Model(
        ..model,
        selection: case model.selection {
          [_, ..rest] -> rest
          [] -> []
        },
      )
    Enter -> enter(model)
    Nop -> model
  }
}

fn enter(model: Model) {
  let selection = [0, ..model.selection]
  case get_node(model.document, selection) {
    Some(..) -> Model(..model, selection:)
    None -> model
  }
}

fn get_node(
  node: List(syntax.Node),
  selection: List(Int),
) -> Option(syntax.Node) {
  do_get_node(syntax.Expr(node), list.reverse(selection))
}

fn do_get_node(node: syntax.Node, selection: List(Int)) -> Option(syntax.Node) {
  case node, selection {
    _, [] -> Some(node)
    syntax.Expr([car, ..]), [0, ..selection] -> do_get_node(car, selection)
    syntax.Expr([_, ..cdr]), [idx, ..selection] ->
      do_get_node(syntax.Expr(cdr), [idx - 1, ..selection])
    _, _ -> None
  }
}
