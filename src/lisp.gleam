import gleam/list.{map}
import gleam/option.{type Option, None, Some}
import syntax.{
  type Item as SItem, type Node as SNode, type Position, Curly, Ident,
  Item as SItem, Node as SNode, Parens, Position, Round, Square,
}

pub type Node {
  Node(body: NodeBody, position: Position)
}

pub type NodeBody {
  Root(List(Node))
  Call(List(Node))
  Array(List(Node))
  Func(name: Option(String), alist: List(AListItem), body: List(Node))
  Item(SItem)
}

// arg list
pub type AListItem {
  ALArg(String)
  ALError(SNode)
}

pub fn parse_root(syntax: List(SNode)) {
  Node(Root(list.map(syntax, parse)), Position(1, 1))
}

pub fn parse(syntax: SNode) {
  case syntax {
    // parse functions
    SNode(
      Parens(
        Round,
        [
          SNode(SItem(Ident("fn")), _),
          SNode(SItem(Ident(name)), _),
          SNode(Parens(Square, alist), _),
          ..body
        ],
      ),
      pos,
    ) -> Node(Func(Some(name), parse_alist(alist), parse_list(body)), pos)

    SNode(
      Parens(
        Round,
        [SNode(SItem(Ident("fn")), _), SNode(Parens(Square, alist), _), ..body],
      ),
      pos,
    ) -> Node(Func(None, parse_alist(alist), parse_list(body)), pos)

    // Correct malformed functions by adding an empty arg list
    SNode(
      Parens(
        Round,
        [SNode(SItem(Ident("fn")), _), SNode(SItem(Ident(name)), _), ..rest],
      ),
      pos,
    ) -> Node(Func(Some(name), [], parse_list(rest)), pos)

    SNode(Parens(Round, [SNode(SItem(Ident("fn")), _), ..rest]), pos) ->
      Node(Func(None, [], parse_list(rest)), pos)

    SNode(Parens(Round, items), pos) -> Node(Call(parse_list(items)), pos)
    SNode(Parens(Square, items), pos) -> Node(Array(parse_list(items)), pos)
    SNode(Parens(Curly, items), pos) -> todo
    SNode(SItem(it), pos) -> Node(Item(it), pos)
  }
}

pub fn parse_alist(syntax: List(SNode)) {
  map(syntax, fn(arg) {
    case arg.body {
      SItem(Ident(name)) -> ALArg(name)
      _ -> ALError(arg)
    }
  })
}

pub fn parse_list(syntax) {
  map(syntax, parse)
}
// pub fn unparse(structure) {
//   case structure. {
//     Call(content) -> Parens(Round, unparse_list(content))
//     Array(content) -> Parens(Square, unparse_list(content))
//     Func(name, alist, body) ->
//       Parens(
//         Round,
//         list.flatten([
//           [SItem(Ident("fn"))],
//           case name {
//             Some(name) -> [SItem(Ident(name))]
//             None -> []
//           },
//           [
//             Parens(
//               Square,
//               map(alist, fn(arg) {
//                 case arg {
//                   ALArg(arg) -> SItem(Ident(arg))
//                   ALError(syn) -> syn
//                 }
//               }),
//             ),
//           ],
//           unparse_list(body),
//         ]),
//       )
//     Item(item) -> SItem(item)
//   }
// }

// pub fn unparse_list(structures) {
//   map(structures, unparse)
// }
