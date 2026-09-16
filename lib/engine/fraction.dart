/// Exact-ish fraction helpers for the Frac display mode and the
/// math menu conversions.
class Fraction {
  const Fraction(this.n, this.d);

  final int n;
  final int d;

  static const maxDenominator = 9999;

  /// Best rational approximation of [v] within [maxDenominator],
  /// using continued fractions like the classic Frac conversion.
  static Fraction? approximate(double v,
      {int maxDen = maxDenominator, double tol = 1e-9}) {
    if (!v.isFinite || v.abs() > 1e15) return null;
    final sign = v < 0 ? -1 : 1;
    var x = v.abs();
    var h1 = 1, h2 = 0, k1 = 0, k2 = 1;
    while (x > 1e-12) {
      final a = x.floor();
      final h = a * h1 + h2;
      final k = a * k1 + k2;
      if (k > maxDen) break;
      h2 = h1;
      h1 = h;
      k2 = k1;
      k1 = k;
      final approx = h1 / k1;
      if ((approx - x).abs() < tol) {
        return Fraction(sign * h1, k1);
      }
      x = 1 / (x - a);
      if (x > 1e15) break;
    }
    return Fraction(sign * h1, k1);
  }

  @override
  String toString() => d == 1 ? '$n' : '$n/$d';
}
