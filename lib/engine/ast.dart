/// Parsed expression tree.
sealed class Node {
  const Node();
}

class NumNode extends Node {
  const NumNode(this.v);
  final double v;
}

class StrNode extends Node {
  const StrNode(this.v);
  final String v;
}

/// Variable, list, matrix or equation reference resolved at eval time.
class NameNode extends Node {
  const NameNode(this.name);
  final String name;
}

class CallNode extends Node {
  const CallNode(this.fn, this.args);
  final String fn;
  final List<Node> args;
}

class UnaryNode extends Node {
  const UnaryNode(this.op, this.operand);
  final String op;
  final Node operand;
}

class BinaryNode extends Node {
  const BinaryNode(this.op, this.left, this.right);
  final String op;
  final Node left;
  final Node right;
}

class PostfixNode extends Node {
  const PostfixNode(this.op, this.operand);
  final String op;
  final Node operand;
}

class ListNode extends Node {
  const ListNode(this.items);
  final List<Node> items;
}

/// NAME(expr) or NAME(r,c): list/matrix indexing, equation call.
class IndexNode extends Node {
  const IndexNode(this.name, this.args);
  final String name;
  final List<Node> args;
}

/// [[a,b][c,d]] matrix literal, rows as parsed node lists.
class MatrixLitNode extends Node {
  const MatrixLitNode(this.rows);
  final List<List<Node>> rows;
}

/// expr → NAME, or expr → NAME(i) for list/matrix element stores.
class StoreNode extends Node {
  const StoreNode(this.expr, this.target, [this.index]);
  final Node expr;
  final String target;

  /// Element index expressions for L1(i) / [A](r,c) targets.
  final List<Node>? index;
}

/// expr ▸Frac / ▸Dec / ▸DMS / ▸Rect / ▸Polar display hint.
class HintNode extends Node {
  const HintNode(this.expr, this.hint);
  final Node expr;
  final String hint;
}

/// stmt : stmt : stmt
class SeqNode extends Node {
  const SeqNode(this.items);
  final List<Node> items;
}
