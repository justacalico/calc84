import 'ast.dart';
import 'tokenizer.dart';
import 'value.dart';

/// Recursive descent parser following the classic precedence order:
/// logic < compare < add < mul < implicit-mul < negate < power < postfix.
class Parser {
  Parser(this.tokens);

  final List<Tok> tokens;
  int pos = 0;

  static Node parse(String src) => Parser(tokenize(src)).statement();

  Tok? get peek => pos < tokens.length ? tokens[pos] : null;

  Tok next() {
    final t = peek;
    if (t == null) throw const CalcException('SYNTAX');
    pos++;
    return t;
  }

  bool at(TokType type, [String? text]) {
    final t = peek;
    return t != null && t.type == type && (text == null || t.text == text);
  }

  bool takeOp(String op) {
    if (at(TokType.op, op)) {
      pos++;
      return true;
    }
    return false;
  }

  Node statement() {
    final items = <Node>[commandOrExpr()];
    while (at(TokType.colon)) {
      pos++;
      items.add(commandOrExpr());
    }
    return items.length == 1 ? items.first : SeqNode(items);
  }

  Node commandOrExpr() {
    var e = logic();
    if (at(TokType.store)) {
      pos++;
      final t = next();
      if (t.type != TokType.name && t.type != TokType.func) {
        throw const CalcException('SYNTAX');
      }
      if (t.text == 'dim(') {
        final n = next();
        if (n.type != TokType.name) throw const CalcException('SYNTAX');
        _expect(TokType.rparen);
        e = StoreNode(e, 'dim(${n.text})');
      } else {
        var name = t.text;
        if (name.endsWith('(')) {
          name = name.substring(0, name.length - 1);
        }
        List<Node>? index;
        if (at(TokType.lparen)) {
          // Element store: L1(i), [A](r,c)
          pos++;
          index = [logic()];
          while (at(TokType.comma)) {
            pos++;
            index.add(logic());
          }
          _expect(TokType.rparen);
        }
        e = StoreNode(e, name, index);
      }
    }
    while (at(TokType.op) && hintTokens.contains(peek!.text)) {
      e = HintNode(e, next().text);
    }
    return e;
  }

  Node logic() {
    var l = compare();
    while (at(TokType.op) &&
        (peek!.text == 'and' || peek!.text == 'or' || peek!.text == 'xor')) {
      final op = next().text;
      l = BinaryNode(op, l, compare());
    }
    return l;
  }

  static const _cmp = {'=', '≠', '<', '≤', '>', '≥'};

  Node compare() {
    var l = add();
    while (at(TokType.op) && _cmp.contains(peek!.text)) {
      final op = next().text;
      l = BinaryNode(op, l, add());
    }
    return l;
  }

  Node add() {
    var l = mul();
    while (true) {
      if (takeOp('+')) {
        l = BinaryNode('+', l, mul());
      } else if (takeOp('-')) {
        l = BinaryNode('-', l, mul());
      } else {
        return l;
      }
    }
  }

  Node mul() {
    var l = implied();
    while (true) {
      if (takeOp('*')) {
        l = BinaryNode('*', l, implied());
      } else if (takeOp('/')) {
        l = BinaryNode('/', l, implied());
      } else {
        return l;
      }
    }
  }

  bool _startsExpr(Tok? t) {
    if (t == null) return false;
    return t.type == TokType.number ||
        t.type == TokType.name ||
        t.type == TokType.func ||
        t.type == TokType.lparen ||
        t.type == TokType.lbrace ||
        t.type == TokType.str ||
        (t.type == TokType.op && t.text == '⁻');
  }

  Node implied() {
    var l = perm();
    while (_startsExpr(peek)) {
      l = BinaryNode('*', l, perm());
    }
    return l;
  }

  /// nPr / nCr sit between negation and multiplication.
  Node perm() {
    var l = negate();
    while (at(TokType.op) &&
        (peek!.text == 'nPr' || peek!.text == 'nCr')) {
      final op = next().text;
      l = BinaryNode(op, l, negate());
    }
    return l;
  }

  Node negate() {
    if (takeOp('⁻')) {
      return UnaryNode('⁻', negate());
    }
    if (takeOp('-')) {
      // A leading '-' reads as negation like on the real keypad
      // when there is no left operand.
      return UnaryNode('⁻', negate());
    }
    return power();
  }

  Node power() {
    final base = postfix();
    if (takeOp('^')) {
      return BinaryNode('^', base, negate());
    }
    if (takeOp('ˣ√')) {
      return BinaryNode('ˣ√', base, negate());
    }
    return base;
  }

  Node postfix() {
    var e = primary();
    while (true) {
      if (e is NameNode && at(TokType.lparen)) {
        pos++;
        final args = <Node>[];
        if (!at(TokType.rparen)) {
          args.add(logic());
          while (at(TokType.comma)) {
            pos++;
            args.add(logic());
          }
        }
        _expect(TokType.rparen);
        e = IndexNode(e.name, args);
        continue;
      }
      if (at(TokType.op) && postfixOps.contains(peek!.text)) {
        e = PostfixNode(next().text, e);
        continue;
      }
      return e;
    }
  }

  Node primary() {
    final t = next();
    switch (t.type) {
      case TokType.number:
        final v = double.tryParse(t.text.replaceAll('ᴇ', 'E').replaceAll('⁻', '-'));
        if (v == null) throw const CalcException('SYNTAX');
        return NumNode(v);
      case TokType.str:
        return StrNode(t.text);
      case TokType.name:
        return NameNode(t.text);
      case TokType.lparen:
        final e = logic();
        _expect(TokType.rparen);
        return e;
      case TokType.lbracket:
        final rows = <List<Node>>[];
        while (at(TokType.lbracket)) {
          pos++;
          final row = <Node>[logic()];
          while (at(TokType.comma)) {
            pos++;
            row.add(logic());
          }
          _expect(TokType.rbracket);
          rows.add(row);
        }
        _expect(TokType.rbracket);
        return MatrixLitNode(rows);
      case TokType.lbrace:
        final items = <Node>[];
        if (!at(TokType.rbrace)) {
          items.add(logic());
          while (at(TokType.comma)) {
            pos++;
            items.add(logic());
          }
        }
        _expect(TokType.rbrace);
        return ListNode(items);
      case TokType.func:
        if (t.text == 'rand') {
          // rand takes an optional trial count: rand(5) yields a list.
          if (at(TokType.lparen)) {
            pos++;
            final arg = logic();
            _expect(TokType.rparen);
            return CallNode('rand', [arg]);
          }
          return const CallNode('rand', []);
        }
        final fn = t.text.substring(0, t.text.length - 1);
        final args = <Node>[];
        if (!at(TokType.rparen)) {
          args.add(logic());
          while (at(TokType.comma)) {
            pos++;
            args.add(logic());
          }
        }
        _expect(TokType.rparen);
        return CallNode(fn, args);
      default:
        throw const CalcException('SYNTAX');
    }
  }

  void _expect(TokType type) {
    final t = next();
    if (t.type != type) throw const CalcException('SYNTAX');
  }
}
