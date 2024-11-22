import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/set.{type Set}
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
    keybinds: Dict(KeyMatch, Operation),
    modifiers: Set(Modifier),
  )
}

pub type KeyMatch {
  KeyMatch(key: String, shift: Bool, control: Bool, alt: Bool)
  KeyMatchAnyCase(key: String, control: Bool, alt: Bool)
}

fn key(key) {
  KeyMatchAnyCase(key, False, False)
}

fn shift(key) {
  KeyMatch(key, True, False, False)
}

fn ctrl(key) {
  KeyMatch(key, False, True, False)
}

fn alt(key) {
  KeyMatch(key, False, False, True)
}

pub type Modifier {
  Shift
  Control
  Alt
}

pub type Msg {
  SetModifier(Modifier, Bool)
  Alternatives(List(Msg))
  Multi(List(Msg))
  SelectPath(Path)
  Copy(register: String)
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
    keybinds: dict.from_list([
      #(key("^"), op.Root),
      #(key("0"), op.First),
      #(key("$"), op.Last),
      #(key("j"), op.FlowEnter),
      #(key("k"), op.Leave),
      #(key("h"), op.FlowPrev),
      #(key("ArrowLeft"), op.FlowPrev),
      #(key("l"), op.FlowNext),
      #(key("ArrowRight"), op.FlowNext),
      #(key("H"), op.DragPrev),
      #(shift("ArrowLeft"), op.DragPrev),
      #(key("L"), op.DragNext),
      #(shift("ArrowRight"), op.DragNext),
      #(key("y"), op.Copy),
      #(key("i"), op.Insert),
      #(key("a"), op.Append),
      #(key("x"), op.Delete),
      #(key("r"), op.Raise),
      #(key("u"), op.Unwrap),
      #(key("d"), op.Duplicate),
      #(key("s"), op.Split),
      #(key("("), op.JoinLeft),
      #(key(")"), op.JoinRight),
      #(key("%"), op.Convolute),
      #(key("["), op.SlurpLeft),
      #(key("]"), op.SlurpRight),
      #(key("{"), op.BarfLeft),
      #(key("}"), op.BarfRight),
    ]),
    modifiers: set.new(),
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
    SetModifier(mod, True) ->
      Some(Model(..model, modifiers: set.insert(model.modifiers, mod)))
    SetModifier(mod, False) ->
      Some(Model(..model, modifiers: set.delete(model.modifiers, mod)))
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
