import 'dart:math' as math;

import 'complex.dart';
import 'fraction.dart';
import 'value.dart';

/// How results are printed.
enum Notation { normal, sci, eng }

/// float or fixed decimals 0-9.
class DisplaySettings {
  Notation notation = Notation.normal;

  /// -1 means Float, 0-9 fixed decimals.
  int decimals = -1;
}

/// Result of rendering a value: one or more lines of text.
class FormattedResult {
  FormattedResult(this.lines, {this.matrixGrid});

  final List<String> lines;

  /// For matrix results: rows of cell strings to lay out in a grid.
  final List<List<String>>? matrixGrid;
}

class Formatter {
  Formatter(this.settings);

  final DisplaySettings settings;

  FormattedResult format(Value v, {String? hint}) {
    if (v is StringValue) return FormattedResult(['"${v.v}"']);
    if (v is ListValue) {
      return FormattedResult(_listLines(v, hint));
    }
    if (v is MatrixValue) {
      return FormattedResult(
        _matrixLines(v),
        matrixGrid: [
          for (final row in v.m.data)
            [for (final c in row) num(c, hint: hint)]
        ],
      );
    }
    if (v is ComplexValue) {
      return FormattedResult([_complexText(v.v, hint)]);
    }
    return FormattedResult([num((v as RealValue).v, hint: hint)]);
  }

  List<String> _listLines(ListValue v, String? hint) {
    final cells = [for (final i in v.items) _cellText(i, hint)];
    return ['{${cells.join(' ')}}'];
  }

  List<String> _matrixLines(MatrixValue v) {
    return [
      for (final row in v.m.data)
        '[ ${row.map((c) => num(c)).join(' ')} ]'
    ];
  }

  String _cellText(Value v, String? hint) {
    if (v is ComplexValue) return _complexText(v.v, hint);
    if (v is StringValue) return '"${v.v}"';
    return num((v as RealValue).v, hint: hint);
  }

  String _complexText(Complex c, String? hint) {
    if (hint == '▸Polar') {
      return '${num(c.magnitude)}e^(${num(c.argument)}i)';
    }
    final im = num(c.im.abs());
    if (c.im == 0) return num(c.re, hint: hint);
    final sign = c.im < 0 ? '-' : '+';
    if (c.re == 0) return '${c.im < 0 ? '-' : ''}${im}i';
    return '${num(c.re)}$sign${im}i';
  }

  /// Classic display: up to 10 significant digits in Float mode,
  /// trailing zeros trimmed, falls back to E notation when the
  /// number will not fit.
  String num(double v, {String? hint}) {
    if (hint == '▸Frac' || hint == '▸n/d' || hint == '▸Un/d') {
      final f = Fraction.approximate(v);
      if (f != null) {
        if (hint == '▸Un/d' && f.n.abs() > f.d) {
          final whole = f.n ~/ f.d;
          final rem = f.n.abs() % f.d;
          if (rem == 0) return '$whole';
          return '$whole◂$rem/${f.d}';
        }
        return f.toString();
      }
    }
    if (hint == '▸DMS') return dms(v);
    if (v.isNaN) return 'NaN';
    if (v.isInfinite) return v > 0 ? '∞' : '-∞';
    if (v == 0) return '0';

    switch (settings.notation) {
      case Notation.sci:
        return _sci(v);
      case Notation.eng:
        return _eng(v);
      case Notation.normal:
        break;
    }

    final av = v.abs();
    if (av >= 1e10 || av < 1e-4) return _sci(v);

    if (settings.decimals >= 0) {
      final s = v.toStringAsFixed(settings.decimals);
      if (s.length <= 12) return s;
      return _sci(v);
    }

    // Float: 10 significant digits, trim trailing zeros.
    var s = _sigDigits(v, 10);
    if (s.contains('E')) return s;
    s = _trim(s);
    if (s.length > 12) return _sci(v);
    return s;
  }

  String _sigDigits(double v, int digits) {
    final s = v.toStringAsPrecision(digits);
    if (s.contains('e')) return _toENotation(v, digits);
    return s;
  }

  String _toENotation(double v, int digits) {
    final e = v.exponent();
    final m = v / math.pow(10, e);
    var ms = m.toStringAsFixed(digits - 1);
    if (double.parse(ms).abs() >= 10) {
      return _toENotation(v / 10, digits).replaceFirstMapped(
          RegExp(r'E(-?\d+)'), (m0) => 'E${int.parse(m0.group(1)!) + 1}');
    }
    ms = _trim(ms);
    return '${ms}E$e';
  }

  String _sci(double v) {
    final digits = settings.decimals >= 0 ? settings.decimals + 1 : 10;
    return _toENotation(v, digits.clamp(1, 10));
  }

  String _eng(double v) {
    if (v == 0) return '0';
    var e = v.exponent();
    e -= e % 3;
    var m = v / math.pow(10, e);
    final digits = settings.decimals >= 0 ? settings.decimals + 1 : 10;
    var ms = m.toStringAsFixed((digits - 1).clamp(0, 9));
    if (double.parse(ms).abs() >= 1000) {
      e += 3;
      m /= 1000;
      ms = m.toStringAsFixed((digits - 1).clamp(0, 9));
    }
    return '${_trim(ms)}E$e';
  }

  String _trim(String s) {
    if (s.contains('.')) {
      s = s.replaceAll(RegExp('0+\$'), '');
      if (s.endsWith('.')) s = s.substring(0, s.length - 1);
    }
    if (s == '-0') s = '0';
    return s;
  }

  /// Degrees to DMS like ▸DMS: 12°30′15″
  String dms(double v) {
    final sign = v < 0 ? '-' : '';
    final av = v.abs();
    final d = av.floor();
    final mFull = (av - d) * 60;
    var m = mFull.floor();
    var s = (mFull - m) * 60;
    s = (s * 100).roundToDouble() / 100;
    if (s >= 60) {
      s = 0;
      m += 1;
    }
    final ss = _trim(s.toStringAsFixed(2));
    if (m == 0 && s == 0) return '$sign$d°';
    if (s == 0) return '$sign$d°$m′';
    return '$sign$d°$m′$ss″';
  }
}

extension on double {
  int exponent() => this == 0 ? 0 : (log10(abs())).floor();

  double log10(num x) => math.log(x) / math.ln10;
}
