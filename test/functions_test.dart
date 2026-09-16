import 'dart:math' as math;

import 'package:calc84/engine/calculus.dart';
import 'package:calc84/engine/context.dart';
import 'package:calc84/engine/distributions.dart';
import 'package:calc84/engine/evaluator.dart';
import 'package:calc84/engine/regressions.dart';
import 'package:calc84/engine/value.dart';
import 'package:flutter_test/flutter_test.dart';

double num_(String src, [CalcContext? ctx]) =>
    evalSource(src, ctx ?? CalcContext()).asReal;

void main() {
  group('math functions', () {
    test('trig honors angle mode', () {
      expect(num_('sin(π/2)'), closeTo(1, 1e-12));
      final deg = CalcContext()..angleMode = AngleMode.degree;
      expect(num_('sin(90)', deg), closeTo(1, 1e-12));
      expect(num_('cos(180)', deg), closeTo(-1, 1e-12));
      expect(num_('tan⁻¹(1)', deg), closeTo(45, 1e-9));
    });

    test('hyperbolic', () {
      expect(num_('sinh(1)'), closeTo(1.1752011936438014, 1e-10));
      expect(num_('cosh(0)'), 1);
      expect(num_('tanh(1)'), closeTo(0.7615941559557649, 1e-10));
    });

    test('log, ln, exp, roots', () {
      expect(num_('log(100)'), 2);
      expect(num_('ln(e)'), closeTo(1, 1e-12));
      expect(num_('e^(1)'), closeTo(math.e, 1e-12));
      expect(num_('√(144)'), 12);
      expect(num_('³√(27)'), closeTo(3, 1e-10));
      expect(num_('logBASE(8,2)'), 3);
      expect(num_('2ˣ√9'), closeTo(3, 1e-10));
    });

    test('int, frac, abs, round, gcd, lcm, remainder', () {
      expect(num_('iPart(-3.7)'), -3);
      expect(num_('fPart(-3.7)'), closeTo(-0.7, 1e-12));
      expect(num_('int(-3.2)'), -4);
      expect(num_('abs(-9)'), 9);
      expect(num_('round(π,2)'), closeTo(3.14, 1e-12));
      expect(num_('gcd(12,18)'), 6);
      expect(num_('lcm(4,6)'), 12);
      expect(num_('remainder(10,3)'), 1);
    });

    test('min max over lists', () {
      expect(num_('min({3,1,4})'), 1);
      expect(num_('max({3,1,4})'), 4);
      expect(num_('mean({1,2,3,4})'), 2.5);
      expect(num_('median({1,3,2,4,5})'), 3);
      expect(num_('sum({1,2,3,4})'), 10);
      expect(num_('prod({1,2,3,4})'), 24);
      expect(num_('stdDev({2,4,4,4,5,5,7,9})'),
          closeTo(math.sqrt(32 / 7), 1e-9));
      expect(num_('variance({2,4,4,4,5,5,7,9})'), closeTo(32 / 7, 1e-9));
    });

    test('combinatorics', () {
      expect(num_('5 nPr 2'), 20);
      expect(num_('5 nCr 2'), 10);
    });

    test('seq, cumSum, augment, sub, inString, length', () {
      final s = evalSource('seq(X²,X,1,4)', CalcContext()) as ListValue;
      expect(s.items.map((e) => e.asReal).toList(), [1, 4, 9, 16]);
      final c = evalSource('cumSum({1,2,3})', CalcContext()) as ListValue;
      expect(c.items.map((e) => e.asReal).toList(), [1, 3, 6]);
      final a =
          evalSource('augment({1,2},{3})', CalcContext()) as ListValue;
      expect(a.items.length, 3);
      expect(num_('length("HELLO")'), 5);
      expect(num_('inString("HELLO","LL")'), 3);
      final sub = evalSource('sub("HELLO",2,3)', CalcContext());
      expect(sub.toString(), contains('ELL'));
    });

    test('nDeriv and fnInt', () {
      expect(num_('nDeriv(X²,X,3)'), closeTo(6, 1e-4));
      expect(num_('fnInt(X,X,0,1)'), closeTo(0.5, 1e-5));
      expect(num_('fMin(X²,X,-5,5)').abs(), lessThan(1e-4));
      expect(num_('fMax(5-X²,X,-5,5)').abs(), lessThan(1e-4));
      expect(num_('solve(X²-9,X,2)'), closeTo(3, 1e-6));
    });
  });

  group('calculus helpers', () {
    test('derivative and integrate', () {
      expect(Calculus.derivative((x) => x * x, 4), closeTo(8, 1e-5));
      expect(Calculus.integrate((x) => x, 0, 2), closeTo(2, 1e-6));
    });
    test('solve finds roots', () {
      expect(Calculus.solve((x) => x * x - 2, 0, 4),
          closeTo(math.sqrt2, 1e-7));
    });
  });

  group('distributions', () {
    test('normal', () {
      expect(Distributions.normalPdf(0), closeTo(0.3989422804, 1e-9));
      expect(Distributions.normalCdf(-1e99, 0), closeTo(0.5, 1e-6));
      expect(Distributions.invNorm(0.975), closeTo(1.95996, 1e-4));
    });
    test('binom', () {
      expect(Distributions.binomPdf(4, 0.5, 2), closeTo(0.375, 1e-12));
      expect(Distributions.binomCdf(4, 0.5, -1e99, 2),
          closeTo(0.6875, 1e-9));
    });
    test('t and chi2', () {
      expect(Distributions.tCdf(-1e99, 0, 10), closeTo(0.5, 1e-6));
      expect(Distributions.chi2Cdf(0, 3.84, 1), closeTo(0.95, 1e-3));
    });
  });

  group('regressions', () {
    test('one-var stats', () {
      final r = Regressions.oneVar([1, 2, 3, 4, 5]);
      expect(r.coefficients['x̄'], 3);
      expect(r.coefficients['n'], 5);
    });
    test('linear regression fits a line', () {
      final r = Regressions.poly([1, 2, 3, 4], [3, 5, 7, 9], 1);
      final c = r.coefficients;
      // y = 2x + 1
      expect(c.values.any((v) => (v - 2).abs() < 1e-9), isTrue);
      expect(c.values.any((v) => (v - 1).abs() < 1e-9), isTrue);
    });
  });
}
