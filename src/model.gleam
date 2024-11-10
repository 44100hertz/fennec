import gleam/bool
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result

import syntax.{type Node, Expr, Ident, Item}

type Path =
  List(Int)

pub type Model {
  Model(document: List(syntax.Node), selection: Path)
}

pub type Msg {
  SelectPath(Path)
  Root
  Navigation(List(Navigation))
  FlowEnter
  FlowNext
  FlowPrev
  Nop
}

pub type Navigation {
  Leave
  Enter
  Move(offset: Int)
  Jump(index: Int)
  Last
}

pub fn init(_flags) {
  let code = "(fn print_square [x] (print (* x x) (- x)) (print_square 100)"
  Model(code |> syntax.parse_string, [])
}

pub fn update(model: Model, msg: Msg) {
  case msg {
    Root -> Model(..model, selection: [])
    SelectPath(selection) -> Model(..model, selection:)
    Navigation(navs) -> wrap_nav(model, try_navigation_list(_, navs))
    FlowEnter -> wrap_nav(model, flow_enter)
    FlowPrev -> wrap_nav(model, flow_prev)
    FlowNext -> wrap_nav(model, flow_next)
    Nop -> model
  }
}

fn wrap_nav(model: Model, nav: fn(Model) -> Option(Path)) -> Model {
  nav(model)
  |> option.map(fn(selection) { Model(..model, selection:) })
  |> option.unwrap(model)
}

fn try_navigation_list(model: Model, navs: List(Navigation)) -> Option(Path) {
  list.fold(navs, Some(model.selection), fn(path, nav) {
    option.then(path, try_navigation(model.document, _, nav))
  })
}

fn try_navigation_list_list(
  model: Model,
  navs_list: List(List(Navigation)),
) -> Option(Path) {
  list.fold(navs_list, None, fn(path, nav_list) {
    option.lazy_or(path, fn() { try_navigation_list(model, nav_list) })
  })
}

fn try_navigation(root: List(Node), path: Path, nav: Navigation) -> Option(Path) {
  case nav, path {
    Leave, [_, ..rest] -> Some(rest)
    Leave, [] -> None
    Enter, path -> get_node_then_path(root, [0, ..path])
    Move(offset), [head, ..path] ->
      get_node_then_path(root, [head + offset, ..path])
    Move(..), [] -> None
    Jump(index), [_, ..path] -> get_node_then_path(root, [index, ..path])
    Jump(..), [] -> None
    Last, [_, ..parent_path] ->
      case get_node(root, parent_path) {
        Some(Expr([_, ..] as nodes)) -> {
          Some([list.length(nodes) - 1, ..parent_path])
        }
        _ -> None
      }
    Last, [] -> None
  }
}

fn get_node_then_path(root: List(Node), path: Path) -> Option(Path) {
  get_node(root, path) |> option.map(fn(_) { path })
}

// Enter the nearest possible enterable node
fn flow_enter(model: Model) -> Option(Path) {
  use path <- option.then(nearest_expression(model.document, model.selection, 0))

  // ergonomic enter
  case get_node(model.document, path) {
    // always jump to function body
    Some(Expr([Item(Ident("fn")), Item(Ident(..))])) -> Some(4)
    Some(Expr([Item(Ident("fn")), ..])) -> Some(3)
    // try jumping to second first, then first
    Some(Expr([_one, _two, ..])) -> Some(1)
    Some(Expr([_one, ..])) -> Some(0)
    _ -> None
  }
  |> option.map(list.prepend(path, _))
}

fn nearest_expression(root: List(Node), path: Path, tries: Int) -> Option(Path) {
  use <- bool.guard(tries >= 3, None)
  let offset = case tries {
    0 -> 0
    1 -> 1
    2 -> -1
    _ -> panic
    // unreachable
  }
  use path <- option.then(case path {
    [fst, ..rest] -> Some([fst + offset, ..rest])
    [] -> None
  })

  case get_node(root, path) {
    Some(Expr(..)) -> Some(path)
    _ -> nearest_expression(root, path, tries + 1)
  }
}

fn flow_prev(model: Model) -> Option(Path) {
  try_navigation_list_list(model, [
    [Move(-1)],
    [Leave, Move(-1), Enter, Last],
    [Leave, Move(-1)],
  ])
}

fn flow_next(model: Model) -> Option(Path) {
  try_navigation_list_list(model, [
    [Move(1)],
    [Leave, Move(1), Enter],
    [Leave, Move(1)],
  ])
}

fn get_node(node: List(syntax.Node), selection: Path) -> Option(syntax.Node) {
  do_get_node(Expr(node), list.reverse(selection))
}

fn do_get_node(node: syntax.Node, selection: Path) -> Option(syntax.Node) {
  case node, selection {
    _, [] -> Some(node)
    Expr([car, ..]), [0, ..selection] -> do_get_node(car, selection)
    Expr([_, ..cdr]), [index, ..selection] if index > 0 ->
      do_get_node(Expr(cdr), [index - 1, ..selection])
    _, _ -> None
  }
}
