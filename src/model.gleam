import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
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

pub type Msg {
  NodeClicked(path: Path)
  KeyDown(name: String)
  KeyUp(name: String)
}

pub fn key_to_modifier(key) -> Option(Modifier) {
  case key {
    "Alt" -> Some(Alt)
    "Shift" -> Some(Shift)
    "Control" -> Some(Control)
    _ -> None
  }
}

pub fn operation_to_effect(operation: Operation) {
  case operation {
    op.Root -> Root
    op.Enter -> Navigation(navigation.Enter)
    op.FlowEnter -> FlowEnter
    // TODO: 
    op.FlowBottom -> Nop
    op.Leave -> Navigation(navigation.Leave)
    op.Next -> Navigation(navigation.Move(1))
    op.Prev -> Navigation(navigation.Move(-1))
    op.FlowNext -> FlowNext
    op.FlowPrev -> FlowPrev
    op.First -> Navigation(navigation.Jump(0))
    op.Last -> Navigation(navigation.Last)
    // TODO:
    op.FlowFirst -> Nop
    op.FlowLast -> Nop

    op.Copy -> Copy("1")
    op.Insert -> Insert("1")
    op.InsertInto ->
      Alternatives([
        InsertInto("1"),
        Multi([Navigation(navigation.Jump(0)), Insert("1")]),
      ])
    op.Append -> Multi([Append("1"), Navigation(navigation.Move(1))])
    op.AppendInto ->
      Alternatives([
        Multi([
          Alternatives([Navigation(navigation.Enter), Nop]),
          Navigation(navigation.Last),
          Append("1"),
          Navigation(navigation.Move(1)),
        ]),
        // It's empty!
        InsertInto("1"),
      ])
    op.Delete -> Multi([Delete, Navigation(navigation.TruncatePath)])
    op.Raise -> Multi([Copy("0"), Navigation(navigation.Leave), Replace("0")])
    // TODO: 
    op.Unwrap -> Nop
    op.Duplicate -> Multi([Copy("0"), Insert("0")])
    // TODO: 
    op.Split -> Nop
    op.JoinLeft -> Nop
    op.JoinRight -> Nop
    op.Convolute -> Nop
    op.SlurpLeft ->
      Multi([
        Navigation(navigation.LeaveIfItem),
        Navigation(navigation.Move(-1)),
        Copy("0"),
        Delete,
        InsertInto("0"),
        Navigation(navigation.Leave),
      ])
    op.SlurpRight ->
      Multi([
        Navigation(navigation.LeaveIfItem),
        Navigation(navigation.Move(1)),
        Copy("0"),
        Delete,
        Navigation(navigation.Move(-1)),
        Alternatives([
          Multi([
            Navigation(navigation.Enter),
            Navigation(navigation.Last),
            Append("0"),
          ]),
          InsertInto("0"),
        ]),
        Navigation(navigation.Leave),
      ])
    op.BarfLeft ->
      Multi([
        Navigation(navigation.EnterIfExpr),
        Navigation(navigation.Jump(0)),
        Copy("0"),
        Delete,
        Navigation(navigation.Leave),
        Insert("0"),
        Navigation(navigation.Move(1)),
      ])
    op.BarfRight ->
      Multi([
        Navigation(navigation.EnterIfExpr),
        Navigation(navigation.Last),
        Copy("0"),
        Delete,
        Navigation(navigation.Leave),
        Append("0"),
      ])
    op.DragPrev -> Multi([Copy("0"), Delete, FlowPrev, Insert("0")])
    op.DragNext ->
      Alternatives([
        Multi([Copy("0"), Delete, FlowNext, Insert("0")]),
        Multi([Copy("0"), Delete, Append("0"), Navigation(navigation.Move(1))]),
      ])
  }
}

pub type Effect {
  Alternatives(List(Effect))
  Multi(List(Effect))
  Copy(register: String)
  Delete
  Replace(register: String)
  Insert(register: String)
  InsertInto(register: String)
  Append(register: String)
  Root
  Navigation(Navigation)
  FlowEnter
  FlowNext
  FlowPrev
  Nop
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
      #(shift("I"), op.InsertInto),
      #(key("a"), op.Append),
      #(shift("A"), op.AppendInto),
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
  case msg {
    KeyDown(key) ->
      case key_to_modifier(key) {
        Some(mod) -> Model(..model, modifiers: set.insert(model.modifiers, mod))
        None -> {
          let shift = set.contains(model.modifiers, Shift)
          let control = set.contains(model.modifiers, Control)
          let alt = set.contains(model.modifiers, Alt)

          dict.get(model.keybinds, KeyMatch(key, shift, control, alt))
          |> result.lazy_or(fn() {
            dict.get(model.keybinds, KeyMatchAnyCase(key, control, alt))
          })
          |> option.from_result
          |> option.then(fn(op) { try_update(model, operation_to_effect(op)) })
          |> option.unwrap(model)
        }
      }
    KeyUp(key) ->
      case key_to_modifier(key) {
        Some(mod) -> Model(..model, modifiers: set.delete(model.modifiers, mod))
        None -> model
      }
    NodeClicked(selection) -> Model(..model, selection:)
  }
}

pub fn try_update(model: Model, msg: Effect) -> Option(Model) {
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
    InsertInto(register) ->
      wrap_register_op(
        Model(..model, selection: [0, ..model.selection]),
        register,
        syntax.NodeInsert(_),
      )
    Append(register) -> wrap_register_op(model, register, syntax.NodeAppend(_))
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
