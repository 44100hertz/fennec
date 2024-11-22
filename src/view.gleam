import gleam/dict
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/set

import lustre/attribute
import lustre/element
import lustre/element/html
import lustre/event

import model.{type Model, type Modifier, Navigation, SelectPath}
import navigation as nav
import operations.{type Operation} as op
import syntax.{
  type Argument, type LispNode, Argument, ArgumentInvalid, Array, Call, Document,
  Expr, Func, Item, Table,
}

pub fn key_to_modifier(key) -> Option(Modifier) {
  case key {
    "Alt" -> Some(model.Alt)
    "Shift" -> Some(model.Shift)
    "Control" -> Some(model.Control)
    _ -> None
  }
}

pub fn operation_to_effect(operation: Operation) {
  case operation {
    op.Root -> model.Root
    op.Enter -> Navigation(nav.Enter)
    op.FlowEnter -> model.FlowEnter
    // TODO: 
    op.FlowBottom -> model.Nop
    op.Leave -> Navigation(nav.Leave)
    op.Next -> Navigation(nav.Move(1))
    op.Prev -> Navigation(nav.Move(-1))
    op.FlowNext -> model.FlowNext
    op.FlowPrev -> model.FlowPrev
    op.First -> Navigation(nav.Jump(0))
    op.Last -> Navigation(nav.Last)
    // TODO:
    op.FlowFirst -> model.Nop
    op.FlowLast -> model.Nop

    op.Copy -> model.Copy("1")
    op.Insert -> model.Insert("1")
    op.InsertInto ->
      model.Alternatives([
        model.InsertInto("1"),
        model.Multi([Navigation(nav.Jump(0)), model.Insert("1")]),
      ])
    op.Append -> model.Multi([model.Append("1"), Navigation(nav.Move(1))])
    op.AppendInto ->
      model.Alternatives([
        model.Multi([
          model.Alternatives([Navigation(nav.Enter), model.Nop]),
          Navigation(nav.Last),
          model.Append("1"),
          Navigation(nav.Move(1)),
        ]),
        // It's empty!
        model.InsertInto("1"),
      ])
    op.Delete -> model.Multi([model.Delete, Navigation(nav.TruncatePath)])
    op.Raise ->
      model.Multi([model.Copy("0"), Navigation(nav.Leave), model.Replace("0")])
    // TODO: 
    op.Unwrap -> model.Nop
    op.Duplicate -> model.Multi([model.Copy("0"), model.Insert("0")])
    // TODO: 
    op.Split -> model.Nop
    op.JoinLeft -> model.Nop
    op.JoinRight -> model.Nop
    op.Convolute -> model.Nop
    op.SlurpLeft ->
      model.Multi([
        Navigation(nav.LeaveIfItem),
        Navigation(nav.Move(-1)),
        model.Copy("0"),
        model.Delete,
        model.InsertInto("0"),
        Navigation(nav.Leave),
      ])
    op.SlurpRight ->
      model.Multi([
        Navigation(nav.LeaveIfItem),
        Navigation(nav.Move(1)),
        model.Copy("0"),
        model.Delete,
        Navigation(nav.Move(-1)),
        model.Alternatives([
          model.Multi([
            Navigation(nav.Enter),
            Navigation(nav.Last),
            model.Append("0"),
          ]),
          model.InsertInto("0"),
        ]),
        Navigation(nav.Leave),
      ])
    op.BarfLeft ->
      model.Multi([
        Navigation(nav.EnterIfExpr),
        Navigation(nav.Jump(0)),
        model.Copy("0"),
        model.Delete,
        Navigation(nav.Leave),
        model.Insert("0"),
        Navigation(nav.Move(1)),
      ])
    op.BarfRight ->
      model.Multi([
        Navigation(nav.EnterIfExpr),
        Navigation(nav.Last),
        model.Copy("0"),
        model.Delete,
        Navigation(nav.Leave),
        model.Append("0"),
      ])
    op.DragPrev ->
      model.Multi([
        model.Copy("0"),
        model.Delete,
        model.FlowPrev,
        model.Insert("0"),
      ])
    op.DragNext ->
      model.Alternatives([
        model.Multi([
          model.Copy("0"),
          model.Delete,
          model.FlowNext,
          model.Insert("0"),
        ]),
        model.Multi([
          model.Copy("0"),
          model.Delete,
          model.Append("0"),
          Navigation(nav.Move(1)),
        ]),
      ])
  }
}

pub fn render(model: Model) {
  html.div([], [
    html.style(
      [],
      "
body {
  margin: 0;
}
.node {
  display: flex;
  flex: row;
  padding: 0 0.5em;
  user-select: none;
}
.selected {
  background: cornflowerblue;
  border-bottom: 2px solid black;
}",
    ),
    html.div(
      [
        attribute.attribute("tabindex", "0"),
        attribute.autofocus(True),
        attribute.style([
          #("margin", "0"),
          #("width", "100svw"),
          #("height", "100svh"),
        ]),
        event.on_keyup(fn(key) {
          key
          |> key_to_modifier
          |> option.map(model.SetModifier(_, False))
          |> option.unwrap(model.Nop)
        }),
        event.on_keydown(fn(key) {
          case key_to_modifier(key) {
            Some(mod) -> model.SetModifier(mod, True)
            None -> {
              let shift = set.contains(model.modifiers, model.Shift)
              let control = set.contains(model.modifiers, model.Control)
              let alt = set.contains(model.modifiers, model.Alt)

              dict.get(model.keybinds, model.KeyMatch(key, shift, control, alt))
              |> result.lazy_or(fn() {
                dict.get(
                  model.keybinds,
                  model.KeyMatchAnyCase(key, control, alt),
                )
              })
              |> option.from_result
              |> option.map(operation_to_effect)
              |> option.unwrap(model.Nop)
            }
          }
        }),
      ],
      [render_content(model.document, [], model)],
    ),
  ])
}

pub fn render_content(expr: LispNode, path: List(Int), model: Model) {
  html.span(
    [
      attribute.classes([
        #("node", True),
        #("selected", path == model.selection),
      ]),
      event.on("click", fn(event) {
        event.stop_propagation(event)
        Ok(SelectPath(path))
      }),
    ],
    case expr {
      Expr(Document, nodes) -> render_list(nodes, path, model)
      Expr(Call(fst), nodes) ->
        list.flatten([
          [element.text("(")],
          [render_content(fst, path, model)],
          render_list(nodes, path, model),
          [element.text(")")],
        ])
      Expr(Func(name, args), nodes) ->
        list.flatten([
          [element.text("(fn ")],
          name |> option.map(fn(x) { [element.text(x)] }) |> option.unwrap([]),
          render_args(args),
          render_list(nodes, path, model),
          [element.text(")")],
        ])
      Expr(Array, nodes) ->
        list.flatten([
          [element.text("[")],
          render_list(nodes, path, model),
          [element.text("]")],
        ])
      Expr(Table, nodes) ->
        list.flatten([
          [element.text("{")],
          render_list(nodes, path, model),
          [element.text("}")],
        ])
      Item(item) -> [render_item(item)]
      syntax.Error(..) -> [
        html.div([attribute.class("error")], [
          element.text(syntax.to_string(expr)),
        ]),
      ]
    },
  )
}

pub fn render_item(item: syntax.Item) {
  item
  |> syntax.item_to_string
  |> element.text
}

pub fn render_args(args: List(Argument)) {
  list.map(args, fn(arg) {
    case arg {
      Argument(ident) -> element.text(ident)
      ArgumentInvalid(..) -> element.text("Invalid Arg")
    }
  })
}

pub fn render_list(expr: List(LispNode), path: List(Int), model: Model) {
  list.index_map(expr, fn(item, i) { render_content(item, [i, ..path], model) })
}
