import gleam/list
import gleam/option.{type Option, None, Some}

import lustre/attribute
import lustre/element
import lustre/element/html
import lustre/event

import model.{type Model}
import syntax.{
  type Argument, type LispNode, Argument, ArgumentInvalid, Array, Call, Document,
  Expr, Func, Item, Table,
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
        event.on_keyup(model.KeyUp(_)),
        event.on_keydown(model.KeyDown(_)),
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
        Ok(model.NodeClicked(path))
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
