import gleam/list
import gleam/option

import lustre/attribute
import lustre/element
import lustre/element/html

import lisp.{ALArg, ALError, Array, Call, Func}
import syntax.{Item}

pub fn render(expr: lisp.Node) {
  html.html([], [
    html.head([], [
      html.style(
        [],
        "
      .node {
        display: flex;
        flex: row;
        gap: 1em;
      }",
      ),
    ]),
    html.body([], [render_content(expr, [])]),
  ])
}

pub fn render_content(expr: lisp.Node, path: List(Int)) {
  html.span([attribute.class("node")], case expr {
    Call(nodes) ->
      list.flatten([
        [element.text("(")],
        render_list(nodes, path),
        [element.text(")")],
      ])
    Array(nodes) ->
      list.flatten([
        [element.text("[")],
        render_list(nodes, path),
        [element.text("]")],
      ])
    Func(name, alist, body) ->
      list.flatten([
        [element.text("( fn ")],
        name |> option.map(fn(x) { [element.text(x)] }) |> option.unwrap([]),
        [element.text("[")],
        render_alist(alist),
        [element.text("]")],
        render_list(body, path),
      ])
    lisp.Item(item) -> [render_item(item)]
  })
}

pub fn render_item(item: syntax.Item) {
  item
  |> syntax.item_to_string
  |> element.text
}

pub fn render_list(expr: List(lisp.Node), path: List(Int)) {
  list.index_map(expr, fn(item, i) {
    render_content(item, list.append(path, [i]))
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
