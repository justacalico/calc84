import 'dart:math' as math;

import 'value.dart';

/// Numeric derivative, integral, extrema and root finding used by
/// nDeriv(, fnInt(, fMin(, fMax(, solve( and the CALC graph menu.
class Calculus {
  static double derivative(double Function(double) f, double x,
      [double h = 1e-4]) {
    return (f(x + h) - f(x - h)) / (2 * h);
  }

  /// Simpson integration with adaptive refinement.
  static double integrate(double Function(double) f, double a, double b,
      [double tol = 1e-8]) {
    if (a == b) return 0;
    if (a > b) return -integrate(f, b, a, tol);
    var n = 64;
    var prev = _simpson(f, a, b, 16);
    for (var i = 0; i < 8; i++) {
      final cur = _simpson(f, a, b, n);
      if ((cur - prev).abs() < tol) return cur;
      prev = cur;
      n *= 2;
    }
    return prev;
  }

  static double _simpson(double Function(double) f, double a, double b, int n) {
    final h = (b - a) / n;
    var s = f(a) + f(b);
    for (var i = 1; i < n; i++) {
      s += (i.isOdd ? 4 : 2) * f(a + i * h);
    }
    return s * h / 3;
  }

  /// Golden section search for a minimum on [lo, hi].
  static double fMin(double Function(double) f, double lo, double hi,
      [double tol = 1e-7]) {
    return _golden(f, lo, hi, tol, true);
  }

  static double fMax(double Function(double) f, double lo, double hi,
      [double tol = 1e-7]) {
    return _golden(f, lo, hi, tol, false);
  }

  static double _golden(
      double Function(double) f, double a, double b, double tol, bool min) {
    const gr = 0.6180339887498949;
    var c = b - gr * (b - a);
    var d = a + gr * (b - a);
    double score(double x) => min ? f(x) : -f(x);
    while ((d - c).abs() > tol) {
      if (score(c) < score(d)) {
        b = d;
      } else {
        a = c;
      }
      c = b - gr * (b - a);
      d = a + gr * (b - a);
    }
    return (a + b) / 2;
  }

  /// Brent's method root find on [a, b].
  static double solve(double Function(double) f, double a, double b,
      [double tol = 1e-12]) {
    var fa = f(a);
    var fb = f(b);
    if (fa == 0) return a;
    if (fb == 0) return b;
    if (fa * fb > 0) {
      // Widen the bracket a few times before giving up.
      var lo = a;
      var hi = b;
      for (var i = 0; i < 60; i++) {
        lo -= (b - a) * (i + 1);
        hi += (b - a) * (i + 1);
        fa = f(lo);
        fb = f(hi);
        if (fa * fb <= 0) {
          a = lo;
          b = hi;
          break;
        }
      }
      if (f(a) * f(b) > 0) {
        // Fall back to a scan for a sign change.
        final root = _scan(f, a - 50 * (b - a).abs().clamp(1, 100),
            b + 50 * (b - a).abs().clamp(1, 100));
        if (root != null) return root;
        throw const CalcException('NO SIGN CHNG');
      }
      fa = f(a);
      fb = f(b);
    }
    var c = a;
    var fc = fa;
    var d = b - a;
    var e = d;
    for (var i = 0; i < 200; i++) {
      if (fb * fc > 0) {
        c = a;
        fc = fa;
        d = b - a;
        e = d;
      }
      if (fc.abs() < fb.abs()) {
        a = b;
        b = c;
        c = a;
        fa = fb;
        fb = fc;
        fc = fa;
      }
      final tol1 = 2 * 1e-15 * b.abs() + 0.5 * tol;
      final m = 0.5 * (c - b);
      if (m.abs() <= tol1 || fb == 0) return b;
      if (e.abs() >= tol1 && fa.abs() > fb.abs()) {
        var s = fb / fa;
        double p, q;
        if (a == c) {
          p = 2 * m * s;
          q = 1 - s;
        } else {
          q = fa / fc;
          final r = fb / fc;
          p = s * (2 * m * q * (q - r) - (b - a) * (r - 1));
          q = (q - 1) * (r - 1) * (s - 1);
        }
        if (p > 0) q = -q;
        p = p.abs();
        if (2 * p < math.min(3 * m * q - (tol1 * q).abs(), (e * q).abs())) {
          e = d;
          d = p / q;
        } else {
          d = m;
          e = m;
        }
      } else {
        d = m;
        e = m;
      }
      a = b;
      fa = fb;
      b += d.abs() > tol1 ? d : (m > 0 ? tol1 : -tol1);
      fb = f(b);
    }
    return b;
  }

  static double? _scan(double Function(double) f, double lo, double hi) {
    const steps = 2000;
    var px = lo;
    var py = f(px);
    for (var i = 1; i <= steps; i++) {
      final x = lo + (hi - lo) * i / steps;
      final y = f(x);
      if (y.isFinite && py.isFinite && y * py <= 0) {
        return solve(f, px, x);
      }
      px = x;
      py = y;
    }
    return null;
  }
}
