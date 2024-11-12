import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{type Option, None, Some}
import navigation.{type Navigation}
import operations.{type Operation} as op

import syntax.{type LispNode, type LispNodeOperation}

type Path =
  List(Int)

pub type Model {
  Model(
    document: LispNode,
    selection: Path,
    registers: Dict(String, LispNode),
    keybinds: Dict(String, Operation),
    saved_selection: Path,
  )
}

pub type Msg {
  Alternatives(List(Msg))
  Multi(List(Msg))
  SelectPath(Path)
  Copy(register: String)
  SavePath
  LoadPath
  Delete
  Replace(register: String)
  Insert(register: String)
  Append(register: String)
  Root
  Navigation(Navigation)
  FlowEnter
  FlowNext
  FlowPrev
  Nop
}

pub fn init(_flags) {
  let code = "(fn print_square [x] (print (* x x) (- x)) (print_square 100)"
  Model(
    document: code |> syntax.parse_string,
    selection: [],
    registers: dict.new(),
    saved_selection: [],
    keybinds: dict.from_list([
      #("^", op.Root),
      #("0", op.First),
      #("$", op.Last),
      #("j", op.FlowEnter),
      #("k", op.Leave),
      #("h", op.FlowPrev),
      #("l", op.FlowNext),
      #("y", op.Copy),
      #("i", op.Insert),
      #("a", op.Append),
      #("x", op.Delete),
      #("r", op.Raise),
      #("u", op.Unwrap),
      #("d", op.Duplicate),
      #("s", op.Split),
      #("(", op.JoinLeft),
      #(")", op.JoinRight),
      #("%", op.Convolute),
      #("[", op.SlurpLeft),
      #("]", op.SlurpRight),
      #("{", op.BarfLeft),
      #("}", op.BarfRight),
      #("ArrowLeft", op.DragPrev),
      #("ArrowRight", op.DragNext),
    ]),
  )
}

pub fn update(model: Model, msg: Msg) -> Model {
  try_update(model, msg) |> option.unwrap(model)
}

pub fn try_update(model: Model, msg: Msg) -> Option(Model) {
  case msg {
    Alternatives(messages) ->
      list.fold(messages, None, fn(res, op) {
        res |> option.lazy_or(fn() { try_update(model, op) })
      })
    Multi(messages) ->
      list.fold(messages, Some(model), fn(res, op) {
        res |> option.then(try_update(_, op))
      })
    Root -> Some(Model(..model, selection: []))
    SelectPath(selection) ->
      syntax.get_node(model.document, selection)
      |> option.then(fn(_) { Some(Model(..model, selection:)) })
    Navigation(nav) ->
      wrap_nav(model, fn(root, path) {
        navigation.try_navigation(root, path, nav)
      })
    SavePath -> Some(Model(..model, saved_selection: model.selection))
    LoadPath ->
      Some(
        Model(
          ..model,
          selection: model.saved_selection,
          saved_selection: model.selection,
        ),
      )
    Copy(register) ->
      syntax.get_node(model.document, model.selection)
      |> option.map(fn(node) {
        Model(..model, registers: dict.insert(model.registers, register, node))
      })
    Insert(register) -> wrap_register_op(model, register, syntax.NodeInsert(_))
    Append(register) -> wrap_register_op(model, register, syntax.NodeAppend(_))
    // TODO: fix delete path
    Delete -> wrap_op(model, syntax.NodeDelete)
    Replace(register) ->
      dict.get(model.registers, register)
      |> option.from_result
      |> option.then(fn(node) { wrap_op(model, syntax.NodeReplace(node)) })
    FlowEnter -> wrap_nav(model, navigation.flow_enter)
    FlowPrev -> wrap_nav(model, navigation.flow_prev)
    FlowNext -> wrap_nav(model, navigation.flow_next)
    Nop -> Some(model)
  }
}

fn wrap_nav(
  model: Model,
  nav: fn(LispNode, Path) -> Option(Path),
) -> Option(Model) {
  nav(model.document, model.selection)
  |> option.map(fn(selection) { Model(..model, selection:) })
}

fn wrap_register_op(
  model: Model,
  register: String,
  operation: fn(LispNode) -> LispNodeOperation,
) {
  dict.get(model.registers, register)
  |> option.from_result
  |> option.then(fn(node) { wrap_op(model, operation(node)) })
}

fn wrap_op(model: Model, operation: LispNodeOperation) -> Option(Model) {
  syntax.node_operation(operation, model.document, model.selection)
  |> option.map(fn(document) { Model(..model, document:) })
}
