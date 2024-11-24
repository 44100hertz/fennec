import gleam/bool
import gleam/list
import gleam/option.{type Option, None, Some}

import syntax.{type LispNode, Expr, get_node}

pub type Navigation {
  Root
  Leave
  Enter
  FlowEnter
  FlowBottom
  Next
  Prev
  First
  Last
  FlowPrev
  FlowNext
  FlowFirst
  FlowLast
}

type Path =
  List(Int)

pub fn try_navigation(
  root: LispNode,
  path: Path,
  nav: Navigation,
) -> Option(Path) {
  case nav, path {
    Root, _ -> Some([])
    Leave, [_, ..rest] -> Some(rest)
    Leave, [] -> None
    Enter, path -> get_node_then_path(root, [0, ..path])
    FlowEnter, _ ->
      nearest_expression(root, path, 0)
      |> option.map(fn(_) { [0, ..path] })
    // TODO:
    FlowBottom, _ -> None
    Prev, [head, ..path] -> get_node_then_path(root, [head - 1, ..path])
    Prev, [] -> None
    Next, [head, ..path] -> get_node_then_path(root, [head + 1, ..path])
    Next, [] -> None
    FlowNext, _ ->
      try_navigation_list_iter(
        root,
        path,
        SiblingFlowStep(0, 0, list.length(path), False),
        sibling_flow_step,
      )
    FlowPrev, _ ->
      try_navigation_list_iter(
        root,
        path,
        SiblingFlowStep(0, 0, list.length(path), True),
        sibling_flow_step,
      )
    // TODO:
    FlowFirst, _ -> None
    First, [_, ..path] -> get_node_then_path(root, [0, ..path])
    First, [] -> None
    Last, [_, ..parent_path] ->
      case get_node(root, parent_path) {
        Some(Expr(_, [_, ..] as nodes)) -> {
          Some([list.length(nodes) - 1, ..parent_path])
        }
        _ -> None
      }
    Last, [] -> None
    // TODO:
    FlowLast, _ -> None
  }
}

fn try_navigation_list_iter(
  root: LispNode,
  path: Path,
  state: step,
  step_func: fn(step) -> Option(#(List(Navigation), step)),
) -> Option(Path) {
  use #(nav_list, next_step) <- option.then(step_func(state))
  use <- option.lazy_or(try_navigation_list(root, path, nav_list))
  try_navigation_list_iter(root, path, next_step, step_func)
}

fn get_node_then_path(root: LispNode, path: Path) -> Option(Path) {
  get_node(root, path) |> option.map(fn(_) { path })
}

fn try_navigation_list(
  root: LispNode,
  path: Path,
  navs: List(Navigation),
) -> Option(Path) {
  list.fold(navs, Some(path), fn(path, nav) {
    option.then(path, try_navigation(root, _, nav))
  })
}

type SiblingFlowStep {
  SiblingFlowStep(depth: Int, depth_right: Int, max_depth: Int, is_prev: Bool)
}

// Generate flows to test, i.e.
// [Move(-1)],
// [Leave, Move(-1), Enter, Last],
// [Leave, Move(-1)],
// [Leave, Leave, Move(-1), Enter, Last, Enter, Last],
// [Leave, Leave, Move(-1), Enter, Last],
// [Leave, Leave, Move(-1)],
fn sibling_flow_step(step) -> Option(#(List(Navigation), SiblingFlowStep)) {
  let SiblingFlowStep(depth, depth_right, max_depth, is_prev) = step
  use <- bool.guard(depth >= max_depth, None)
  let #(move, reenter) = case is_prev {
    True -> #(Prev, [Enter, Last])
    False -> #(Next, [Enter])
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
  Some(#(nav, SiblingFlowStep(depth, depth_right, max_depth, is_prev)))
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
