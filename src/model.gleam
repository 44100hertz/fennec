import gleam/option.{type Option}
import navigation.{type Navigation}

import syntax.{type LispNode}

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

pub fn init(_flags) {
  let code = "(fn print_square [x] (print (* x x) (- x)) (print_square 100)"
  Model(code |> syntax.parse_string, [])
}

pub fn update(model: Model, msg: Msg) {
  case msg {
    Root -> Model(..model, selection: [])
    SelectPath(selection) -> Model(..model, selection:)
    Navigation(navs) ->
      wrap_nav(model, fn(root, path) {
        navigation.try_navigation_list(root, path, navs)
      })
    FlowEnter -> wrap_nav(model, navigation.flow_enter)
    FlowPrev -> wrap_nav(model, navigation.flow_prev)
    FlowNext -> wrap_nav(model, navigation.flow_next)
    Nop -> model
  }
}

fn wrap_nav(model: Model, nav: fn(LispNode, Path) -> Option(Path)) -> Model {
  nav(model.document, model.selection)
  |> option.map(fn(selection) { Model(..model, selection:) })
  |> option.unwrap(model)
}
