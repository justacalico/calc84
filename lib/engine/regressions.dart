import 'dart:math' as math;

import 'matrix.dart';
import 'value.dart';

/// Result of a regression or stats calculation, as ordered
/// label/value pairs rendered on the home screen.
class RegressionResult {
  RegressionResult(this.name, this.fields,
      {this.equation, this.equationBuilder});

  final String name;
  final List<(String, double)> fields;

  /// Equation text like "aX+b" description for storing into Yn.
  final String Function(Map<String, double> coefficients)? equationBuilder;

  final String? equation;

  Map<String, double> get coefficients =>
      {for (final f in fields) f.$1: f.$2};
}

/// Statistics calculations for the STAT CALC menu.
class Regressions {
  /// 1-Var Stats.
  static RegressionResult oneVar(List<double> x, [List<double>? freq]) {
    if (x.isEmpty) throw const CalcException('DIM MISMATCH');
    final f = freq ?? List.filled(x.length, 1.0);
    var n = 0.0, sx = 0.0, sx2 = 0.0;
    final expanded = <double>[];
    for (var i = 0; i < x.length; i++) {
      final w = i < f.length ? f[i] : 1.0;
      n += w;
      sx += x[i] * w;
      sx2 += x[i] * x[i] * w;
      for (var k = 0; k < w.round(); k++) {
        expanded.add(x[i]);
      }
    }
    expanded.sort();
    final mean = sx / n;
    final sampleVar = n > 1 ? (sx2 - sx * sx / n) / (n - 1) : 0.0;
    final popVar = n > 0 ? (sx2 - sx * sx / n) / n : 0.0;
    return RegressionResult('1-Var Stats', [
      ('x̄', mean),
      ('Σx', sx),
      ('Σx²', sx2),
      ('Sx', math.sqrt(sampleVar)),
      ('σx', math.sqrt(popVar)),
      ('n', n),
      ('minX', expanded.first),
      ('Q1', _quartile(expanded, 0.25)),
      ('Med', _quartile(expanded, 0.5)),
      ('Q3', _quartile(expanded, 0.75)),
      ('maxX', expanded.last),
    ]);
  }

  /// 2-Var Stats.
  static RegressionResult twoVar(List<double> x, List<double> y) {
    if (x.length != y.length || x.isEmpty) {
      throw const CalcException('DIM MISMATCH');
    }
    var n = 0.0, sx = 0.0, sy = 0.0, sx2 = 0.0, sy2 = 0.0, sxy = 0.0;
    for (var i = 0; i < x.length; i++) {
      n++;
      sx += x[i];
      sy += y[i];
      sx2 += x[i] * x[i];
      sy2 += y[i] * y[i];
      sxy += x[i] * y[i];
    }
    double sd(double s2, double s, bool sample) =>
        math.sqrt(((s2 - s * s / n) / (sample ? n - 1 : n)).clamp(0, 1e300));
    return RegressionResult('2-Var Stats', [
      ('x̄', sx / n),
      ('Σx', sx),
      ('Σx²', sx2),
      ('Sx', sd(sx2, sx, true)),
      ('σx', sd(sx2, sx, false)),
      ('ȳ', sy / n),
      ('Σy', sy),
      ('Σy²', sy2),
      ('Sy', sd(sy2, sy, true)),
      ('σy', sd(sy2, sy, false)),
      ('Σxy', sxy),
      ('n', n),
    ]);
  }

  static double _quartile(List<double> sorted, double q) {
    final pos = (sorted.length - 1) * q;
    final lo = pos.floor();
    final hi = pos.ceil();
    if (lo == hi) return sorted[lo];
    return sorted[lo] + (sorted[hi] - sorted[lo]) * (pos - lo);
  }

  /// Median-median line.
  static RegressionResult medMed(List<double> x, List<double> y) {
    _checkPair(x, y);
    final groups = _threeGroups(x, y);
    final pts = <(double, double)>[];
    for (final g in groups) {
      if (g.isEmpty) {
        pts.add((x.first, y.first));
        continue;
      }
      final xs = g.map((e) => e.$1).toList()..sort();
      final ys = g.map((e) => e.$2).toList()..sort();
      pts.add((_medianOf(xs), _medianOf(ys)));
    }
    final slope = (pts[2].$2 - pts[0].$2) / (pts[2].$1 - pts[0].$1);
    final b = (pts[0].$2 + pts[1].$2 + pts[2].$2 -
            slope * (pts[0].$1 + pts[1].$1 + pts[2].$1)) /
        3;
    return RegressionResult('Med-Med', [('a', slope), ('b', b)],
        equationBuilder: (c) => '${c['a']}X+${c['b']}');
  }

  static List<List<(double, double)>> _threeGroups(
      List<double> x, List<double> y) {
    final pairs = [
      for (var i = 0; i < x.length; i++) (x[i], y[i])
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    final n = pairs.length;
    final g1 = pairs.sublist(0, n ~/ 3);
    final g3 = pairs.sublist(n - n ~/ 3);
    final g2 = pairs.sublist(n ~/ 3, n - n ~/ 3);
    return [g1, g2, g3];
  }

  static double _medianOf(List<double> s) {
    final m = s.length ~/ 2;
    return s.length.isOdd ? s[m] : (s[m - 1] + s[m]) / 2;
  }

  static void _checkPair(List<double> x, List<double> y) {
    if (x.length != y.length || x.length < 2) {
      throw const CalcException('DIM MISMATCH');
    }
  }

  /// Polynomial regression of the given degree (1=linear, 2=quad,
  /// 3=cubic, 4=quartic).
  static RegressionResult poly(List<double> x, List<double> y, int degree,
      {String name = 'LinReg'}) {
    _checkPair(x, y);
    final n = degree + 1;
    final a = Matrix(n, n);
    final b = Matrix(n, 1);
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        var s = 0.0;
        for (var i = 0; i < x.length; i++) {
          s += math.pow(x[i], r + c);
        }
        a.data[r][c] = s;
      }
      var s = 0.0;
      for (var i = 0; i < x.length; i++) {
        s += y[i] * math.pow(x[i], r);
      }
      b.data[r][0] = s;
    }
    final coeff = a.inverse().multiply(b);
    // coeff[0] is the constant; flip so fields read a,b,c...
    final fields = <(String, double)>[
      for (var i = n - 1; i >= 0; i--)
        (String.fromCharCode(97 + (n - 1 - i)), coeff.data[i][0]),
    ];
    final result = RegressionResult(name, fields);
    if (degree <= 2) {
      final r = _correlation(x, y);
      result.fields.add(('r²', degree == 2 ? _r2(x, y, coeff) : r * r));
      if (degree == 1) result.fields.add(('r', r));
    }
    return result;
  }

  static double _r2(List<double> x, List<double> y, Matrix coeff) {
    final mean = y.reduce((a, b) => a + b) / y.length;
    var ssRes = 0.0, ssTot = 0.0;
    for (var i = 0; i < x.length; i++) {
      var pred = 0.0;
      for (var p = 0; p < coeff.rows; p++) {
        pred += coeff.data[p][0] * math.pow(x[i], p);
      }
      ssRes += math.pow(y[i] - pred, 2);
      ssTot += math.pow(y[i] - mean, 2);
    }
    return ssTot == 0 ? 1 : 1 - ssRes / ssTot;
  }

  static double _correlation(List<double> x, List<double> y) {
    final n = x.length;
    final mx = x.reduce((a, b) => a + b) / n;
    final my = y.reduce((a, b) => a + b) / n;
    var sxy = 0.0, sx2 = 0.0, sy2 = 0.0;
    for (var i = 0; i < n; i++) {
      sxy += (x[i] - mx) * (y[i] - my);
      sx2 += (x[i] - mx) * (x[i] - mx);
      sy2 += (y[i] - my) * (y[i] - my);
    }
    if (sx2 == 0 || sy2 == 0) return 0;
    return sxy / math.sqrt(sx2 * sy2);
  }

  /// ln(x) transform regression: y = a + b ln x.
  static RegressionResult lnReg(List<double> x, List<double> y) {
    if (x.any((v) => v <= 0)) throw const CalcException('DOMAIN');
    final lx = [for (final v in x) math.log(v)];
    final r = poly(lx, y, 1, name: 'LnReg');
    final rr = _correlation(lx, y);
    r.fields.add(('r²', rr * rr));
    r.fields.add(('r', rr));
    return r;
  }

  /// y = a*b^x.
  static RegressionResult expReg(List<double> x, List<double> y) {
    if (y.any((v) => v <= 0)) throw const CalcException('DOMAIN');
    final ly = [for (final v in y) math.log(v)];
    final r = poly(x, ly, 1, name: 'ExpReg');
    final a = math.exp(r.fields[1].$2);
    final b = math.exp(r.fields[0].$2);
    final rr = _correlation(x, ly);
    return RegressionResult('ExpReg', [
      ('a', a),
      ('b', b),
      ('r²', rr * rr),
      ('r', rr),
    ]);
  }

  /// y = a*x^b.
  static RegressionResult pwrReg(List<double> x, List<double> y) {
    if (x.any((v) => v <= 0) || y.any((v) => v <= 0)) {
      throw const CalcException('DOMAIN');
    }
    final lx = [for (final v in x) math.log(v)];
    final ly = [for (final v in y) math.log(v)];
    final r = poly(lx, ly, 1, name: 'PwrReg');
    final a = math.exp(r.fields[1].$2);
    final b = r.fields[0].$2;
    final rr = _correlation(lx, ly);
    return RegressionResult('PwrReg', [
      ('a', a),
      ('b', b),
      ('r²', rr * rr),
      ('r', rr),
    ]);
  }
}
