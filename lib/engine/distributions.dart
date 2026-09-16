import 'dart:math' as math;

import 'value.dart';

/// Probability density, cumulative and inverse functions for the
/// DISTR menu.
class Distributions {
  static double _logGamma(double x) {
    const p = [
      0.99999999999980993, 676.5203681218851, -1259.1392167224028,
      771.32342877765313, -176.61502916214059, 12.507343278686905,
      -0.13857109526572012, 9.9843695780195716e-6, 1.5056327351493116e-7,
    ];
    if (x < 0.5) {
      return math.log(math.pi) -
          math.log(math.sin(math.pi * x)) -
          _logGamma(1 - x);
    }
    x -= 1;
    var a = p[0];
    for (var i = 1; i < p.length; i++) {
      a += p[i] / (x + i);
    }
    final t = x + p.length - 1.5;
    return 0.5 * math.log(2 * math.pi) +
        (x + 0.5) * math.log(t) -
        t +
        math.log(a);
  }

  /// Regularized lower incomplete gamma P(a, x).
  static double gammaP(double a, double x) {
    if (x <= 0) return 0;
    if (x < a + 1) {
      var sum = 1 / a;
      var term = sum;
      for (var n = 1; n < 200; n++) {
        term *= x / (a + n);
        sum += term;
        if (term.abs() < sum.abs() * 1e-14) break;
      }
      return sum * math.exp(-x + a * math.log(x) - _logGamma(a));
    }
    return 1 - _gammaQcf(a, x);
  }

  static double _gammaQcf(double a, double x) {
    var b = x + 1 - a;
    var c = 1e30;
    var d = 1 / b;
    var h = d;
    for (var i = 1; i < 200; i++) {
      final an = -i * (i - a);
      b += 2;
      d = an * d + b;
      if (d.abs() < 1e-30) d = 1e-30;
      c = b + an / c;
      if (c.abs() < 1e-30) c = 1e-30;
      d = 1 / d;
      final delta = d * c;
      h *= delta;
      if ((delta - 1).abs() < 1e-14) break;
    }
    return math.exp(-x + a * math.log(x) - _logGamma(a)) * h;
  }

  /// Regularized incomplete beta I_x(a, b).
  static double betaI(double x, double a, double b) {
    if (x <= 0) return 0;
    if (x >= 1) return 1;
    final bt = math.exp(_logGamma(a + b) -
        _logGamma(a) -
        _logGamma(b) +
        a * math.log(x) +
        b * math.log(1 - x));
    if (x < (a + 1) / (a + b + 2)) {
      return bt * _betaCf(x, a, b) / a;
    }
    return 1 - bt * _betaCf(1 - x, b, a) / b;
  }

  static double _betaCf(double x, double a, double b) {
    var c = 1.0;
    var d = 1 - (a + b) * x / (a + 1);
    if (d.abs() < 1e-30) d = 1e-30;
    d = 1 / d;
    var h = d;
    for (var m = 1; m < 200; m++) {
      final m2 = 2 * m;
      var aa = m * (b - m) * x / ((a + m2 - 1) * (a + m2));
      d = 1 + aa * d;
      if (d.abs() < 1e-30) d = 1e-30;
      c = 1 + aa / c;
      if (c.abs() < 1e-30) c = 1e-30;
      d = 1 / d;
      h *= d * c;
      aa = -(a + m) * (a + b + m) * x / ((a + m2) * (a + m2 + 1));
      d = 1 + aa * d;
      if (d.abs() < 1e-30) d = 1e-30;
      c = 1 + aa / c;
      if (c.abs() < 1e-30) c = 1e-30;
      d = 1 / d;
      final delta = d * c;
      h *= delta;
      if ((delta - 1).abs() < 1e-14) break;
    }
    return h;
  }

  static double normalPdf(double x, [double mu = 0, double sigma = 1]) {
    final z = (x - mu) / sigma;
    return math.exp(-0.5 * z * z) / (sigma * math.sqrt(2 * math.pi));
  }

  static double normalCdf(double lo, double hi,
      [double mu = 0, double sigma = 1]) {
    double phi(double z) => 0.5 * (1 + _erf(z / math.sqrt2));
    return phi((hi - mu) / sigma) - phi((lo - mu) / sigma);
  }

  static double _erf(double x) {
    final t = 1 / (1 + 0.5 * x.abs());
    final tau = t *
        math.exp(-x * x -
            1.26551223 +
            t *
                (1.00002368 +
                    t *
                        (0.37409196 +
                            t *
                                (0.09678418 +
                                    t *
                                        (-0.18628806 +
                                            t *
                                                (0.27886807 +
                                                    t *
                                                        (-1.13520398 +
                                                            t *
                                                                (1.48851587 +
                                                                    t * (-0.82215223 + t * 0.17087277)))))))));
    return x >= 0 ? 1 - tau : tau - 1;
  }

  /// Inverse normal via rational approximation + Newton polish.
  static double invNorm(double p, [double mu = 0, double sigma = 1]) {
    if (p <= 0 || p >= 1) throw const CalcException('DOMAIN');
    const a = [
      -3.969683028665376e1, 2.209460984245205e2, -2.759285104469687e2,
      1.383577518672690e2, -3.066479806614716e1, 2.506628277459239e0,
    ];
    const b = [
      -5.447609879822406e1, 1.615858368580409e2, -1.556989798598866e2,
      6.680131188771972e1, -1.328068155288572e1,
    ];
    const c = [
      -7.784894002430293e-3, -3.223964580411365e-1, -2.400758277161838e0,
      -2.549732539343734e0, 4.374664141464968e0, 2.938163982698783e0,
    ];
    const d = [
      7.784695709041462e-3, 3.224671290700398e-1, 2.445134137142996e0,
      3.754408661907416e0,
    ];
    const plow = 0.02425;
    const phigh = 1 - plow;
    double z;
    if (p < plow) {
      final q = math.sqrt(-2 * math.log(p));
      z = (((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) /
          ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1);
    } else if (p > phigh) {
      final q = math.sqrt(-2 * math.log(1 - p));
      z = -(((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) /
          ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1);
    } else {
      final q = p - 0.5;
      final r = q * q;
      z = (((((a[0] * r + a[1]) * r + a[2]) * r + a[3]) * r + a[4]) * r + a[5]) *
          q /
          (((((b[0] * r + b[1]) * r + b[2]) * r + b[3]) * r + b[4]) * r + 1);
    }
    for (var i = 0; i < 3; i++) {
      final err = normalCdf(-1e99, z) - p;
      z -= err / normalPdf(z);
    }
    return mu + sigma * z;
  }

  static double tPdf(double x, double df) {
    return math.exp(_logGamma((df + 1) / 2) - _logGamma(df / 2)) /
        math.sqrt(df * math.pi) *
        math.pow(1 + x * x / df, -(df + 1) / 2);
  }

  static double tCdf(double lo, double hi, double df) {
    double cdf(double t) {
      final x = df / (df + t * t);
      final ib = betaI(x, df / 2, 0.5);
      return t >= 0 ? 1 - 0.5 * ib : 0.5 * ib;
    }
    return cdf(hi) - cdf(lo);
  }

  static double invT(double p, double df) {
    if (p <= 0 || p >= 1) throw const CalcException('DOMAIN');
    var t = invNorm(p);
    for (var i = 0; i < 8; i++) {
      final err = tCdf(-1e99, t, df) - p;
      final d = tPdf(t, df);
      if (d == 0) break;
      t -= err / d;
    }
    return t;
  }

  static double chi2Pdf(double x, double df) {
    if (x <= 0) return 0;
    return math.exp((df / 2 - 1) * math.log(x) -
            x / 2 -
            _logGamma(df / 2) -
            (df / 2) * math.log(2));
  }

  static double chi2Cdf(double lo, double hi, double df) {
    return gammaP(df / 2, hi / 2) - gammaP(df / 2, lo / 2);
  }

  static double fPdf(double x, double d1, double d2) {
    if (x <= 0) return 0;
    final logB = _logGamma(d1 / 2) + _logGamma(d2 / 2) - _logGamma((d1 + d2) / 2);
    return math.exp((d1 / 2) * math.log(d1 / d2) +
        (d1 / 2 - 1) * math.log(x) -
        ((d1 + d2) / 2) * math.log(1 + d1 * x / d2) -
        logB);
  }

  static double fCdf(double lo, double hi, double d1, double d2) {
    double cdf(double x) =>
        x <= 0 ? 0 : betaI(d1 * x / (d1 * x + d2), d1 / 2, d2 / 2);
    return cdf(hi) - cdf(lo);
  }

  static double binomPdf(int n, double p, [int? k]) {
    double one(int kk) => math.exp(_logGamma(n + 1) -
        _logGamma(kk + 1) -
        _logGamma(n - kk + 1) +
        kk * math.log(p.clamp(1e-300, 1)) +
        (n - kk) * math.log((1 - p).clamp(1e-300, 1)));
    if (k != null) return one(k);
    var s = 0.0;
    for (var i = 0; i <= n; i++) {
      s += one(i);
    }
    return s;
  }

  static double binomCdf(int n, double p, [double lo = -1e99, double hi = 1e99]) {
    final l = lo <= -1e90 ? 0 : lo.ceil();
    final h = hi >= 1e90 ? n : hi.floor();
    var s = 0.0;
    for (var k = l; k <= h; k++) {
      s += binomPdf(n, p, k);
    }
    return s;
  }

  static double poissonPdf(double lambda, int k) => math.exp(
      -lambda + k * math.log(lambda.clamp(1e-300, 1e300)) - _logGamma(k + 1));

  static double poissonCdf(double lambda,
      [double lo = -1e99, double hi = 1e99]) {
    final l = lo <= -1e90 ? 0 : lo.ceil();
    final h = hi >= 1e90 ? (lambda + 10 * math.sqrt(lambda) + 50).ceil() : hi.floor();
    var s = 0.0;
    for (var k = l; k <= h; k++) {
      s += poissonPdf(lambda, k);
    }
    return s;
  }

  static double geometPdf(double p, int k) =>
      k < 1 ? 0 : p * math.pow(1 - p, k - 1);

  static double geometCdf(double p, [double lo = -1e99, double hi = 1e99]) {
    final l = lo <= -1e90 ? 1 : lo.ceil();
    final h = hi >= 1e90 ? 10000 : hi.floor();
    var s = 0.0;
    for (var k = l; k <= h; k++) {
      s += geometPdf(p, k);
    }
    return s;
  }
}
