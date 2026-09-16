import 'dart:math' as math;

import 'value.dart';

/// Time value of money solver for the Finance app.
/// Solves for any one of N, I%, PV, PMT, FV given the others.
class TvmSolver {
  double n = 0;
  double i = 0;
  double pv = 0;
  double pmt = 0;
  double fv = 0;
  double py = 12;
  double cy = 12;
  bool pmtEnd = true;

  double _rate() => i / 100 / cy;

  /// Future-value annuity factor ((1+r)^n - 1)/r, adjusted for
  /// payments at the beginning of each period.
  double _pmtFactor(double rate, double periods) {
    if (rate == 0) return periods;
    return (math.pow(1 + rate, periods).toDouble() - 1) /
        rate *
        (pmtEnd ? 1 : 1 + rate);
  }

  double _fvOf(double rate, double periods) => math.pow(1 + rate, periods).toDouble();

  /// fv = -(pv*(1+r)^n + pmt*factor)
  double _fvm(double rate, double periods) =>
      -(pv * _fvOf(rate, periods) + pmt * _pmtFactor(rate, periods));

  double solveFv() => fv = _fvm(_rate(), n);

  double solvePv() => pv = (-fv - pmt * _pmtFactor(_rate(), n)) / _fvOf(_rate(), n);

  double solvePmt() {
    final rate = _rate();
    final factor = _pmtFactor(rate, n);
    if (factor == 0) throw _tvmErr();
    return pmt = (-fv - pv * _fvOf(rate, n)) / factor;
  }

  double solveN() {
    final rate = _rate();
    if (rate == 0) {
      if (pmt == 0) throw _tvmErr();
      return n = -(pv + fv) / pmt;
    }
    final b = pmt * (pmtEnd ? 1 : 1 + rate) / rate;
    final num_ = b - fv;
    final den = pv + b;
    if (num_ / den <= 0) throw _tvmErr();
    return n = math.log(num_ / den) / math.log(1 + rate);
  }

  double solveI() {
    // Secant iteration on the FV equation.
    var r1 = 0.01, r2 = 0.02;
    double f(double rate) {
      final oldI = i;
      i = rate * 100 * cy;
      final v = _fvm(rate, n) - fv;
      i = oldI;
      return v;
    }

    var f1 = f(r1);
    var f2 = f(r2);
    for (var iter = 0; iter < 200; iter++) {
      if ((f2 - f1).abs() < 1e-15) break;
      final r3 = r2 - f2 * (r2 - r1) / (f2 - f1);
      r1 = r2;
      f1 = f2;
      r2 = r3;
      f2 = f(r3);
      if (f2.abs() < 1e-8) break;
    }
    if (f2.abs() > 1e-4) throw _tvmErr();
    return i = r2 * 100 * cy;
  }

  double solve(String field) => switch (field) {
        'N' => solveN(),
        'I%' => solveI(),
        'PV' => solvePv(),
        'PMT' => solvePmt(),
        'FV' => solveFv(),
        _ => throw _tvmErr(),
      };
}

Exception _tvmErr() => const CalcException('NO SOLUTION');
