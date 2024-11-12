import gleam/dict
import gleam/list
import gleam/option

import lustre/attribute
import lustre/element
import lustre/element/html
import lustre/event

import model.{type Model, Navigation, SelectPath}
import navigation as nav
import operations.{type Operation} as op
import syntax.{
  type LispNode, ArgumentList, Array, Call, Document, Expr, Func, Item, Table,
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
    op.Append -> model.Multi([model.Append("1"), Navigation(nav.Move(1))])

    op.Delete -> model.Delete
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
    // op.SlurpLeft ->
    //   model.Multi([
    //     model.SavePath,
    //     model.FlowPrev,
    //     model.Copy("0"),
    //     model.Delete,
    //     model.LoadPath,
    //     model.Insert("0"),
    //   ])
    op.SlurpLeft -> model.Nop
    op.SlurpRight -> model.Nop
    op.BarfLeft -> model.Nop
    op.BarfRight -> model.Nop
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
        event.on_keydown(fn(key) {
          key
          |> dict.get(model.keybinds, _)
          |> option.from_result
          |> option.map(operation_to_effect)
          |> option.unwrap(model.Nop)
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
      Expr(Call, nodes) ->
        list.flatten([
          [element.text("(")],
          render_list(nodes, path, model),
          [element.text(")")],
        ])
      Expr(Func(name), nodes) ->
        list.flatten([
          [element.text("(fn ")],
          name |> option.map(fn(x) { [element.text(x)] }) |> option.unwrap([]),
          render_list(nodes, path, model),
          [element.text(")")],
        ])
      Expr(Array, nodes) ->
        list.flatten([
          [element.text("[")],
          render_list(nodes, path, model),
          [element.text("]")],
        ])
      Expr(ArgumentList, nodes) ->
        list.flatten([
          [element.text("<")],
          render_list(nodes, path, model),
          [element.text(">")],
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

pub fn render_list(expr: List(LispNode), path: List(Int), model: Model) {
  list.index_map(expr, fn(item, i) { render_content(item, [i, ..path], model) })
}
