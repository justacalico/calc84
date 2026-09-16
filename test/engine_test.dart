import 'package:calc84/engine/context.dart';
import 'package:calc84/engine/evaluator.dart';
import 'package:calc84/engine/value.dart';
import 'package:flutter_test/flutter_test.dart';

double num_(String src, [CalcContext? ctx]) =>
    evalSource(src, ctx ?? CalcContext()).asReal;

void main() {
  group('arithmetic', () {
    test('basic ops and precedence', () {
      expect(num_('1+2*3'), 7);
      expect(num_('(1+2)*3'), 9);
      expect(num_('10/4'), 2.5);
      expect(num_('2^3^2'), 512);
      expect(num_('9-4-3'), 2);
      expect(num_('-3^2'), -9);
      expect(num_('(-3)^2'), 9);
    });

    test('implicit multiplication', () {
      expect(num_('2(3+4)'), 14);
      expect(num_('3sin(0)'), 0);
      expect(num_('2π'), closeTo(6.283185307179586, 1e-12));
    });

    test('postfix operators', () {
      expect(num_('5!'), 120);
      expect(num_('4²'), 16);
      expect(num_('3⁻¹'), closeTo(1 / 3, 1e-12));
      expect(num_('2°'), closeTo(0.03490658503988659, 1e-12));
      expect(num_('100%'), 1);
    });

    test('variables and ans', () {
      final ctx = CalcContext();
      expect(num_('5→A', ctx), 5);
      expect(num_('A+2', ctx), 7);
    });

    test('ans reads the stored answer', () {
      final ctx = CalcContext();
      ctx.ans = evalSource('42', ctx);
      expect(num_('Ans*2', ctx), 84);
    });
  });

  group('comparison and logic', () {
    test('comparisons', () {
      expect(num_('1<2'), 1);
      expect(num_('2≤2'), 1);
      expect(num_('3>4'), 0);
      expect(num_('1=1'), 1);
      expect(num_('1≠2'), 1);
      expect(num_('2≥3'), 0);
    });

    test('logical ops', () {
      expect(num_('1 and 1'), 1);
      expect(num_('1 and 0'), 0);
      expect(num_('0 or 1'), 1);
      expect(num_('1 xor 1'), 0);
      expect(num_('not(0)'), 1);
    });
  });

  group('lists', () {
    test('list literals and elementwise math', () {
      final v = evalSource('{1,2,3}+{10,20,30}', CalcContext());
      expect((v as ListValue).items.map((e) => e.asReal).toList(),
          [11, 22, 33]);
      final sq = evalSource('{1,2,3}²', CalcContext()) as ListValue;
      expect(sq.items.map((e) => e.asReal).toList(), [1, 4, 9]);
    });

    test('list storage and access', () {
      final ctx = CalcContext();
      evalSource('{5,6,7}→L1', ctx);
      expect(ctx.list('L1'), [5, 6, 7]);
      expect(num_('L1(2)', ctx), 6);
    });
  });

  group('complex', () {
    test('complex arithmetic', () {
      final ctx = CalcContext()..complexMode = ComplexMode.aBi;
      final v = evalSource('(1+2i)+(3-1i)', ctx);
      expect(v.toString(), contains('4'));
      final p = evalSource('(1+i)*(1-i)', ctx);
      expect(p.asReal, closeTo(2, 1e-12));
    });

    test('sqrt of negative in real mode throws', () {
      expect(() => num_('√(-4)'), throwsA(isA<CalcException>()));
    });
  });

  group('matrices', () {
    test('matrix storage and multiply', () {
      final ctx = CalcContext();
      evalSource('[[1,2][3,4]]→[A]', ctx);
      final m = ctx.matrix('[A]')!;
      expect(m.rows, 2);
      expect(m.at(0, 1), 2);
      final prod = evalSource('[A]*[A]', ctx) as MatrixValue;
      expect(prod.m.at(0, 0), 7);
      expect(prod.m.at(1, 1), 22);
    });
  });

  group('errors', () {
    test('syntax error', () {
      expect(() => num_('1+*2'), throwsA(isA<CalcException>()));
    });
    test('divide by zero', () {
      expect(() => num_('1/0'), throwsA(isA<CalcException>()));
    });
    test('undefined variable name throws', () {
      expect(() => num_('noSuchFn(1)'), throwsA(isA<CalcException>()));
    });
    test('dim mismatch on lists', () {
      expect(() => evalSource('{1,2}+{1,2,3}', CalcContext()),
          throwsA(isA<CalcException>()));
    });
  });
}
