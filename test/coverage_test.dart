import 'package:calc84/engine/complex.dart';
import 'package:calc84/engine/context.dart';
import 'package:calc84/engine/evaluator.dart';
import 'package:calc84/engine/fraction.dart';
import 'package:calc84/engine/regressions.dart';
import 'package:calc84/engine/value.dart';
import 'package:flutter_test/flutter_test.dart';

double num_(String src, [CalcContext? ctx]) =>
    evalSource(src, ctx ?? CalcContext()).asReal;

void main() {
  setUpAll(() => registerInlineEval(evalSource));

  group('complex', () {
    test('ops', () {
      const a = Complex(3, 4);
      const b = Complex(1, -2);
      expect((a + b).re, 4);
      expect((a - b).im, 6);
      expect((a * b).re, 11);
      expect((a / b).im, closeTo(2, 1e-12));
      expect(a.magnitude, 5);
      expect(a.conjugate.im, -4);
      expect(a.argument, closeTo(0.9272952180016122, 1e-10));
    });
    test('trig and exp', () {
      expect((Complex.i * Complex.i).re, closeTo(-1, 1e-12));
      expect(const Complex(0, mathPi).exp.re, closeTo(-1, 1e-12));
      expect(const Complex(1, 0).sqrt.re, closeTo(1, 1e-12));
      expect(const Complex(0, 0).sin().re, 0);
      expect(const Complex(0, 0).cos().re, 1);
      expect(const Complex(1, 1).ln.im, closeTo(mathPi / 4, 1e-10));
      expect(const Complex(1, 0).pow(const Complex(0, mathPi)).re,
          closeTo(1, 1e-12));
    });
  });

  group('matrix ops', () {
    test('determinant, inverse, transpose, rref', () {
      final ctx = CalcContext();
      evalSource('[[1,2][3,4]]→[A]', ctx);
      expect(num_('det([A])', ctx), closeTo(-2, 1e-12));
      final inv = evalSource('[A]⁻¹', ctx) as MatrixValue;
      expect(inv.m.at(0, 0), closeTo(-2, 1e-12));
      final t = evalSource('[A]ᵀ', ctx) as MatrixValue;
      expect(t.m.at(0, 1), 3);
      final r = evalSource('rref([A])', ctx) as MatrixValue;
      expect(r.m.at(0, 0), 1);
      expect(r.m.at(0, 1), 0);
      final rf = evalSource('ref([[1,2][3,4]])', ctx) as MatrixValue;
      expect(rf.m.at(1, 0), 0);
      final d = evalSource('dim([A])', ctx) as ListValue;
      expect(d.items.map((e) => e.asReal).toList(), [2, 2]);
      final id = evalSource('identity(3)', ctx) as MatrixValue;
      expect(id.m.at(2, 2), 1);
      final aug = evalSource('augment([A],[A])', ctx) as MatrixValue;
      expect(aug.m.cols, 4);
    });
    test('matrix scalar and row ops', () {
      final ctx = CalcContext();
      evalSource('[[1,0][0,1]]→[B]', ctx);
      final s = evalSource('[B]*5', ctx) as MatrixValue;
      expect(s.m.at(0, 0), 5);
      final sw = evalSource('rowSwap([B],1,2)', ctx) as MatrixValue;
      expect(sw.m.at(0, 0), 0);
      final rm = evalSource('randM(2,2)', ctx) as MatrixValue;
      expect(rm.m.rows, 2);
      evalSource('Fill(7,[B])', ctx);
      expect(ctx.matrix('[B]')!.at(0, 0), 7);
      evalSource('{3,4}→dim([B])', ctx);
      expect(ctx.matrix('[B]')!.rows, 3);
      expect(ctx.matrix('[B]')!.cols, 4);
    });
  });

  group('fraction', () {
    test('approximate and format', () {
      final f = Fraction.approximate(0.75)!;
      expect(f.toString(), '3/4');
      final h = Fraction.approximate(2.5)!;
      expect(h.n, 5);
      expect(h.d, 2);
      final i = Fraction.approximate(1.4142135623730951)!;
      expect(i.n / i.d, closeTo(1.4142135623730951, 1e-6));
    });
    test('frac hint', () {
      final v = evalSource('0.5▸Frac', CalcContext());
      expect(v.asReal, 0.5);
    });
  });

  group('more functions', () {
    test('inverse trig and hyperbolic', () {
      expect(num_('sin⁻¹(1)'), closeTo(mathPi / 2, 1e-10));
      expect(num_('cos⁻¹(0.5)'), closeTo(1.0471975511965979, 1e-9));
      expect(num_('sinh⁻¹(1)'), closeTo(0.881373587019543, 1e-9));
      expect(num_('cosh⁻¹(2)'), closeTo(1.3169578969248166, 1e-9));
      expect(num_('tanh⁻¹(0.5)'), closeTo(0.549306144334055, 1e-9));
    });
    test('complex functions', () {
      final ctx = CalcContext()..complexMode = ComplexMode.aBi;
      expect(num_('abs(3+4i)', ctx), 5);
      expect(num_('real(3+4i)', ctx), 3);
      expect(num_('imag(3+4i)', ctx), 4);
      expect(num_('angle(1+i)', ctx), closeTo(mathPi / 4, 1e-10));
      final c = evalSource('conj(3+4i)', ctx);
      expect(c.toString(), contains('-4'));
    });
    test('misc', () {
      expect(num_('piecewise(1,2<3,9)'), 1);
      expect(num_('dayOfWk(2000,1,1)'), 7);
      expect(num_('dbd(1.0120,2.0120)'), 31);
      expect(num_('not(5)'), 0);
      final g = evalSource('getDate()', CalcContext());
      expect(g, isA<Value>());
      final r = num_('rand');
      expect(r, inInclusiveRange(0, 1));
      final ri = num_('randInt(1,10)');
      expect(ri, inInclusiveRange(1, 10));
      final rl = evalSource('randInt(1,5,3)', CalcContext()) as ListValue;
      expect(rl.items.length, 3);
      final nr = evalSource('randIntNoRep(1,5,3)', CalcContext()) as ListValue;
      expect(nr.items.length, 3);
      final rn = num_('randNorm(0,1)');
      expect(rn.isFinite, isTrue);
      final rb = num_('randBin(10,0.5)');
      expect(rb, inInclusiveRange(0, 10));
    });
    test('sort and stat helpers', () {
      final ctx = CalcContext();
      evalSource('{3,1,2}→L1', ctx);
      evalSource('SortA(L1)', ctx);
      expect(ctx.list('L1'), [1, 2, 3]);
      evalSource('SortD(L1)', ctx);
      expect(ctx.list('L1'), [3, 2, 1]);
      expect(num_('dim(L1)', ctx), 3);
      evalSource('{9,8}→L2', ctx);
      evalSource('5→dim(L2)', ctx);
      expect(ctx.list('L2').length, 5);
      final cum = evalSource('cumSum(L2)', ctx) as ListValue;
      expect(cum.items.length, 5);
      final dl = evalSource('ΔList(L2)', ctx) as ListValue;
      expect(dl.items.length, 4);
    });
    test('expr and string eval', () {
      final ctx = CalcContext();
      evalSource('2→B', ctx);
      expect(num_('expr("B*3")', ctx), 6);
    });
  });

  group('regressions detail', () {
    test('two-var stats', () {
      final r = Regressions.twoVar([1, 2, 3], [2, 4, 6]);
      expect(r.coefficients['n'], 3);
    });
    test('quad and cubic fit', () {
      final q = Regressions.poly([0, 1, 2, 3], [1, 3, 7, 13], 2);
      // y = x² + x + 1
      expect(q.coefficients.values.any((v) => (v - 1).abs() < 1e-6), isTrue);
      final c =
          Regressions.poly([0, 1, 2, 3, 4], [1, 4, 15, 40, 85], 3);
      expect(c.name, isNotEmpty);
    });
    test('med-med, ln, exp, pwr', () {
      final x = <double>[1, 2, 3, 4, 5, 6, 7, 8, 9];
      final y = <double>[2, 4, 5, 4, 5, 7, 8, 9, 10];
      expect(Regressions.medMed(x, y).fields, isNotEmpty);
      expect(Regressions.lnReg(x, y).fields, isNotEmpty);
      expect(Regressions.expReg(x, y).fields, isNotEmpty);
      expect(Regressions.pwrReg(x, y).fields, isNotEmpty);
    });
  });
}

const mathPi = 3.141592653589793;

