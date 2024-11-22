pub type Operation {
  // navigation
  Root
  Enter
  FlowEnter
  FlowBottom
  Leave
  Next
  Prev
  FlowNext
  FlowPrev
  First
  Last
  FlowFirst
  FlowLast

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
    Root -> "Go to document root"
    Enter -> "Go into child node (basic)"
    FlowEnter -> "Flow into child node"
    FlowBottom -> "Flow into deepest node"
    Leave -> "Leave to parent node"
    Next -> "Go to next sibling (basic)"
    Prev -> "Go to previous sibling (basic)"
    FlowNext -> "Flow to next sibling or cousin/uncle"
    FlowPrev -> "Flow to previous sibling or cousin/uncle"
    First -> "Go to first sibling"
    Last -> "Go to last sibling"
    FlowFirst -> "Flow to first sibling or first cousin/uncle"
    FlowLast -> "Flow to last sibling or last cousin/uncle"

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
