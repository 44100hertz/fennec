import gleam/io
import gleam/list

import lustre/attribute
import lustre/element
import lustre/element/html
import lustre/event

import model.{type Model, SelectPath}
import syntax.{type Node, Expr, Item}

pub fn render(model: Model) {
  html.html([], [
    html.head([], [
      html.style(
        [],
        "
      .node {
        display: flex;
        flex: row;
        padding: 0 0.5em;
        user-select: none;
      }
      .selected {
        background: red;
      }",
      ),
    ]),
    html.body([], [render_content(model.parse_tree, [], model)]),
  ])
}

pub fn render_content(expr: Node, path: List(Int), model: Model) {
  html.span(
    [
      attribute.classes([
        #("node", True),
        #("selected", path == model.select_path),
      ]),
      event.on("click", fn(event) {
        event.stop_propagation(event)
        Ok(SelectPath(path))
      }),
    ],
    case expr {
      Expr([Item(syntax.Array), ..nodes]) ->
        list.flatten([
          [element.text("[")],
          render_list(nodes, path, model),
          [element.text("]")],
        ])
      Expr(nodes) ->
        list.flatten([
          [element.text("(")],
          render_list(nodes, path, model),
          [element.text(")")],
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

pub fn render_list(expr: List(Node), path: List(Int), model: Model) {
  list.index_map(expr, fn(item, i) {
    render_content(item, list.append(path, [i]), model)
  })
}
