import gleam/bool
import gleam/list
import gleam/option.{type Option, None, Some}

import syntax.{type LispNode, Expr}

type Path =
  List(Int)

pub type Model {
  Model(document: LispNode, selection: Path)
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

fn try_navigation(root: LispNode, path: Path, nav: Navigation) -> Option(Path) {
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
        Some(Expr(_, [_, ..] as nodes)) -> {
          Some([list.length(nodes) - 1, ..parent_path])
        }
        _ -> None
      }
    Last, [] -> None
  }
}

fn get_node_then_path(root: LispNode, path: Path) -> Option(Path) {
  get_node(root, path) |> option.map(fn(_) { path })
}

// Enter the nearest possible enterable node
fn flow_enter(model: Model) -> Option(Path) {
  use path <- option.then(nearest_expression(model.document, model.selection, 0))

  // ergonomic enter
  case get_node(model.document, path) {
    // try jumping to second first, then first
    Some(Expr(_, [_, _, ..])) -> Some(1)
    Some(Expr(_, [_, ..])) -> Some(0)
    _ -> None
  }
  |> option.map(list.prepend(path, _))
}

fn nearest_expression(root: LispNode, path: Path, tries: Int) -> Option(Path) {
  use <- bool.guard(tries >= 3, None)
  let offset = case tries {
    0 -> 0
    1 -> 1
    2 -> -1
    _ -> panic
    // unreachable
  }

  let path = case path {
    [fst, ..rest] -> [fst + offset, ..rest]
    [] -> []
  }

  case get_node(root, path) {
    Some(Expr(..)) -> Some(path)
    _ if path != [] -> nearest_expression(root, path, tries + 1)
    _ -> None
  }
}

fn flow_prev(model: Model) -> Option(Path) {
  try_navigation_list_list(model, generate_sibling_flow(0, 0, 4, True))
}

fn flow_next(model: Model) -> Option(Path) {
  try_navigation_list_list(model, generate_sibling_flow(0, 0, 4, False))
}

// Generate flows to test, i.e.
// [Move(-1)],
// [Leave, Move(-1), Enter, Last],
// [Leave, Move(-1)],
// [Leave, Leave, Move(-1), Enter, Last, Enter, Last],
// [Leave, Leave, Move(-1), Enter, Last],
// [Leave, Leave, Move(-1)],
fn generate_sibling_flow(
  depth,
  depth_right,
  max_depth,
  is_prev,
) -> List(List(Navigation)) {
  use <- bool.guard(depth >= max_depth, [])
  let #(move, reenter) = case is_prev {
    True -> #(Move(-1), [Enter, Last])
    False -> #(Move(1), [Enter])
  }
  let nav =
    list.flatten([
      list.repeat(Leave, depth),
      [move],
      ..list.repeat(reenter, depth_right)
    ])
  let #(depth, depth_right) = case depth_right > 0 {
    True -> #(depth, depth_right - 1)
    False -> #(depth + 1, depth + 1)
  }
  [nav, ..generate_sibling_flow(depth, depth_right, max_depth, is_prev)]
}

fn get_node(node: LispNode, selection: Path) -> Option(LispNode) {
  do_get_node(node, list.reverse(selection))
}

fn do_get_node(node: LispNode, selection: Path) -> Option(LispNode) {
  case node, selection {
    _, [] -> Some(node)
    Expr(_, [car, ..]), [0, ..selection] -> do_get_node(car, selection)
    Expr(kind, [_, ..cdr]), [index, ..selection] if index > 0 ->
      do_get_node(Expr(kind, cdr), [index - 1, ..selection])
    _, _ -> None
  }
}
