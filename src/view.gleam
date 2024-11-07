import gleam/list
import gleam/option

import lustre/attribute
import lustre/element
import lustre/element/html
import lustre/event.{on}

import lisp.{ALArg, ALError, Array, Call, Func, Root}
import model.{type Model, SelectPath}
import syntax.{Item}

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

pub fn render_content(expr: lisp.Node, path: List(Int), model: Model) {
  html.span(
    [
      attribute.classes([
        #("node", True),
        #("selected", path == model.select_path),
      ]),
      on("click", fn(event) {
        event.stop_propagation(event)
        Ok(SelectPath(path))
      }),
    ],
    case expr.body {
      Root(nodes) -> render_list(nodes, path, model)
      Call(nodes) ->
        list.flatten([
          [element.text("(")],
          render_list(nodes, path, model),
          [element.text(")")],
        ])
      Array(nodes) ->
        list.flatten([
          [element.text("[")],
          render_list(nodes, path, model),
          [element.text("]")],
        ])
      Func(name, alist, body) ->
        list.flatten([
          [element.text("( fn ")],
          name |> option.map(fn(x) { [element.text(x)] }) |> option.unwrap([]),
          [element.text("[")],
          render_alist(alist),
          [element.text("]")],
          render_list(body, path, model),
          [element.text(")")],
        ])
      lisp.Item(item) -> [render_item(item)]
    },
  )
}

pub fn render_item(item: syntax.Item) {
  item
  |> syntax.item_to_string
  |> element.text
}

pub fn render_list(expr: List(lisp.Node), path: List(Int), model: Model) {
  list.index_map(expr, fn(item, i) {
    render_content(item, list.append(path, [i]), model)
  })
}

pub fn render_alist(expr: List(lisp.AListItem)) {
  list.map(expr, fn(arg) {
    case arg {
      ALArg(s) -> s
      ALError(node) -> syntax.to_string(node)
    }
    |> element.text
  })
}
