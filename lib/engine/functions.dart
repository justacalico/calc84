import 'dart:math' as math;

import 'ast.dart';
import 'calculus.dart';
import 'complex.dart';
import 'context.dart';
import 'distributions.dart';
import 'evaluator.dart';
import 'matrix.dart';
import 'value.dart';

/// Dispatches a CallNode to its implementation. Handlers receive the
/// raw argument nodes so functions like nDeriv( can re-evaluate the
/// expression with a bound variable.
Value callFunction(Evaluator ev, String name, List<Node> args) {
  final h = _handlers[name];
  if (h == null) throw CalcException('UNDEFINED', name);
  return h(ev, args);
}

bool isFunctionName(String name) => _handlers.containsKey(name);

typedef _Fn = Value Function(Evaluator ev, List<Node> args);

final Map<String, _Fn> _handlers = {
  // Trig
  'sin': _trig((x) => math.sin(x), (c) => c.sin()),
  'cos': _trig((x) => math.cos(x), (c) => c.cos()),
  'tan': _trig((x) => math.tan(x), (c) => c.tan()),
  'sin⁻¹': _invTrig((x) => math.asin(x), (c) => c.asin()),
  'cos⁻¹': _invTrig((x) => math.acos(x), (c) => c.acos()),
  'tan⁻¹': _invTrig((x) => math.atan(x), (c) => c.atan()),
  'sinh': _both((x) => _sinh(x), (c) => c.sinhC),
  'cosh': _both((x) => _cosh(x), (c) => c.coshC),
  'tanh': _both((x) => _sinh(x) / _cosh(x), (c) => c.tanhC),
  'sinh⁻¹': _both(
      (x) => math.log(x + math.sqrt(x * x + 1)), (c) => c.asinh),
  'cosh⁻¹': _both((x) {
    if (x < 1) throw _NotReal();
    return math.log(x + math.sqrt(x * x - 1));
  }, (c) => c.acosh),
  'tanh⁻¹': _both((x) {
    if (x <= -1 || x >= 1) throw _NotReal();
    return 0.5 * math.log((1 + x) / (1 - x));
  }, (c) => c.atanh),

  // Powers and logs
  '√': _sqrt,
  '³√': _plain((x) => _cbrt(x)),
  'ln': _ln,
  'log': _log10,
  'logBASE': _logBase,
  '10^': _plain((x) => math.pow(10, x).toDouble()),
  'e^': _exp,

  // Numeric
  'abs': _abs,
  'round': _round,
  'iPart': _plain((x) => x.truncateToDouble()),
  'fPart': _plain((x) => x - x.truncateToDouble()),
  'int': _plain((x) => x.floorToDouble()),
  'min': _minMax(true),
  'max': _minMax(false),
  'lcm': _gcdLcm(false),
  'gcd': _gcdLcm(true),
  'remainder': _remainder,
  'not': _not,

  // Calculus
  'nDeriv': _nDeriv,
  'fnInt': _fnInt,
  'fMin': _fExtremum(true),
  'fMax': _fExtremum(false),
  'solve': _solve,
  'summation Σ': _summation,
  'piecewise': _piecewise,

  // Lists
  'seq': _seqFn,
  'cumSum': _cumSum,
  'ΔList': _deltaList,
  'SortA': _sort(true),
  'SortD': _sort(false),
  'augment': _augment,
  'mean': _mean,
  'median': _median,
  'stdDev': _stdDev,
  'variance': _variance,
  'sum': _sumProd(true),
  'prod': _sumProd(false),
  'dim': _dim,
  'Fill': _fill,

  // Matrices
  'det': _det,
  'identity': _identity,
  'randM': _randM,
  'ref': _matUn((m) => m.ref()),
  'rref': _matUn((m) => m.rref()),
  'rowSwap': _rowOp((m, a, b, k) => m.swapRows(a, b)),
  'row+': _rowOp((m, a, b, k) => m.addRows(b, a)),
  '*row': _scaleRow,
  '*row+': _scaleRowAdd,

  // Distributions
  'normalpdf': _dist((a) =>
      Distributions.normalPdf(a.$1, a.$2 ?? 0, a.$3 ?? 1), 1, 3),
  'normalcdf': _dist((a) =>
      Distributions.normalCdf(a.$1, a.$2 ?? 1, a.$3 ?? 0, a.$4 ?? 1), 2, 4),
  'invNorm': _dist((a) =>
      Distributions.invNorm(a.$1, a.$2 ?? 0, a.$3 ?? 1), 1, 3),
  'invT': _dist((a) => Distributions.invT(a.$1, a.$2!), 2, 2),
  'tpdf': _dist((a) => Distributions.tPdf(a.$1, a.$2!), 2, 2),
  'tcdf': _dist((a) => Distributions.tCdf(a.$1, a.$2!, a.$3!), 3, 3),
  'χ²pdf': _dist((a) => Distributions.chi2Pdf(a.$1, a.$2!), 2, 2),
  'χ²cdf': _dist((a) => Distributions.chi2Cdf(a.$1, a.$2!, a.$3!), 3, 3),
  'Fpdf': _dist((a) => Distributions.fPdf(a.$1, a.$2!, a.$3!), 3, 3),
  'Fcdf': _dist(
      (a) => Distributions.fCdf(a.$1, a.$2!, a.$3!, a.$4!), 4, 4),
  'binompdf': _binomPdf,
  'binomcdf': _dist((a) =>
      Distributions.binomCdf(a.$1.round(), a.$2!, a.$3 ?? -1e99, a.$4 ?? 1e99), 2, 4),
  'poissonpdf': _dist(
      (a) => Distributions.poissonPdf(a.$1, a.$2!.round()), 2, 2),
  'poissoncdf': _dist((a) =>
      Distributions.poissonCdf(a.$1, a.$2 ?? -1e99, a.$3 ?? 1e99), 1, 3),
  'geometpdf': _dist(
      (a) => Distributions.geometPdf(a.$1, a.$2!.round()), 2, 2),
  'geometcdf': _dist((a) =>
      Distributions.geometCdf(a.$1, a.$2 ?? -1e99, a.$3 ?? 1e99), 1, 3),

  // Random
  'rand': _rand,
  'randInt': _randInt,
  'randNorm': _randNorm,
  'randBin': _randBin,
  'randIntNoRep': _randIntNoRep,

  // Complex
  'real': _cplx((c) => c.re),
  'imag': _cplx((c) => c.im),
  'conj': _conj,
  'angle': _angle,

  // Strings
  'expr': _expr,
  'sub': _sub,
  'inString': _inString,
  'length': _length,

  // Sequences u(n), v(n), w(n)
  'u': _seqVar('u'),
  'v': _seqVar('v'),
  'w': _seqVar('w'),

  // Equation calls Y1(x)
  'Y1': _eqCall('Y1'), 'Y2': _eqCall('Y2'), 'Y3': _eqCall('Y3'),
  'Y4': _eqCall('Y4'), 'Y5': _eqCall('Y5'), 'Y6': _eqCall('Y6'),
  'Y7': _eqCall('Y7'), 'Y8': _eqCall('Y8'), 'Y9': _eqCall('Y9'),
  'Y0': _eqCall('Y0'),

  // Dates
  'dayOfWk': _dayOfWk,
  'dbd': _dbd,

  'getTime': _getTime,
  'getDate': _getDate,
};

// ---- helpers -------------------------------------------------------------

List<Value> _args(Evaluator ev, List<Node> args, int min, int max) {
  if (args.length < min || args.length > max) {
    throw const CalcException('ARGUMENT');
  }
  return [for (final a in args) ev.eval(a)];
}

double _real(Evaluator ev, Node n) => ev.eval(n).asReal;

double _sinh(double x) => (math.exp(x) - math.exp(-x)) / 2;
double _cosh(double x) => (math.exp(x) + math.exp(-x)) / 2;
double _cbrt(double x) => x < 0 ? -math.pow(-x, 1 / 3).toDouble() : math.pow(x, 1 / 3).toDouble();

double _toRad(double x, CalcContext ctx) =>
    ctx.angleMode == AngleMode.degree ? x * math.pi / 180 : x;

double _fromRad(double x, CalcContext ctx) =>
    ctx.angleMode == AngleMode.degree ? x * 180 / math.pi : x;

_Fn _trig(double Function(double) f, Complex Function(Complex) cf) =>
    (ev, args) {
      _arity(args, 1);
      final v = ev.eval(args[0]);
      return _mapValue(ev, v, (x) => f(_toRad(x, ev.ctx)),
          (c) => cf(Complex(_toRad(c.re, ev.ctx), _toRad(c.im, ev.ctx))));
    };

_Fn _invTrig(double Function(double) f, Complex Function(Complex) cf) =>
    (ev, args) {
      _arity(args, 1);
      final v = ev.eval(args[0]);
      return _mapValue(ev, v, (x) {
        if (x < -1 || x > 1) {
          if (ev.ctx.complexMode == ComplexMode.aBi) {
            throw _NotReal();
          }
          throw const CalcException('DOMAIN');
        }
        return _fromRad(f(x), ev.ctx);
      }, (c) {
        final r = cf(c);
        return Complex(_fromRad(r.re, ev.ctx), _fromRad(r.im, ev.ctx));
      });
    };

class _NotReal implements Exception {}

Value _mapValue(Evaluator ev, Value v, double Function(double) f,
    [Complex Function(Complex)? cf]) {
  if (v is ListValue) {
    return ListValue([for (final i in v.items) _mapValue(ev, i, f, cf)]);
  }
  if (v is ComplexValue) {
    if (cf == null) throw const CalcException('DATA TYPE');
    return ComplexValue(cf(v.v));
  }
  if (v is RealValue) {
    try {
      return RealValue(f(v.v));
    } on _NotReal {
      if (cf == null) rethrow;
      if (ev.ctx.complexMode != ComplexMode.aBi) {
        throw const CalcException('NONREAL ANS');
      }
      return ComplexValue(cf(Complex(v.v, 0)));
    }
  }
  throw const CalcException('DATA TYPE');
}

void _arity(List<Node> args, int n) {
  if (args.length != n) throw const CalcException('ARGUMENT');
}

_Fn _plain(double Function(double) f) => (ev, args) {
      _arity(args, 1);
      return _mapValue(ev, ev.eval(args[0]), f);
    };

_Fn _both(double Function(double) f, Complex Function(Complex) cf) =>
    (ev, args) {
      _arity(args, 1);
      return _mapValue(ev, ev.eval(args[0]), f, cf);
    };

Value _sqrt(Evaluator ev, List<Node> args) {
  _arity(args, 1);
  final v = ev.eval(args[0]);
  return _mapValue(ev, v, (x) {
    if (x < 0) throw _NotReal();
    return math.sqrt(x);
  }, (c) => c.sqrt);
}

Value _ln(Evaluator ev, List<Node> args) {
  _arity(args, 1);
  final v = ev.eval(args[0]);
  return _mapValue(ev, v, (x) {
    if (x <= 0) {
      if (x < 0) throw _NotReal();
      throw const CalcException('DOMAIN');
    }
    return math.log(x);
  }, (c) => c.ln);
}

Value _log10(Evaluator ev, List<Node> args) {
  _arity(args, 1);
  final v = ev.eval(args[0]);
  return _mapValue(ev, v, (x) {
    if (x <= 0) {
      if (x < 0) throw _NotReal();
      throw const CalcException('DOMAIN');
    }
    return math.log(x) / math.ln10;
  }, (c) => c.ln / const Complex(math.ln10, 0));
}

Value _logBase(Evaluator ev, List<Node> args) {
  _arity(args, 2);
  final x = _real(ev, args[0]);
  final b = _real(ev, args[1]);
  if (x <= 0 || b <= 0 || b == 1) throw const CalcException('DOMAIN');
  return RealValue(math.log(x) / math.log(b));
}

Value _exp(Evaluator ev, List<Node> args) {
  _arity(args, 1);
  final v = ev.eval(args[0]);
  return _mapValue(ev, v, (x) => math.exp(x), (c) => c.exp);
}

Value _abs(Evaluator ev, List<Node> args) {
  _arity(args, 1);
  final v = ev.eval(args[0]);
  if (v is MatrixValue) return RealValue(v.m.determinant().abs());
  return _mapValue(ev, v, (x) => x.abs(), (c) => Complex(c.magnitude, 0));
}

Value _round(Evaluator ev, List<Node> args) {
  if (args.isEmpty || args.length > 2) {
    throw const CalcException('ARGUMENT');
  }
  final dec = args.length == 2 ? _real(ev, args[1]).round() : 0;
  final p = math.pow(10, dec.clamp(-9, 9)).toDouble();
  return _mapValue(ev, ev.eval(args[0]),
      (x) => (x * p).roundToDouble() / p);
}

_Fn _minMax(bool min) => (ev, args) {
      final vals = _args(ev, args, 1, 99);
      double choose(double a, double b) => min ? math.min(a, b) : math.max(a, b);
      if (vals.length == 1 && vals[0] is ListValue) {
        final items = (vals[0] as ListValue).items;
        if (items.isEmpty) throw const CalcException('DIM MISMATCH');
        var best = items[0].asReal;
        for (final i in items.skip(1)) {
          best = choose(best, i.asReal);
        }
        return RealValue(best);
      }
      if (vals.length == 2 &&
          (vals[0] is ListValue || vals[1] is ListValue)) {
        return _pairMinMax(vals, choose);
      }
      var best = vals[0].asReal;
      for (final v in vals.skip(1)) {
        best = choose(best, v.asReal);
      }
      return RealValue(best);
    };

Value _pairMinMax(List<Value> vals, double Function(double, double) f) {
  final a = vals[0];
  final b = vals[1];
  if (a is ListValue && b is ListValue) {
    if (a.items.length != b.items.length) {
      throw const CalcException('DIM MISMATCH');
    }
    return ListValue([
      for (var i = 0; i < a.items.length; i++)
        RealValue(f(a.items[i].asReal, b.items[i].asReal))
    ]);
  }
  if (a is ListValue) {
    return ListValue([
      for (final i in a.items) RealValue(f(i.asReal, b.asReal))
    ]);
  }
  if (b is ListValue) {
    return ListValue([
      for (final i in b.items) RealValue(f(a.asReal, i.asReal))
    ]);
  }
  return RealValue(f(a.asReal, b.asReal));
}

_Fn _gcdLcm(bool gcd) => (ev, args) {
      final vals = _args(ev, args, 2, 2);
      var a = vals[0].asReal.round().abs();
      var b = vals[1].asReal.round().abs();
      if (a == 0 && b == 0) throw const CalcException('DOMAIN');
      var x = a, y = b;
      while (y != 0) {
        final t = y;
        y = x % y;
        x = t;
      }
      final g = x;
      return RealValue((gcd ? g : (a ~/ g) * b).toDouble());
    };

Value _remainder(Evaluator ev, List<Node> args) {
  final vals = _args(ev, args, 2, 2);
  final b = vals[1].asReal;
  if (b == 0) throw const CalcException('DIVIDE BY 0');
  return RealValue(vals[0].asReal % b);
}

Value _not(Evaluator ev, List<Node> args) {
  _arity(args, 1);
  return RealValue(ev.eval(args[0]).asReal == 0 ? 1 : 0);
}

// ---- calculus -------------------------------------------------------------

/// Evaluate arg node with a variable bound to a value.
double _bind(Evaluator ev, Node expr, String varName, double x) {
  final saved = ev.ctx.vars[varName];
  ev.ctx.vars[varName] = x;
  try {
    return ev.eval(expr).asReal;
  } finally {
    if (saved == null) {
      ev.ctx.vars.remove(varName);
    } else {
      ev.ctx.vars[varName] = saved;
    }
  }
}

String _varOf(Node n) {
  if (n is NameNode && RegExp(r'^[A-Za-zθ]$').hasMatch(n.name)) {
    return n.name;
  }
  throw const CalcException('SYNTAX');
}

Value _nDeriv(Evaluator ev, List<Node> args) {
  if (args.length < 3 || args.length > 4) {
    throw const CalcException('ARGUMENT');
  }
  final varName = _varOf(args[1]);
  final at = _real(ev, args[2]);
  final h = args.length == 4 ? _real(ev, args[3]).abs() : 1e-4;
  return RealValue(
      Calculus.derivative((x) => _bind(ev, args[0], varName, x), at, h));
}

Value _fnInt(Evaluator ev, List<Node> args) {
  if (args.length < 4 || args.length > 5) {
    throw const CalcException('ARGUMENT');
  }
  final varName = _varOf(args[1]);
  final lo = _real(ev, args[2]);
  final hi = _real(ev, args[3]);
  final tol = args.length == 5 ? _real(ev, args[4]) : 1e-8;
  return RealValue(
      Calculus.integrate((x) => _bind(ev, args[0], varName, x), lo, hi, tol));
}

_Fn _fExtremum(bool min) => (ev, args) {
      if (args.length < 4 || args.length > 5) {
        throw const CalcException('ARGUMENT');
      }
      final varName = _varOf(args[1]);
      final lo = _real(ev, args[2]);
      final hi = _real(ev, args[3]);
      final tol = args.length == 5 ? _real(ev, args[4]) : 1e-7;
      double f(double x) => _bind(ev, args[0], varName, x);
      return RealValue(min
          ? Calculus.fMin(f, lo, hi, tol)
          : Calculus.fMax(f, lo, hi, tol));
    };

Value _solve(Evaluator ev, List<Node> args) {
  if (args.length < 3 || args.length > 4) {
    throw const CalcException('ARGUMENT');
  }
  final varName = _varOf(args[1]);
  final guess = _real(ev, args[2]);
  double lo = -1e99, hi = 1e99;
  if (args.length == 4) {
    final b = ev.eval(args[3]);
    if (b is ListValue && b.items.length == 2) {
      lo = b.items[0].asReal;
      hi = b.items[1].asReal;
    }
  }
  double f(double x) => _bind(ev, args[0], varName, x);
  final g = guess.abs() < 1 ? 1.0 : guess.abs();
  return RealValue(
      Calculus.solve(f, guess - 0.1 * g, guess + 0.1 * g)
          .clamp(lo, hi)
          .toDouble());
}

Value _summation(Evaluator ev, List<Node> args) {
  if (args.length != 4) throw const CalcException('ARGUMENT');
  final varName = _varOf(args[1]);
  final lo = _real(ev, args[2]).round();
  final hi = _real(ev, args[3]).round();
  var s = 0.0;
  for (var i = lo; i <= hi; i++) {
    s += _bind(ev, args[0], varName, i.toDouble());
  }
  return RealValue(s);
}

Value _piecewise(Evaluator ev, List<Node> args) {
  if (args.length < 2) throw const CalcException('ARGUMENT');
  var i = 0;
  Value? fallback;
  while (i < args.length) {
    if (i + 1 >= args.length) {
      fallback = ev.eval(args[i]);
      break;
    }
    if (ev.eval(args[i + 1]).asReal != 0) {
      return ev.eval(args[i]);
    }
    i += 2;
  }
  return fallback ?? (throw const CalcException('DOMAIN'));
}

// ---- lists ----------------------------------------------------------------

List<double> _listOf(Value v) {
  if (v is ListValue) {
    return [for (final i in v.items) i.asReal];
  }
  return [v.asReal];
}

Value _seqFn(Evaluator ev, List<Node> args) {
  if (args.length < 4 || args.length > 5) {
    throw const CalcException('ARGUMENT');
  }
  final varName = _varOf(args[1]);
  final lo = _real(ev, args[2]).round();
  final hi = _real(ev, args[3]).round();
  final step = args.length == 5 ? _real(ev, args[4]).round() : 1;
  if (step == 0) throw const CalcException('DOMAIN');
  final out = <Value>[];
  for (var i = lo; step > 0 ? i <= hi : i >= hi; i += step) {
    out.add(RealValue(_bind(ev, args[0], varName, i.toDouble())));
  }
  return ListValue(out);
}

Value _cumSum(Evaluator ev, List<Node> args) {
  _arity(args, 1);
  final l = _listOf(ev.eval(args[0]));
  var s = 0.0;
  return ListValue([for (final v in l) RealValue(s += v)]);
}

Value _deltaList(Evaluator ev, List<Node> args) {
  _arity(args, 1);
  final l = _listOf(ev.eval(args[0]));
  return ListValue([
    for (var i = 1; i < l.length; i++) RealValue(l[i] - l[i - 1])
  ]);
}

_Fn _sort(bool asc) => (ev, args) {
      if (args.isEmpty) throw const CalcException('ARGUMENT');
      final lists = <List<double>>[];
      final names = <String>[];
      for (final a in args) {
        if (a is NameNode && a.name.startsWith('L')) {
          names.add(a.name);
          lists.add(List.of(ev.ctx.list(a.name)));
        } else {
          lists.add(_listOf(ev.eval(a)));
          names.add('');
        }
      }
      final key = lists[0];
      final order = List.generate(key.length, (i) => i)
        ..sort((a, b) =>
            asc ? key[a].compareTo(key[b]) : key[b].compareTo(key[a]));
      final sorted = [
        for (final l in lists)
          [for (final i in order) l[i]]
      ];
      for (var i = 0; i < names.length; i++) {
        if (names[i].isNotEmpty) ev.ctx.lists[names[i]] = sorted[i];
      }
      return ListValue([for (final v in sorted[0]) RealValue(v)]);
    };

Value _augment(Evaluator ev, List<Node> args) {
  final vals = _args(ev, args, 2, 2);
  if (vals[0] is MatrixValue || vals[1] is MatrixValue) {
    if (vals[0] is! MatrixValue || vals[1] is! MatrixValue) {
      throw const CalcException('DATA TYPE');
    }
    final a = (vals[0] as MatrixValue).m;
    final b = (vals[1] as MatrixValue).m;
    if (a.rows != b.rows) throw const CalcException('DIM MISMATCH');
    return MatrixValue(Matrix.from([
      for (var r = 0; r < a.rows; r++) [...a.data[r], ...b.data[r]],
    ]));
  }
  return ListValue([
    for (final v in vals)
      ..._listOf(v).map(RealValue.new),
  ]);
}

List<double> _freqOf(Value? v) {
  if (v == null) return const [];
  return _listOf(v);
}

Value _mean(Evaluator ev, List<Node> args) {
  final vals = _args(ev, args, 1, 2);
  final data = _listOf(vals[0]);
  final freq = vals.length == 2 ? _freqOf(vals[1]) : const <double>[];
  return RealValue(_stats(data, freq).mean);
}

class _Stats {
  _Stats(this.mean, this.sumX, this.sumX2, this.n);
  final double mean;
  final double sumX;
  final double sumX2;
  final int n;

  double get s => n > 1 ? math.sqrt((sumX2 - sumX * sumX / n) / (n - 1)) : 0;
  double get sigma => n > 0 ? math.sqrt((sumX2 - sumX * sumX / n) / n) : 0;
  double get variance => s * s;
  double get popVariance => sigma * sigma;
}

_Stats _stats(List<double> data, List<double> freq) {
  if (data.isEmpty) throw const CalcException('DIM MISMATCH');
  var sx = 0.0, sx2 = 0.0, n = 0.0;
  for (var i = 0; i < data.length; i++) {
    final f = i < freq.length ? freq[i] : 1.0;
    sx += data[i] * f;
    sx2 += data[i] * data[i] * f;
    n += f;
  }
  if (n == 0) throw const CalcException('DIVIDE BY 0');
  return _Stats(sx / n, sx, sx2, n.round());
}

Value _median(Evaluator ev, List<Node> args) {
  final vals = _args(ev, args, 1, 2);
  final data = _listOf(vals[0]);
  final freq = vals.length == 2 ? _freqOf(vals[1]) : const <double>[];
  final expanded = <double>[];
  for (var i = 0; i < data.length; i++) {
    final f = i < freq.length ? freq[i].round() : 1;
    for (var k = 0; k < f; k++) {
      expanded.add(data[i]);
    }
  }
  expanded.sort();
  if (expanded.isEmpty) throw const CalcException('DIM MISMATCH');
  final m = expanded.length ~/ 2;
  return RealValue(expanded.length.isOdd
      ? expanded[m]
      : (expanded[m - 1] + expanded[m]) / 2);
}

Value _stdDev(Evaluator ev, List<Node> args) {
  final vals = _args(ev, args, 1, 2);
  return RealValue(
      _stats(_listOf(vals[0]), vals.length == 2 ? _freqOf(vals[1]) : const []).s);
}

Value _variance(Evaluator ev, List<Node> args) {
  final vals = _args(ev, args, 1, 2);
  return RealValue(_stats(
          _listOf(vals[0]), vals.length == 2 ? _freqOf(vals[1]) : const [])
      .variance);
}

_Fn _sumProd(bool sum) => (ev, args) {
      final vals = _args(ev, args, 1, 3);
      final l = _listOf(vals[0]);
      var lo = vals.length > 1 ? vals[1].asReal.round() : 1;
      var hi = vals.length > 2 ? vals[2].asReal.round() : l.length;
      lo = lo.clamp(1, l.length);
      hi = hi.clamp(1, l.length);
      var acc = sum ? 0.0 : 1.0;
      for (var i = lo - 1; i < hi; i++) {
        acc = sum ? acc + l[i] : acc * l[i];
      }
      return RealValue(acc);
    };

Value _dim(Evaluator ev, List<Node> args) {
  _arity(args, 1);
  final v = ev.eval(args[0]);
  if (v is ListValue) return RealValue(v.items.length.toDouble());
  if (v is MatrixValue) {
    return ListValue([
      RealValue(v.m.rows.toDouble()),
      RealValue(v.m.cols.toDouble()),
    ]);
  }
  if (v is StringValue) return RealValue(v.v.length.toDouble());
  throw const CalcException('DATA TYPE');
}

Value _fill(Evaluator ev, List<Node> args) {
  _arity(args, 2);
  final v = _real(ev, args[0]);
  final target = args[1];
  if (target is NameNode) {
    if (target.name.startsWith('L')) {
      final l = ev.ctx.list(target.name);
      for (var i = 0; i < l.length; i++) {
        l[i] = v;
      }
      return const StringValue('Done');
    }
    if (target.name.startsWith('[')) {
      final m = ev.ctx.matrix(target.name);
      if (m == null) throw const CalcException('UNDEFINED');
      for (var r = 0; r < m.rows; r++) {
        for (var c = 0; c < m.cols; c++) {
          m.data[r][c] = v;
        }
      }
      return const StringValue('Done');
    }
  }
  throw const CalcException('DATA TYPE');
}

// ---- matrices --------------------------------------------------------------

Value _det(Evaluator ev, List<Node> args) {
  _arity(args, 1);
  final v = ev.eval(args[0]);
  if (v is! MatrixValue) throw const CalcException('DATA TYPE');
  return RealValue(v.m.determinant());
}

Value _identity(Evaluator ev, List<Node> args) {
  _arity(args, 1);
  final n = _real(ev, args[0]).round();
  if (n < 1 || n > 99) throw const CalcException('DIM MISMATCH');
  return MatrixValue(Matrix.identity(n));
}

Value _randM(Evaluator ev, List<Node> args) {
  _arity(args, 2);
  final r = _real(ev, args[0]).round();
  final c = _real(ev, args[1]).round();
  final m = Matrix(r, c);
  for (var i = 0; i < r; i++) {
    for (var j = 0; j < c; j++) {
      m.data[i][j] = ev.ctx.random.nextInt(19) - 9.0;
    }
  }
  return MatrixValue(m);
}

_Fn _matUn(Matrix Function(Matrix) f) => (ev, args) {
      _arity(args, 1);
      final v = ev.eval(args[0]);
      if (v is! MatrixValue) throw const CalcException('DATA TYPE');
      return MatrixValue(f(v.m));
    };

Matrix _matArg(Evaluator ev, Node n) {
  final v = ev.eval(n);
  if (v is! MatrixValue) throw const CalcException('DATA TYPE');
  return v.m.copy();
}

_Fn _rowOp(void Function(Matrix, int, int, double) f) => (ev, args) {
      _arity(args, 3);
      final m = _matArg(ev, args[0]);
      final a = _real(ev, args[1]).round() - 1;
      final b = _real(ev, args[2]).round() - 1;
      if (a < 0 || b < 0 || a >= m.rows || b >= m.rows) {
        throw const CalcException('DIM MISMATCH');
      }
      f(m, a, b, 0);
      return MatrixValue(m);
    };

Value _scaleRow(Evaluator ev, List<Node> args) {
  _arity(args, 3);
  final k = _real(ev, args[0]);
  final m = _matArg(ev, args[1]);
  final r = _real(ev, args[2]).round() - 1;
  if (r < 0 || r >= m.rows) throw const CalcException('DIM MISMATCH');
  m.scaleRow(r, k);
  return MatrixValue(m);
}

Value _scaleRowAdd(Evaluator ev, List<Node> args) {
  _arity(args, 4);
  final k = _real(ev, args[0]);
  final m = _matArg(ev, args[1]);
  final a = _real(ev, args[2]).round() - 1;
  final b = _real(ev, args[3]).round() - 1;
  if (a < 0 || b < 0 || a >= m.rows || b >= m.rows) {
    throw const CalcException('DIM MISMATCH');
  }
  m.addScaledRowK(b, k, a);
  return MatrixValue(m);
}

// ---- distributions ----------------------------------------------------------

typedef _DistArgs = (double, double?, double?, double?);

_Fn _dist(double Function(_DistArgs) f, int min, int max) => (ev, args) {
      if (args.length < min || args.length > max) {
        throw const CalcException('ARGUMENT');
      }
      final vals = [for (final a in args) ev.eval(a).asReal];
      return RealValue(f((
        vals[0],
        vals.length > 1 ? vals[1] : null,
        vals.length > 2 ? vals[2] : null,
        vals.length > 3 ? vals[3] : null,
      )));
    };

Value _binomPdf(Evaluator ev, List<Node> args) {
  if (args.length < 2 || args.length > 3) {
    throw const CalcException('ARGUMENT');
  }
  final n = _real(ev, args[0]).round();
  final p = _real(ev, args[1]);
  final k = args.length == 3 ? _real(ev, args[2]).round() : null;
  return RealValue(Distributions.binomPdf(n, p, k));
}

// ---- random -----------------------------------------------------------------

Value _rand(Evaluator ev, List<Node> args) {
  if (args.isEmpty) return RealValue(ev.ctx.random.nextDouble());
  _arity(args, 1);
  final n = _real(ev, args[0]).round();
  return ListValue(
      [for (var i = 0; i < n; i++) RealValue(ev.ctx.random.nextDouble())]);
}

Value _randInt(Evaluator ev, List<Node> args) {
  if (args.length < 2 || args.length > 3) {
    throw const CalcException('ARGUMENT');
  }
  final lo = _real(ev, args[0]).round();
  final hi = _real(ev, args[1]).round();
  if (hi < lo) throw const CalcException('DOMAIN');
  final n = args.length == 3 ? _real(ev, args[2]).round() : 1;
  Value one() =>
      RealValue((lo + ev.ctx.random.nextInt(hi - lo + 1)).toDouble());
  if (n == 1) return one();
  return ListValue([for (var i = 0; i < n; i++) one()]);
}

Value _randNorm(Evaluator ev, List<Node> args) {
  if (args.length < 2 || args.length > 3) {
    throw const CalcException('ARGUMENT');
  }
  final mu = _real(ev, args[0]);
  final sigma = _real(ev, args[1]);
  final n = args.length == 3 ? _real(ev, args[2]).round() : 1;
  double one() {
    final u1 = ev.ctx.random.nextDouble().clamp(1e-12, 1.0);
    final u2 = ev.ctx.random.nextDouble();
    return mu + sigma * math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2);
  }
  if (n == 1) return RealValue(one());
  return ListValue([for (var i = 0; i < n; i++) RealValue(one())]);
}

Value _randBin(Evaluator ev, List<Node> args) {
  if (args.length < 2 || args.length > 3) {
    throw const CalcException('ARGUMENT');
  }
  final n = _real(ev, args[0]).round();
  final p = _real(ev, args[1]);
  final count = args.length == 3 ? _real(ev, args[2]).round() : 1;
  double one() {
    var s = 0;
    for (var i = 0; i < n; i++) {
      if (ev.ctx.random.nextDouble() < p) s++;
    }
    return s.toDouble();
  }
  if (count == 1) return RealValue(one());
  return ListValue([for (var i = 0; i < count; i++) RealValue(one())]);
}

Value _randIntNoRep(Evaluator ev, List<Node> args) {
  if (args.length < 2 || args.length > 3) {
    throw const CalcException('ARGUMENT');
  }
  final lo = _real(ev, args[0]).round();
  final hi = _real(ev, args[1]).round();
  final range = hi - lo + 1;
  final n = args.length == 3 ? _real(ev, args[2]).round() : range;
  if (range <= 0 || n > range) throw const CalcException('DOMAIN');
  final pool = [for (var i = lo; i <= hi; i++) i]..shuffle(ev.ctx.random);
  return ListValue(
      [for (var i = 0; i < n; i++) RealValue(pool[i].toDouble())]);
}

// ---- complex ------------------------------------------------------------------

_Fn _cplx(double Function(Complex) f) => (ev, args) {
      _arity(args, 1);
      final v = ev.eval(args[0]);
      return _mapValue(ev, v, (x) => f(Complex(x, 0)),
          (c) => Complex(f(c), 0));
    };

Value _conj(Evaluator ev, List<Node> args) {
  _arity(args, 1);
  final v = ev.eval(args[0]);
  return _mapValue(ev, v, (x) => x, (c) => c.conjugate);
}

Value _angle(Evaluator ev, List<Node> args) {
  _arity(args, 1);
  final v = ev.eval(args[0]);
  return _mapValue(ev, v, (x) => 0.0,
      (c) => Complex(_fromRad(c.argument, ev.ctx), 0));
}

// ---- strings -------------------------------------------------------------------

Value _expr(Evaluator ev, List<Node> args) {
  _arity(args, 1);
  final v = ev.eval(args[0]);
  if (v is! StringValue) throw const CalcException('DATA TYPE');
  return evaluateInline(v.v, ev.ctx);
}

Value _sub(Evaluator ev, List<Node> args) {
  _arity(args, 3);
  final s = ev.eval(args[0]);
  if (s is! StringValue) throw const CalcException('DATA TYPE');
  final start = _real(ev, args[1]).round();
  final len = _real(ev, args[2]).round();
  if (start < 1 || start - 1 + len > s.v.length || len < 0) {
    throw const CalcException('DOMAIN');
  }
  return StringValue(s.v.substring(start - 1, start - 1 + len));
}

Value _inString(Evaluator ev, List<Node> args) {
  if (args.length < 2 || args.length > 3) {
    throw const CalcException('ARGUMENT');
  }
  final h = ev.eval(args[0]);
  final n = ev.eval(args[1]);
  if (h is! StringValue || n is! StringValue) {
    throw const CalcException('DATA TYPE');
  }
  final start = args.length == 3 ? _real(ev, args[2]).round() - 1 : 0;
  final idx = h.v.indexOf(n.v, start.clamp(0, h.v.length));
  return RealValue((idx < 0 ? 0 : idx + 1).toDouble());
}

Value _length(Evaluator ev, List<Node> args) {
  _arity(args, 1);
  final v = ev.eval(args[0]);
  if (v is! StringValue) throw const CalcException('DATA TYPE');
  return RealValue(v.v.length.toDouble());
}

// ---- sequences -------------------------------------------------------------------

_Fn _seqVar(String name) => (ev, args) {
      _arity(args, 1);
      final n = _real(ev, args[0]).round();
      return RealValue(ev.ctx.sequenceAt(name, n));
    };

// ---- equations --------------------------------------------------------------------

_Fn _eqCall(String name) => (ev, args) {
      _arity(args, 1);
      final eq = ev.ctx.equations[name];
      if (eq == null || !eq.isDefined) {
        throw const CalcException('UNDEFINED');
      }
      final x = _real(ev, args[0]);
      final saved = ev.ctx.vars['X'];
      ev.ctx.vars['X'] = x;
      try {
        return evaluateInline(eq.expression, ev.ctx);
      } finally {
        if (saved == null) {
          ev.ctx.vars.remove('X');
        } else {
          ev.ctx.vars['X'] = saved;
        }
      }
    };

// ---- dates ---------------------------------------------------------------------------

Value _dayOfWk(Evaluator ev, List<Node> args) {
  _arity(args, 3);
  final y = _real(ev, args[0]).round();
  final m = _real(ev, args[1]).round();
  final d = _real(ev, args[2]).round();
  final dt = DateTime(y, m, d);
  return RealValue(((dt.weekday) % 7 + 1).toDouble());
}

Value _dbd(Evaluator ev, List<Node> args) {
  _arity(args, 2);
  final a = _parseDate(ev.eval(args[0]).asReal);
  final b = _parseDate(ev.eval(args[1]).asReal);
  return RealValue(b.difference(a).inDays.toDouble());
}

/// TI date numbers are mm.ddyy with a 1950-2049 year window.
DateTime _parseDate(double v) {
  final s = v.toStringAsFixed(4);
  final parts = s.split('.');
  final m = int.parse(parts[0]);
  final ddyy = parts[1].padRight(4, '0');
  final d = int.parse(ddyy.substring(0, 2));
  final yy = int.parse(ddyy.substring(2));
  return DateTime(yy <= 49 ? 2000 + yy : 1900 + yy, m, d);
}

Value _getTime(Evaluator ev, List<Node> args) {
  _arity(args, 0);
  final now = DateTime.now();
  return ListValue([
    RealValue(now.hour.toDouble()),
    RealValue(now.minute.toDouble()),
    RealValue(now.second.toDouble()),
  ]);
}

Value _getDate(Evaluator ev, List<Node> args) {
  _arity(args, 0);
  final now = DateTime.now();
  return ListValue([
    RealValue(now.year.toDouble()),
    RealValue(now.month.toDouble()),
    RealValue(now.day.toDouble()),
  ]);
}
