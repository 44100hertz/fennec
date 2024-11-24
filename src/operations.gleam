import navigation

pub type Operation {
  Navigation(nav: navigation.Navigation)

  Copy
  Insert
  InsertInto
  Append
  AppendInto

  // deletions
  Delete
  Raise
  Unwrap
  // SyntaxUnwrap // needed?
  // SyntaxDelete // needed?
  //
  // transformations
  Duplicate
  Split
  JoinLeft
  JoinRight
  // SyntaxJoin // needed?
  Convolute
  SlurpRight
  SlurpLeft
  BarfRight
  BarfLeft
  DragPrev
  DragNext
}

pub fn name(op: Operation) -> String {
  case op {
    Navigation(nav) ->
      case nav {
        navigation.Root -> "Go to document root"
        navigation.Leave -> "Leave to parent node"
        navigation.Enter -> "Go into child node (basic)"
        navigation.FlowEnter -> "Flow into child node"
        navigation.FlowBottom -> "Flow into deepest node"
        navigation.Prev -> "Go to next sibling (basic)"
        navigation.Next -> "Go to previous sibling (basic)"
        navigation.FlowPrev -> "Flow to previous sibling or cousin/uncle"
        navigation.FlowNext -> "Flow to next sibling or cousin/uncle"
        navigation.First -> "Go to first sibling"
        navigation.Last -> "Go to last sibling"
        navigation.FlowFirst -> "Flow to first sibling or first cousin/uncle"
        navigation.FlowLast -> "Flow to last sibling or last cousin/uncle"
      }

    Copy -> "Copy selection to register"
    Insert -> "Insert before selection"
    InsertInto -> "Insert inside expression (or start)"
    Append -> "Insert after selection"
    AppendInto -> "Append inside expression (or end)"

    // deletions
    Delete -> "Delete node and subtree"
    Raise -> "Replace parent node with this one"
    Unwrap -> "Replace this node with its content"

    // SyntaxUnwrap // needed?
    // SyntaxDelet // needed?
    // transformations
    Duplicate -> "Copy node forward"
    Split -> "Split node apart, copy car"
    JoinLeft -> "Join left, replacing left car"
    JoinRight -> "Join right, replacing right car"
    // SyntaxJoin // needed?
    Convolute -> "Switch parent and grandparent"
    SlurpRight -> "Slurp next node"
    SlurpLeft -> "Slurp previous node"
    BarfRight -> "Barf last node into next expression"
    BarfLeft -> "Barf first node into prev expression"
    DragPrev -> "Drag node left, swapping them"
    DragNext -> "Drag node right, swapping them"
  }
}
