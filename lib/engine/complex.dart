import 'dart:math' as math;

/// Immutable complex number used when the calculator is in a+bi mode.
class Complex {
  const Complex(this.re, this.im);

  final double re;
  final double im;

  static const zero = Complex(0, 0);
  static const one = Complex(1, 0);
  static const i = Complex(0, 1);

  bool get isReal => im == 0;

  double get magnitude => math.sqrt(re * re + im * im);

  double get argument => math.atan2(im, re);

  Complex get conjugate => Complex(re, -im);

  Complex operator +(Complex o) => Complex(re + o.re, im + o.im);

  Complex operator -(Complex o) => Complex(re - o.re, im - o.im);

  Complex operator -() => Complex(-re, -im);

  Complex operator *(Complex o) =>
      Complex(re * o.re - im * o.im, re * o.im + im * o.re);

  Complex operator /(Complex o) {
    final d = o.re * o.re + o.im * o.im;
    return Complex((re * o.re + im * o.im) / d, (im * o.re - re * o.im) / d);
  }

  Complex pow(Complex o) {
    if (o.isReal && o.re == o.re.roundToDouble() && o.re.abs() < 64) {
      var result = one;
      var base = this;
      var n = o.re.round();
      final neg = n < 0;
      n = n.abs();
      while (n > 0) {
        if (n.isOdd) result = result * base;
        base = base * base;
        n >>= 1;
      }
      return neg ? one / result : result;
    }
    if (re == 0 && im == 0) {
      return o.re > 0 ? Complex.zero : const Complex(1e300, 1e300);
    }
    final lnR = math.log(magnitude);
    final theta = argument;
    final r = math.exp(lnR * o.re - theta * o.im);
    final t = lnR * o.im + theta * o.re;
    return Complex(r * math.cos(t), r * math.sin(t));
  }

  Complex get exp {
    final r = math.exp(re);
    return Complex(r * math.cos(im), r * math.sin(im));
  }

  Complex get ln => Complex(math.log(magnitude), argument);

  Complex get sqrt => pow(const Complex(0.5, 0));

  static double _sinh(double x) => (math.exp(x) - math.exp(-x)) / 2;

  static double _cosh(double x) => (math.exp(x) + math.exp(-x)) / 2;

  Complex sin() => Complex(
        math.sin(re) * _cosh(im),
        math.cos(re) * _sinh(im),
      );

  Complex cos() => Complex(
        math.cos(re) * _cosh(im),
        -math.sin(re) * _sinh(im),
      );

  Complex tan() => sin() / cos();

  Complex get sinhC => (exp - (-this).exp) / const Complex(2, 0);

  Complex get coshC => (exp + (-this).exp) / const Complex(2, 0);

  Complex get tanhC => sinhC / coshC;

  Complex get asinh => (this + (this * this + one).sqrt).ln;

  Complex get acosh =>
      (this + (this - one).sqrt * (this + one).sqrt).ln;

  Complex get atanh =>
      ((one + this).ln - (one - this).ln) / const Complex(2, 0);

  Complex asin() {
    final iz = i * this;
    final inner = (one - this * this).sqrt;
    return -(i * (iz + inner).ln);
  }

  Complex acos() {
    final inner = (this + i * (one - this * this).sqrt).ln;
    return -(i * inner);
  }

  Complex atan() {
    final iz = i * this;
    final inner = ((one + iz) / (one - iz)).ln;
    return inner * const Complex(0, -0.5);
  }

  @override
  bool operator ==(Object other) =>
      other is Complex && other.re == re && other.im == im;

  @override
  int get hashCode => Object.hash(re, im);

  @override
  String toString() => '$re${im >= 0 ? '+' : ''}${im}i';
}
