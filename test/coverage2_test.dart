import 'package:calc84/engine/complex.dart';
import 'package:calc84/engine/context.dart';
import 'package:calc84/engine/distributions.dart';
import 'package:calc84/engine/evaluator.dart';
import 'package:calc84/engine/format.dart';
import 'package:calc84/engine/matrix.dart';
import 'package:calc84/engine/tibasic.dart';
import 'package:calc84/engine/value.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  double num_(String src, [CalcContext? ctx]) =>
      evalSource(src, ctx ?? CalcContext()).asReal;

  group('complex class', () {
    test('all operations', () {
      const a = Complex(3, 4);
      const b = Complex(1, -2);
      expect(a.magnitude, 5);
      expect(a.argument, closeTo(0.9272952180016122, 1e-12));
      expect(a.conjugate, const Complex(3, -4));
      expect(a + b, const Complex(4, 2));
      expect(a - b, const Complex(2, 6));
      expect(-a, const Complex(-3, -4));
      expect(a * b, const Complex(11, -2));
      final q = a / b;
      expect(q.re, closeTo(-1, 1e-12));
      expect(q.im, closeTo(2, 1e-12));
      expect(const Complex(0, 1).pow(const Complex(2, 0)).re,
          closeTo(-1, 1e-12));
      expect(const Complex(2, 0).pow(const Complex(-2, 0)).re,
          closeTo(0.25, 1e-12));
      expect(const Complex(1, 1).pow(const Complex(1, 1)).re,
          closeTo(0.2739572, 1e-6));
      expect(const Complex(0, 0).sin(), Complex.zero);
      expect(const Complex(0, 0).cos(), Complex.one);
      expect(const Complex(0, 0).tan(), Complex.zero);
      expect(const Complex(0, 1).asin().im, closeTo(0.8813735, 1e-6));
      expect(const Complex(0, 0).acos().re, closeTo(mathPi / 2, 1e-10));
      expect(const Complex(1, 0).atan().re, closeTo(mathPi / 4, 1e-10));
      expect(const Complex(1, 1).hashCode, const Complex(1, 1).hashCode);
      expect(const Complex(1, -1).toString(), '1.0-1.0i');
      expect(const Complex(0, 0).isReal, isTrue);
      expect(const Complex(0, 1).sqrt.im, closeTo(0.7071067, 1e-6));
    });
  });

  group('evaluator complex paths', () {
    test('complex arithmetic in a+bi mode', () {
      final ctx = CalcContext()..complexMode = ComplexMode.aBi;
      expect(num_('real((2+3i)+(1-i))', ctx), 3);
      expect(num_('imag((2+3i)+(1-i))', ctx), 2);
      expect(num_('real((2+3i)+(1-i))', ctx), 3);
      expect(num_('imag(2+3i)', ctx), 3);
      expect(num_('i*i', ctx), -1);
      expect(num_('abs(3+4i)', ctx), 5);
      expect(num_('real(conj(2+3i))', ctx), 2);
      expect(num_('imag(conj(2+3i))', ctx), -3);
      expect(num_('angle(0+1i)', ctx), closeTo(mathPi / 2, 1e-9));
      final v = evalSource('(1+i)^2', ctx);
      expect(v.isComplex, isTrue);
      expect(v.asComplex.im, closeTo(2, 1e-10));
      expect(num_('real((1+i)/(1-i))', ctx), closeTo(0, 1e-10));
      expect(num_('imag((1+i)/(1-i))', ctx), closeTo(1, 1e-10));
      expect(num_('real((1+i)²)', ctx), closeTo(0, 1e-10));
      expect(num_('real(2 ˣ√(1+i))', ctx), closeTo(1.09868, 1e-4));
      expect(num_('real((1+i)⁻¹)', ctx), closeTo(0.5, 1e-10));
      expect(num_('real(-(1+i))', ctx), -1);
      expect(num_('real(√(-4))', ctx), closeTo(0, 1e-10));
      expect(num_('imag(√(-4))', ctx), 2);
      expect(num_('(1+i)=(1+i)', ctx), 1);
      expect(num_('(1+i)≠(1-i)', ctx), 1);
      expect(num_('(1+i) and 1', ctx), 1);
      expect(num_('(1+i) or 0', ctx), 1);
      expect(num_('(1+i) xor (1+i)', ctx), 0);
      expect(num_('real(e^(iπ))', ctx), closeTo(-1, 1e-10));
      expect(num_('real(ln(i))', ctx), closeTo(0, 1e-10));
      expect(num_('real(sin(i))', ctx), 0);
      expect(num_('real(cos(i))', ctx), closeTo(1.543, 1e-3));
      expect(num_('real(tan(i))', ctx), 0);
      expect(num_('real(sin⁻¹(2))', ctx), closeTo(mathPi / 2, 1e-9));
      expect(num_('real(cos⁻¹(2))', ctx), closeTo(0, 1e-9));
      expect(num_('real(tan⁻¹(2i))', ctx), closeTo(mathPi / 2, 1e-9));
      expect(num_('real(sinh(i))', ctx), 0);
      expect(num_('real(cosh(i))', ctx), closeTo(0.54030, 1e-5));
      expect(num_('real(tanh(i))', ctx), 0);
      expect(num_('real(sinh⁻¹(i))', ctx), 0);
      expect(num_('real(cosh⁻¹(2))', ctx), closeTo(1.3169, 1e-3));
      expect(num_('real(tanh⁻¹(0.5i))', ctx), 0);
      // Bare i is rejected outside a+bi mode.
      expect(() => num_('real(1+i)'), throwsA(anything));
    });

    test('nonreal answers error in real mode', () {
      expect(() => num_('√(-4)'), throwsA(anything));
      // Odd-denominator roots of negatives stay real.
      expect(num_('(-2)^(1/3)'), closeTo(-1.2599, 1e-3));
      expect(() => num_('(-2)^(0.5)'), throwsA(anything));
    });
  });

  group('evaluator matrix paths', () {
    CalcContext matCtx() {
      final ctx = CalcContext();
      evalSource('[[1,2][3,4]]→[A]', ctx);
      evalSource('[[5,6][7,8]]→[B]', ctx);
      return ctx;
    }

    test('matrix binary ops', () {
      final ctx = matCtx();
      expect(evalSource('[A]+[B]', ctx), isA<MatrixValue>());
      expect(evalSource('[A]-[B]', ctx), isA<MatrixValue>());
      expect(evalSource('[A]*[B]', ctx), isA<MatrixValue>());
      expect(evalSource('[A]*2', ctx), isA<MatrixValue>());
      expect(evalSource('2*[A]', ctx), isA<MatrixValue>());
      expect(evalSource('[A]/2', ctx), isA<MatrixValue>());
      expect(evalSource('[A]^2', ctx), isA<MatrixValue>());
      expect(evalSource('[A]ᵀ', ctx), isA<MatrixValue>());
      expect(evalSource('[A]⁻¹', ctx), isA<MatrixValue>());
      expect(evalSource('⁻[A]', ctx), isA<MatrixValue>());
      expect(num_('[A]=[A]', ctx), 1);
      expect(num_('[A]=[B]', ctx), 0);
      expect(num_('[A]≠[B]', ctx), 1);
    });

    test('matrix errors', () {
      final ctx = matCtx();
      evalSource('[[1,2,3]]→[C]', ctx);
      expect(() => evalSource('[A]+[C]', ctx), throwsA(anything));
      expect(() => evalSource('[A]+1', ctx), throwsA(anything));
      expect(() => evalSource('1+[A]', ctx), throwsA(anything));
      expect(() => evalSource('[A]/0', ctx), throwsA(anything));
      expect(() => evalSource('1/[A]', ctx), throwsA(anything));
      expect(() => evalSource('[A]^0.5', ctx), throwsA(anything));
      expect(() => evalSource('2^[A]', ctx), throwsA(anything));
      expect(() => evalSource('[A] and [B]', ctx), throwsA(anything));
      expect(() => evalSource('5 ᵀ', ctx), throwsA(anything));
      expect(() => evalSource('[Q]', ctx), throwsA(anything));
      expect(() => evalSource('[A](0,1)', ctx), throwsA(anything));
      expect(() => evalSource('[A](9,1)', ctx), throwsA(anything));
      expect(evalSource('[A](2,1)', ctx).asReal, 3);
      evalSource('{3,3}→dim([A])', ctx);
      expect(ctx.matrix('[A]')!.rows, 3);
      expect(() => evalSource('{0,2}→dim([A])', ctx), throwsA(anything));
      expect(() => evalSource('5→dim([A])', ctx), throwsA(anything));
      evalSource('3→dim(L1)', ctx);
      expect(ctx.list('L1').length, 3);
      evalSource('1→dim(L1)', ctx);
      expect(ctx.list('L1').length, 1);
      expect(() => evalSource('-1→dim(L1)', ctx), throwsA(anything));
      expect(() => evalSource('"x"→dim(L1)', ctx), throwsA(anything));
    });
  });

  group('evaluator list and string paths', () {
    test('list broadcasts and errors', () {
      final ctx = CalcContext();
      final v = evalSource('{1,2}+{3,4}', ctx);
      expect(v, isA<ListValue>());
      expect(evalSource('{1,2}*10', ctx), isA<ListValue>());
      expect(evalSource('10-{1,2}', ctx), isA<ListValue>());
      expect(evalSource('sin({0,1})', ctx), isA<ListValue>());
      expect(() => evalSource('{1,2}+{1,2,3}', ctx), throwsA(anything));
      evalSource('{5,6}→L1', ctx);
      expect(ctx.list('L1'), [5, 6]);
      evalSource('7→L1(1)', ctx);
      expect(ctx.list('L1'), [7, 6]);
      evalSource('9→L1(5)', ctx);
      expect(ctx.list('L1'), [7, 6, 0, 0, 9]);
      expect(() => evalSource('9→L1(0)', ctx), throwsA(anything));
      evalSource('5→L3(1)', ctx);
      expect(ctx.list('L3'), [5]);
    });

    test('strings', () {
      final ctx = CalcContext();
      expect(evalSource('"AB"+"CD"', ctx), isA<StringValue>());
      expect(num_('"A"="A"', ctx), 1);
      expect(num_('"A"≠"B"', ctx), 1);
      expect(num_('"A"="B"', ctx), 0);
      expect(() => evalSource('"A"-"B"', ctx), throwsA(anything));
      expect(() => evalSource('"A"+1', ctx), throwsA(anything));
      expect(() => evalSource('1+"A"', ctx), throwsA(anything));
      evalSource('"HI"→Str1', ctx);
      expect(ctx.strings['Str1'], 'HI');
      expect(evalSource('Str1', ctx), isA<StringValue>());
      expect(() => evalSource('5→Str1', ctx), throwsA(anything));
      expect(() => evalSource('"A"→A', ctx), throwsA(anything));
      expect(() => evalSource('"A"→[A]', ctx), throwsA(anything));
      expect(() => evalSource('"A"→L1', ctx), throwsA(anything));
    });
  });

  group('evaluator misc paths', () {
    test('postfix operators', () {
      final ctx = CalcContext()..angleMode = AngleMode.degree;
      expect(num_('90°', ctx), closeTo(mathPi / 2, 1e-10));
      expect(num_('1′', ctx), closeTo(mathPi / 10800, 1e-10));
      expect(num_('1″', ctx), closeTo(mathPi / 648000, 1e-10));
      expect(num_('1ʳ', ctx), closeTo(180 / mathPi, 1e-10));
      ctx.angleMode = AngleMode.radian;
      expect(num_('1ʳ', ctx), 1);
      expect(num_('5!', ctx), 120);
      expect(num_('0.5!', ctx), closeTo(0.8862269, 1e-6));
      expect(num_('50%', ctx), 0.5);
      expect(num_('2³', ctx), 8);
      expect(num_('5 nPr 2', ctx), 20);
      expect(num_('5 nCr 2', ctx), 10);
      expect(() => num_('(-1)!', ctx), throwsA(anything));
      expect(() => num_('500!', ctx), throwsA(anything));
      expect(() => num_('0⁻¹', ctx), throwsA(anything));
      expect(() => num_('2 nPr 5', ctx), throwsA(anything));
      expect(() => num_('2.5 nPr 1', ctx), throwsA(anything));
      expect(() => num_('0^0', ctx), throwsA(anything));
      expect(() => num_('0^-1', ctx), throwsA(anything));
      expect(num_('(-8)^(1/3)', ctx), closeTo(-2, 1e-9));
      expect(num_('(-8)^(2/3)', ctx), closeTo(4, 1e-9));
      expect(() => num_('1/0', ctx), throwsA(anything));
      expect(num_('getKey', ctx), isA<double>());
    });

    test('store to equation and sequence names', () {
      final ctx = CalcContext();
      evalSource('X²→Y1', ctx);
      expect(ctx.equation('Y1').expression, 'X²');
      evalSource('u(n-1)+1→u', ctx);
      expect(ctx.sequences['u']!.expression, isNotEmpty);
      evalSource('2→A', ctx);
      expect(ctx.getVar('A'), 2);
      expect(num_('Y1(3)', ctx), 9);
      expect(num_('Y1', ctx), 0);
    });

    test('unparse round trip', () {
      final ctx = CalcContext();
      evalSource('"S"+"T"→Str2', ctx);
      evalSource('{1,2}→L2', ctx);
      evalSource('3X+1→Y2', ctx);
      expect(ctx.equation('Y2').expression, '3*X+1');
      final v = evalSource('{1,2}', ctx);
      expect(v.toString(), contains('{'));
      expect(MatrixValue(Matrix(1, 1)).toString(), contains('['));
      expect(const RealValue(5).toString(), '5.0');
      expect(const ComplexValue(Complex.i).toString(), contains('i'));
      expect(const StringValue('hi').toString(), 'hi');
      expect(const CalcException('X').toString(), 'ERR:X');
      expect(const CalcException('X', 'd').toString(), 'ERR:X d');
      expect(() => evalSource('{1}', ctx).asReal, throwsA(anything));
      expect(() => const StringValue('x').asComplex, throwsA(anything));
    });
  });

  group('distributions', () {
    test('all pdf/cdf/inverse functions', () {
      expect(Distributions.normalPdf(0), closeTo(0.39894228, 1e-6));
      expect(Distributions.normalCdf(-1e99, 0), closeTo(0.5, 1e-6));
      expect(Distributions.invNorm(0.975), closeTo(1.95996, 1e-4));
      expect(Distributions.invNorm(0.01), closeTo(-2.32635, 1e-4));
      expect(Distributions.invNorm(0.999), closeTo(3.09023, 1e-4));
      expect(() => Distributions.invNorm(0), throwsA(anything));
      expect(() => Distributions.invNorm(1.5), throwsA(anything));
      expect(Distributions.tPdf(0, 10), closeTo(0.389108, 1e-5));
      expect(Distributions.tCdf(-1e99, 0, 10), closeTo(0.5, 1e-6));
      expect(Distributions.tCdf(-1e99, 1.812, 10), closeTo(0.95, 1e-3));
      expect(Distributions.invT(0.975, 10), closeTo(2.228, 1e-2));
      expect(() => Distributions.invT(0, 5), throwsA(anything));
      expect(Distributions.chi2Pdf(2, 4), closeTo(0.1839397, 1e-6));
      expect(Distributions.chi2Pdf(0, 4), 0);
      expect(Distributions.chi2Cdf(0, 9.488, 4), closeTo(0.95, 1e-3));
      expect(Distributions.fPdf(1, 5, 10), closeTo(0.49548, 1e-4));
      expect(Distributions.fPdf(0, 5, 10), 0);
      expect(Distributions.fCdf(0, 3.326, 5, 10), closeTo(0.95, 1e-2));
      expect(Distributions.binomPdf(10, 0.5, 5), closeTo(0.24609375, 1e-6));
      expect(Distributions.binomPdf(4, 0.5), closeTo(1, 1e-9));
      expect(Distributions.binomCdf(10, 0.5, 0, 5),
          closeTo(0.623046875, 1e-6));
      expect(Distributions.binomCdf(5, 0.5), closeTo(1, 1e-9));
      expect(Distributions.binomCdf(5, 0.5, 2, 3), closeTo(0.625, 1e-9));
      expect(Distributions.poissonPdf(3, 2), closeTo(0.22404, 1e-4));
      expect(Distributions.poissonCdf(3, 0, 2), closeTo(0.42319, 1e-4));
      expect(Distributions.poissonCdf(3), closeTo(1, 1e-9));
      expect(Distributions.poissonCdf(3, 1, 2), closeTo(0.37340, 1e-4));
      expect(Distributions.geometPdf(0.5, 3), closeTo(0.125, 1e-9));
      expect(Distributions.geometPdf(0.5, 0), 0);
      expect(Distributions.geometCdf(0.5, 1, 3), closeTo(0.875, 1e-9));
      expect(Distributions.geometCdf(0.5), closeTo(1, 1e-9));
      expect(Distributions.gammaP(2, 5), closeTo(0.95957, 1e-4));
      expect(Distributions.gammaP(5, 1), closeTo(0.0036598, 1e-5));
      expect(Distributions.betaI(0.5, 2, 2), closeTo(0.5, 1e-9));
      expect(Distributions.betaI(0, 2, 2), 0);
      expect(Distributions.betaI(1, 2, 2), 1);
    });
  });

  group('formatter', () {
    test('hints and notations', () {
      final s = DisplaySettings();
      final f = Formatter(s);
      expect(f.format(const ComplexValue(Complex(3, 4)), hint: '▸Polar')
          .lines.single, contains('e^('));
      expect(f.num(0.5, hint: '▸Frac'), '1/2');
      expect(f.num(1.5, hint: '▸Un/d'), '1◂1/2');
      expect(f.num(2, hint: '▸Un/d'), '2');
      expect(f.num(0.5, hint: '▸n/d'), '1/2');
      expect(f.num(12.5, hint: '▸DMS'), '12°30′');
      expect(f.dms(12.5125), '12°30′45″');
      expect(f.dms(-45), '-45°');
      expect(f.dms(1.016667), contains('1°1′'));
      expect(f.num(double.nan), 'NaN');
      expect(f.num(double.infinity), '∞');
      expect(f.num(double.negativeInfinity), '-∞');
      expect(f.num(0), '0');
      expect(f.num(1e15), contains('ᴇ'));
      expect(f.num(1e-8), contains('ᴇ'));
      s.notation = Notation.sci;
      expect(f.num(12345), contains('ᴇ'));
      s.notation = Notation.eng;
      expect(f.num(12345), '12.345ᴇ3');
      expect(f.num(0), '0');
      expect(f.num(1234567), contains('ᴇ6'));
      s.notation = Notation.normal;
      s.decimals = 2;
      expect(f.num(mathPi), '3.14');
      s.decimals = -1;
      expect(f.num(0.1 + 0.2), '0.3');
      expect(f.num(-0.0), '0');
      expect(f.num(123456789.123456), isNotEmpty);
      // Complex formatting
      expect(f.format(const ComplexValue(Complex(0, 2))).lines.single, '2i');
      expect(f.format(const ComplexValue(Complex(0, -2))).lines.single,
          '-2i');
      expect(f.format(const ComplexValue(Complex(1, -2))).lines.single,
          '1-2i');
      expect(f.format(const ComplexValue(Complex(3, 0))).lines.single, '3');
      // Lists with mixed cells
      expect(
          f.format(const ListValue([
            RealValue(1),
            ComplexValue(Complex(0, 1)),
            StringValue('hi'),
          ])).lines.single,
          contains('i'));
      // Matrix grid
      final m = f.format(MatrixValue(Matrix(2, 2)..set(1, 1, 5)));
      expect(m.matrixGrid, isNotNull);
      expect(m.lines.first, contains('['));
    });
  });

  group('tibasic', () {
    ProgramRunner run(String src, CalcContext ctx) =>
        ProgramRunner(src, ctx)..run();

    test('input and prompt flows', () {
      final ctx = CalcContext();
      final r = run('Input X\nDisp X*2', ctx);
      expect(r.io.paused, isTrue);
      expect(r.io.promptLabel, '?');
      r.resume('21');
      expect(r.io.lines, ['42']);

      final r2 = run('Input "VAL",Y\nDisp Y', ctx);
      expect(r2.io.promptLabel, 'VAL');
      r2.resume('9');
      expect(r2.io.lines, ['9']);

      final r3 = run('Input\nDisp X', ctx);
      r3.resume('7');
      expect(r3.io.lines, ['7']);

      final r4 = run('Prompt A,B\nDisp A+B', ctx);
      expect(r4.io.promptLabel, 'A=?');
      r4.resume('3');
      expect(r4.io.promptLabel, 'B=?');
      r4.resume('4');
      expect(r4.io.lines, ['7']);
    });

    test('pause, output, menu, stop', () {
      final ctx = CalcContext();
      final r = run('Disp 1\nPause\nDisp 2', ctx);
      expect(r.io.paused, isTrue);
      r.resume('');
      expect(r.io.lines, ['1', '2']);

      final r2 = run('Pause "WAIT"\nDisp 1', ctx);
      expect(r2.io.lines, ['WAIT']);

      final r3 = run('Output(1,1,42)\nStop\nDisp 9', ctx);
      expect(r3.io.lines, ['42']);
      expect(r3.io.done, isTrue);

      final r4 = run('Menu("T","A",1,"B",2)\nLbl 1\nDisp 10', ctx);
      expect(r4.io.paused, isTrue);
      r4.resume('');
    });

    test('else branch and multi-statement lines', () {
      final ctx = CalcContext();
      final r = run('If 0\nThen\nDisp 1\nElse\nDisp 2\nEnd\nDisp 3:Disp 4',
          ctx);
      expect(r.io.lines, ['2', '3', '4']);

      final r2 = run('If 1\nThen\nDisp 5\nEnd', ctx);
      expect(r2.io.lines, ['5']);

      final r3 = run('For(I,5,1)\nDisp I\nEnd', ctx);
      expect(r3.io.lines, isEmpty);

      final r4 = run('For(I,1,5,2)\nDisp I\nEnd', ctx);
      expect(r4.io.lines, ['1', '3', '5']);

      final r5 = run('While 0\nDisp 1\nEnd\nDisp 2', ctx);
      expect(r5.io.lines, ['2']);

      final r6 = run('Repeat X>3\nX+1→X\nEnd\nDisp X', ctx);
      expect(r6.io.lines, ['4']);

      final r7 = run('1→A\nGoto B\nLbl A\nDisp 1\nLbl B\nDisp 2', ctx);
      expect(r7.io.lines, ['2']);

      final r8 = run('Disp {1,2}\nDisp "A"+"B"\nDisp 1+i', ctx
        ..complexMode = ComplexMode.aBi);
      expect(r8.io.lines.length, 3);
    });
  });
}

const mathPi = 3.141592653589793;
