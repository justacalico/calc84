import 'dart:math' as math;

import 'ast.dart';
import 'complex.dart';
import 'context.dart';
import 'fraction.dart';
import 'functions.dart';
import 'matrix.dart';
import 'parser.dart';
import 'value.dart';

/// Evaluates an AST against calculator memory.
class Evaluator {
  Evaluator(this.ctx);

  final CalcContext ctx;

  Value eval(Node n) => switch (n) {
        NumNode() => RealValue(n.v),
        StrNode() => StringValue(n.v),
        NameNode() => _name(n.name),
        ListNode() => ListValue([for (final i in n.items) eval(i)]),
        IndexNode() => _index(n),
        MatrixLitNode() => _matrixLit(n),
        CallNode() => callFunction(this, n.fn, n.args),
        UnaryNode() => _unary(n.op, eval(n.operand)),
        BinaryNode() => _binary(n.op, n.left, n.right),
        PostfixNode() => _postfix(n.op, eval(n.operand)),
        StoreNode() => _store(n),
        HintNode() => eval(n.expr),
        SeqNode() => _seq(n),
      };

  Value _seq(SeqNode n) {
    Value last = const RealValue(0);
    for (final item in n.items) {
      last = eval(item);
    }
    return last;
  }

  Value _matrixLit(MatrixLitNode n) {
    if (n.rows.isEmpty) throw const CalcException('SYNTAX');
    final cols = n.rows.first.length;
    final m = Matrix(n.rows.length, cols);
    for (var r = 0; r < n.rows.length; r++) {
      if (n.rows[r].length != cols) {
        throw const CalcException('DIM MISMATCH');
      }
      for (var c = 0; c < cols; c++) {
        m.set(r, c, eval(n.rows[r][c]).asReal);
      }
    }
    return MatrixValue(m);
  }

  Value _index(IndexNode n) {
    final name = n.name;
    final a = [for (final x in n.args) eval(x).asReal];
    if (a.isEmpty) throw const CalcException('SYNTAX');
    if (name.startsWith('L') && ctx.lists.containsKey(name)) {
      final l = ctx.lists[name]!;
      final i = a[0].round();
      if (i < 1 || i > l.length) throw const CalcException('DOMAIN');
      return RealValue(l[i - 1]);
    }
    if (name.startsWith('[') && name.endsWith(']')) {
      final m = ctx.matrices[name];
      if (m == null) throw const CalcException('UNDEFINED');
      if (a.length != 2) throw const CalcException('SYNTAX');
      final r = a[0].round(), c = a[1].round();
      if (r < 1 || c < 1 || r > m.rows || c > m.cols) {
        throw const CalcException('DOMAIN');
      }
      return RealValue(m.at(r - 1, c - 1));
    }
    if (name == 'u' || name == 'v' || name == 'w') {
      return RealValue(ctx.sequenceAt(name, a[0].round()));
    }
    if (_isEquationName(name)) {
      return _evalEquation(name, a[0]);
    }
    // Plain variable followed by a parenthesized expression: implied
    // multiplication like the real OS.
    if (a.length != 1) throw const CalcException('SYNTAX');
    return _binary('*', null, null,
        precomputed: (_name(name), RealValue(a[0])));
  }

  Value _name(String name) {
    switch (name) {
      case 'Ans':
        return ctx.ans;
      case 'π':
        return RealValue(math.pi);
      case 'e':
        return RealValue(math.e);
      case 'i':
        _requireComplex();
        return const ComplexValue(Complex.i);
      case 'getKey':
        return RealValue(ctx.lastKeyCode.toDouble());
      case 'n':
        return RealValue(ctx.getVar('n'));
    }
    if (name.startsWith('L') && ctx.lists.containsKey(name)) {
      return ListValue(
          [for (final v in ctx.lists[name]!) RealValue(v)]);
    }
    if (name.startsWith('[') && name.endsWith(']')) {
      final m = ctx.matrices[name];
      if (m == null) throw const CalcException('UNDEFINED');
      return MatrixValue(m);
    }
    if (name.startsWith('Str')) {
      return StringValue(ctx.strings[name] ?? '');
    }
    if (name == 'u' || name == 'v' || name == 'w') {
      if (ctx.vars.containsKey('_seq_$name')) {
        return RealValue(ctx.vars['_seq_$name']!);
      }
      return RealValue(
          ctx.sequenceAt(name, ctx.getVar('n').round().clamp(1, 9999)));
    }
    if (_isEquationName(name)) {
      // Bare equation name evaluates at the current X/T/theta/n.
      return _evalEquation(name);
    }
    return RealValue(ctx.getVar(name));
  }

  bool _isEquationName(String name) =>
      ctx.equations.containsKey(name) &&
      (ctx.equations[name]?.isDefined ?? false);

  Value _evalEquation(String name, [double? arg]) {
    final eq = ctx.equations[name];
    if (eq == null || !eq.isDefined) {
      throw const CalcException('UNDEFINED');
    }
    final saved = ctx.vars['X'];
    if (arg != null) ctx.vars['X'] = arg;
    try {
      return evaluateInline(eq.expression, ctx);
    } finally {
      if (arg != null) {
        if (saved == null) {
          ctx.vars.remove('X');
        } else {
          ctx.vars['X'] = saved;
        }
      }
    }
  }

  Value _store(StoreNode n) {
    final v = eval(n.expr);
    final t = n.target;
    if (t.startsWith('L')) {
      ctx.lists[t] = _toRealList(v);
    } else if (t.startsWith('[')) {
      if (v is! MatrixValue) throw const CalcException('DATA TYPE');
      ctx.matrices[t] = v.m;
    } else if (t.startsWith('Str')) {
      if (v is! StringValue) throw const CalcException('DATA TYPE');
      ctx.strings[t] = v.v;
    } else if (RegExp(r'^(Y\d|X\dT|Y\dT|r\d|u|v|w)$').hasMatch(t)) {
      if (t == 'u' || t == 'v' || t == 'w') {
        ctx.sequences[t]!.expression = unparse(n.expr);
      } else {
        ctx.equation(t).expression = unparse(n.expr);
      }
    } else {
      ctx.setVar(t, v.asReal);
    }
    return v;
  }

  List<double> _toRealList(Value v) {
    if (v is ListValue) {
      return [for (final i in v.items) i.asReal];
    }
    if (v is RealValue) return [v.v];
    throw const CalcException('DATA TYPE');
  }

  void _requireComplex() {
    if (ctx.complexMode != ComplexMode.aBi) {
      throw const CalcException('NONREAL ANS');
    }
  }

  // Elementwise broadcast for lists.
  Value _broadcast(Value v, double Function(double) f) {
    if (v is ListValue) {
      return ListValue([for (final i in v.items) _broadcast(i, f)]);
    }
    return RealValue(f(v.asReal));
  }

  Value _broadcastC(Value v, Complex Function(Complex) f) {
    if (v is ListValue) {
      return ListValue([for (final i in v.items) _broadcastC(i, f)]);
    }
    return ComplexValue(f(v.asComplex));
  }

  Value _unary(String op, Value v) {
    if (op == '⁻') {
      if (v is MatrixValue) return MatrixValue(v.m.scale(-1));
      if (v.isComplex || _wantsComplex(v)) {
        return _broadcastC(v, (c) => -c);
      }
      return _broadcast(v, (x) => -x);
    }
    throw const CalcException('SYNTAX');
  }

  bool _wantsComplex(Value v) =>
      v is ComplexValue && ctx.complexMode == ComplexMode.aBi;

  Value _postfix(String op, Value v) => switch (op) {
        '!' => _broadcast(v, _factorial),
        '°' => _broadcast(v, (x) => x * math.pi / 180),
        '′' => _broadcast(v, (x) => x * math.pi / 10800),
        '″' => _broadcast(v, (x) => x * math.pi / 648000),
        'ʳ' => _broadcast(v, (x) =>
            ctx.angleMode == AngleMode.degree ? x * 180 / math.pi : x),
        '²' => _binary('*', null, null, precomputed: (v, v)),
        '³' => _pow3(v),
        '⁻¹' => _recip(v),
        'ᵀ' => _transpose(v),
        '%' => _broadcast(v, (x) => x / 100),
        _ => throw const CalcException('SYNTAX'),
      };

  Value _pow3(Value v) =>
      _binary('*', null, null, precomputed: (_binary('*', null, null, precomputed: (v, v)), v));

  Value _recip(Value v) => switch (v) {
        MatrixValue() => MatrixValue(v.m.inverse()),
        _ when v.isComplex => _broadcastC(v, (c) => Complex.one / c),
        _ => _broadcast(v, (x) {
            if (x == 0) throw const CalcException('DIVIDE BY 0');
            return 1 / x;
          }),
      };

  Value _transpose(Value v) {
    if (v is! MatrixValue) throw const CalcException('DATA TYPE');
    return MatrixValue(v.m.transpose());
  }

  double _factorial(double x) {
    if (x < 0 || x > 449 || x != x.roundToDouble()) {
      if (x == x.roundToDouble() || x < 0) {
        // Use gamma for non-integers >= 0 like the real OS does
        // via x! = gamma(x+1).
        if (x >= 0) return _gamma(x + 1);
        throw const CalcException('DOMAIN');
      }
      if (x > 449) throw const CalcException('OVERFLOW');
      return _gamma(x + 1);
    }
    var r = 1.0;
    for (var i = 2; i <= x.round(); i++) {
      r *= i;
    }
    return r;
  }

  double _gamma(double x) {
    // Lanczos approximation.
    const p = [
      0.99999999999980993, 676.5203681218851, -1259.1392167224028,
      771.32342877765313, -176.61502916214059, 12.507343278686905,
      -0.13857109526572012, 9.9843695780195716e-6, 1.5056327351493116e-7,
    ];
    if (x < 0.5) {
      return math.pi / (math.sin(math.pi * x) * _gamma(1 - x));
    }
    x -= 1;
    var a = p[0];
    for (var i = 1; i < p.length; i++) {
      a += p[i] / (x + i);
    }
    final t = x + p.length - 1.5;
    return math.sqrt(2 * math.pi) * math.pow(t, x + 0.5) * math.exp(-t) * a;
  }

  Value _binary(String op, Node? ln, Node? rn,
      {(Value, Value)? precomputed}) {
    final l = precomputed?.$1 ?? eval(ln!);
    final r = precomputed?.$2 ?? eval(rn!);

    // List broadcast.
    if (l is ListValue || r is ListValue) {
      return _listBinary(op, l, r);
    }

    // Matrices.
    if (l is MatrixValue || r is MatrixValue) {
      return _matrixBinary(op, l, r);
    }

    if (l is StringValue || r is StringValue) {
      return _stringBinary(op, l, r);
    }

    if (l is ComplexValue || r is ComplexValue) {
      return _complexBinary(op, l.asComplex, r.asComplex);
    }

    final a = l.asReal;
    final b = r.asReal;
    if (op == '^') return _powValue(a, b);
    if (op == 'ˣ√') return _powValue(b, 1 / a);
    return RealValue(switch (op) {
      '+' => a + b,
      '-' => a - b,
      '*' => a * b,
      '/' => b == 0 ? throw const CalcException('DIVIDE BY 0') : a / b,
      'nPr' => _nPr(a, b),
      'nCr' => _nCr(a, b),
      '=' => (a == b) ? 1 : 0,
      '≠' => (a != b) ? 1 : 0,
      '<' => (a < b) ? 1 : 0,
      '≤' => (a <= b) ? 1 : 0,
      '>' => (a > b) ? 1 : 0,
      '≥' => (a >= b) ? 1 : 0,
      'and' => (a != 0 && b != 0) ? 1 : 0,
      'or' => (a != 0 || b != 0) ? 1 : 0,
      'xor' => ((a != 0) != (b != 0)) ? 1 : 0,
      _ => throw const CalcException('SYNTAX'),
    });
  }

  Value _powValue(double a, double b) {
    if (a == 0 && b <= 0) throw const CalcException('DOMAIN');
    if (a < 0) {
      final frac = Fraction.approximate(b, maxDen: 999);
      if (frac != null && frac.d.isOdd) {
        final r = math.pow(-a, b).toDouble();
        return RealValue(frac.n.isEven ? r.abs() : -r.abs());
      }
      _requireComplex();
      return _complexToValue(Complex(a, 0).pow(Complex(b, 0)));
    }
    final r = math.pow(a, b);
    if (r.isNaN) throw const CalcException('DOMAIN');
    return RealValue(r.toDouble());
  }

  Value _complexToValue(Complex c) =>
      c.isReal ? RealValue(c.re) : ComplexValue(c);

  Value _complexBinary(String op, Complex a, Complex b) {
    _requireComplex();
    Complex c;
    switch (op) {
      case '+':
        c = a + b;
      case '-':
        c = a - b;
      case '*':
        c = a * b;
      case '/':
        if (b == Complex.zero) throw const CalcException('DIVIDE BY 0');
        c = a / b;
      case '^':
        c = a.pow(b);
      case 'ˣ√':
        c = b.pow(Complex.one / a);
      case '=':
        return RealValue(a == b ? 1 : 0);
      case '≠':
        return RealValue(a != b ? 1 : 0);
      case 'and':
        return RealValue(a != Complex.zero && b != Complex.zero ? 1 : 0);
      case 'or':
        return RealValue(a != Complex.zero || b != Complex.zero ? 1 : 0);
      case 'xor':
        return RealValue((a != Complex.zero) != (b != Complex.zero) ? 1 : 0);
      default:
        throw const CalcException('SYNTAX');
    }
    return _complexToValue(c);
  }

  Value _matrixBinary(String op, Value l, Value r) {
    switch (op) {
      case '+':
        if (l is MatrixValue && r is MatrixValue) {
          return MatrixValue(l.m + r.m);
        }
        throw const CalcException('DIM MISMATCH');
      case '-':
        if (l is MatrixValue && r is MatrixValue) {
          return MatrixValue(l.m - r.m);
        }
        throw const CalcException('DIM MISMATCH');
      case '*':
        if (l is MatrixValue && r is MatrixValue) {
          return MatrixValue(l.m.multiply(r.m));
        }
        if (l is MatrixValue) return MatrixValue(l.m.scale(r.asReal));
        if (r is MatrixValue) return MatrixValue(r.m.scale(l.asReal));
        throw const CalcException('DATA TYPE');
      case '/':
        if (l is MatrixValue) {
          final s = r.asReal;
          if (s == 0) throw const CalcException('DIVIDE BY 0');
          return MatrixValue(l.m.scale(1 / s));
        }
        throw const CalcException('DATA TYPE');
      case '^':
        if (l is! MatrixValue) throw const CalcException('DATA TYPE');
        final e = r.asReal;
        if (e != e.roundToDouble()) {
          throw const CalcException('DOMAIN');
        }
        return MatrixValue(l.m.pow(e.round()));
      case '=':
        return RealValue(_matEq(l, r) ? 1 : 0);
      case '≠':
        return RealValue(_matEq(l, r) ? 0 : 1);
      default:
        throw const CalcException('SYNTAX');
    }
  }

  bool _matEq(Value l, Value r) =>
      l is MatrixValue &&
      r is MatrixValue &&
      l.m.rows == r.m.rows &&
      l.m.cols == r.m.cols &&
      _matSame(l.m, r.m);

  bool _matSame(Matrix a, Matrix b) {
    for (var i = 0; i < a.rows; i++) {
      for (var j = 0; j < a.cols; j++) {
        if (a.data[i][j] != b.data[i][j]) return false;
      }
    }
    return true;
  }

  Value _listBinary(String op, Value l, Value r) {
    if (l is ListValue && r is ListValue) {
      if (l.items.length != r.items.length) {
        throw const CalcException('DIM MISMATCH');
      }
      return ListValue([
        for (var i = 0; i < l.items.length; i++)
          _binary(op, null, null, precomputed: (l.items[i], r.items[i]))
      ]);
    }
    if (l is ListValue) {
      return ListValue([
        for (final i in l.items)
          _binary(op, null, null, precomputed: (i, r))
      ]);
    }
    return ListValue([
      for (final i in (r as ListValue).items)
        _binary(op, null, null, precomputed: (l, i))
    ]);
  }

  Value _stringBinary(String op, Value l, Value r) {
    final a = l is StringValue ? l.v : throw const CalcException('DATA TYPE');
    final b = r is StringValue ? r.v : throw const CalcException('DATA TYPE');
    return switch (op) {
      '+' => StringValue(a + b),
      '=' => RealValue(a == b ? 1 : 0),
      '≠' => RealValue(a != b ? 1 : 0),
      _ => throw const CalcException('SYNTAX'),
    };
  }

  double _nPr(double n, double r) {
    if (n < r || n < 0 || r < 0 || n != n.roundToDouble() || r != r.roundToDouble()) {
      throw const CalcException('DOMAIN');
    }
    var v = 1.0;
    for (var i = 0; i < r.round(); i++) {
      v *= n - i;
    }
    return v;
  }

  double _nCr(double n, double r) {
    final p = _nPr(n, r);
    var d = 1.0;
    for (var i = 2; i <= r.round(); i++) {
      d *= i;
    }
    return p / d;
  }
}

/// Re-render an AST back to entry text, used when storing into
/// equation variables like Y1.
String unparse(Node n) => switch (n) {
      NumNode() => _numText(n.v),
      StrNode() => '"${n.v}"',
      NameNode() => n.name,
      ListNode() => '{${n.items.map(unparse).join(',')}}',
      IndexNode() => '${n.name}(${n.args.map(unparse).join(',')})',
      MatrixLitNode() =>
        '[${n.rows.map((r) => '[${r.map(unparse).join(',')}]').join()}]',
      CallNode() => '${n.fn}(${n.args.map(unparse).join(',')})',
      UnaryNode() => '⁻${unparse(n.operand)}',
      BinaryNode() => '${unparse(n.left)}${n.op}${unparse(n.right)}',
      PostfixNode() => '${unparse(n.operand)}${n.op}',
      StoreNode() => '${unparse(n.expr)}→${n.target}',
      HintNode() => '${unparse(n.expr)}${n.hint}',
      SeqNode() => n.items.map(unparse).join(':'),
    };

String _numText(double v) {
  if (v == v.roundToDouble() && v.abs() < 1e15) {
    return v.round().toString();
  }
  return v.toString();
}

/// One-shot convenience: parse and evaluate [src].
Value evalSource(String src, CalcContext ctx) =>
    Evaluator(ctx).eval(Parser.parse(src));
