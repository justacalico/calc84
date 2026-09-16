import 'package:calc84/engine/context.dart';
import 'package:calc84/engine/evaluator.dart';
import 'package:calc84/engine/tvm.dart';
import 'package:calc84/engine/value.dart';
import 'package:calc84/model/keymap.dart';
import 'package:calc84/model/settings.dart';
import 'package:calc84/state/calc_state.dart';
import 'package:calc84/ui/lcd.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Coverage for remaining engine functions, TVM branches, matrix row
/// ops, and the LCD split-screen layouts.
void main() {
  double eval(String src) => evalSource(src, CalcContext()).asReal;
  double mat(String src, CalcContext ctx, int r, int c) =>
      (evalSource(src, ctx) as MatrixValue).m.at(r, c);

  group('engine extras', () {
    test('matrix row ops', () {
      final ctx = CalcContext();
      evalSource('[[1,2][3,4]]→[A]', ctx);
      expect(mat('rowSwap([A],1,2)', ctx, 0, 0), 3);
      expect(mat('row+([A],1,2)', ctx, 1, 0), 4);
      expect(mat('*row(2,[A],1)', ctx, 0, 0), 2);
      expect(mat('*row+(2,[A],1,2)', ctx, 1, 0), 5);
      // Pivot skip path in rref.
      evalSource('[[0,1][1,0]]→[B]', ctx);
      expect(mat('rref([B])', ctx, 0, 0), 1);
    });

    test('augment matrices and errors', () {
      final ctx = CalcContext();
      evalSource('[[1][2]]→[A]', ctx);
      evalSource('[[3][4]]→[B]', ctx);
      final m = (evalSource('augment([A],[B])', ctx) as MatrixValue).m;
      expect(m.cols, 2);
      expect(() => evalSource('augment([A],{1,2})', ctx),
          throwsA(anything));
      evalSource('[[1,2,3]]→[C]', ctx);
      expect(() => evalSource('augment([A],[C])', ctx),
          throwsA(anything));
      final l = evalSource('augment({1},{2})', ctx) as ListValue;
      expect(l.items.length, 2);
    });

    test('piecewise and summation', () {
      expect(eval('piecewise(1,X<0,2,X>5,3)'), 3);
      expect(eval('piecewise(9,X>100,7)'), 7);
      expect(() => eval('piecewise(9,X>100)'), throwsA(anything));
      expect(eval('summation Σ(X,X,1,5)'), 15);
    });

    test('stats with freq lists and range args', () {
      expect(eval('mean({1,2,3},{2,1,1})'), closeTo(1.75, 1e-9));
      expect(eval('median({1,2,3},{2,1,1})'), 1.5);
      expect(eval('stdDev({1,2,3},{1,1,1})'), closeTo(1, 1e-9));
      expect(eval('variance({1,2,3})'), closeTo(1, 1e-9));
      expect(eval('sum({1,2,3,4},2,3)'), 5);
      expect(eval('prod({1,2,3,4},2,4)'), 24);
      expect(eval('sum({5,6,7})'), 18);
      expect(evalSource('ΔList({1,4,9})', CalcContext()).toString(),
          contains('3'));
    });

    test('sort with dependent lists', () {
      final ctx = CalcContext();
      ctx.lists['L1'] = [3, 1, 2];
      ctx.lists['L2'] = [30, 10, 20];
      evalSource('SortA(L1,L2)', ctx);
      expect(ctx.lists['L1'], [1, 2, 3]);
      expect(ctx.lists['L2'], [10, 20, 30]);
      evalSource('SortD(L1,L2)', ctx);
      expect(ctx.lists['L2'], [30, 20, 10]);
      evalSource('SortA({2,1})', ctx);
    });

    test('dim and fill variants', () {
      final ctx = CalcContext();
      evalSource('"ABC"→Str1', ctx);
      expect(evalSource('dim(Str1)', ctx).asReal, 3);
      evalSource('[[1,2][3,4]]→[A]', ctx);
      final d = evalSource('dim([A])', ctx) as ListValue;
      expect(d.items.length, 2);
      evalSource('Fill(7,L1)', ctx);
      ctx.lists['L1'] = [1, 2];
      evalSource('Fill(7,L1)', ctx);
      expect(ctx.lists['L1'], [7, 7]);
      evalSource('Fill(9,[A])', ctx);
      expect(ctx.matrix('[A]')!.at(0, 0), 9);
    });

    test('random functions', () {
      int len(String src) =>
          (evalSource(src, CalcContext()) as ListValue).items.length;
      expect(eval('rand') >= 0, isTrue);
      expect(len('rand(3)'), 3);
      expect(eval('randInt(1,10)'), anything);
      expect(len('randInt(1,10,4)'), 4);
      expect(eval('randNorm(0,1)'), anything);
      expect(len('randNorm(0,1,3)'), 3);
      expect(eval('randBin(5,0.5)'), anything);
      expect(len('randBin(5,0.5,4)'), 4);
      expect(len('randIntNoRep(1,10,5)'), 5);
    });

    test('dates and clock', () {
      expect(eval('dayOfWk(2000,1,1)'), isNonZero);
      expect(eval('dbd(1.0125,2.0125)'), closeTo(31, 0.5));
      final t = evalSource('getTime()', CalcContext()) as ListValue;
      expect(t.items.length, 3);
      final d = evalSource('getDate()', CalcContext()) as ListValue;
      expect(d.items.length, 3);
    });

    test('solve with bounds list', () {
      expect(eval('solve(X²-4,X,3,{0,10})'), closeTo(2, 1e-6));
    });

    test('eq calls and undefined', () {
      final ctx = CalcContext();
      ctx.equation('Y1').expression = 'X²';
      expect(evalSource('Y1(3)', ctx).asReal, 9);
      expect(() => evalSource('Y7(3)', ctx), throwsA(anything));
    });
  });

  group('tvm branches', () {
    test('rate zero path', () {
      final t = TvmSolver()
        ..pmt = -50
        ..pv = 1000
        ..fv = 0
        ..i = 0;
      expect(t.solveN(), closeTo(20, 1e-6));
      expect(t.solvePmt(), closeTo(-50, 1e-9));
    });

    test('all field solves', () {
      final t = TvmSolver()
        ..n = 12
        ..i = 6
        ..pv = -1000
        ..fv = 1061.68
        ..pmt = 0;
      expect(t.solvePmt(), closeTo(0, 0.1));
      t
        ..fv = 0
        ..pmt = -50
        ..n = 24;
      expect(t.solvePv(), greaterThan(0));
      t.pv = -1000;
      expect(t.solveFv(), greaterThan(0));
      t
        ..n = 12
        ..i = 0
        ..pmt = 0
        ..pv = 0
        ..fv = 0;
      expect(t.solveI(), isA<double>());
    });
  });

  group('tokenizer edges', () {
    test('unterminated and odd tokens', () {
      expect(eval('2ᴇ3'), 2000);
      expect(eval('2ᴇ⁻2'), 0.02);
      expect(evalSource('{1,2}(1)', CalcContext()), isA<ListValue>());
      expect(eval('rand*2') < 2, isTrue);
    });
  });

  group('lcd split modes', () {
    testWidgets('G-T and HORIZ graph splits', (t) async {
      for (final mode in SplitMode.values) {
        final s = CalcState();
        s.modes.split = mode;
        s.ctx.equation('Y1').expression = 'X';
        s.press(KeyId.graph);
        await t.pumpWidget(MaterialApp(
            home: SizedBox(width: 320, height: 240, child: Lcd(state: s))));
        await t.pump();
        expect(find.byType(CustomPaint), findsWidgets);
      }
    });

    testWidgets('off screen and menu overlay', (t) async {
      final s = CalcState();
      s.press(KeyId.second);
      s.press(KeyId.on);
      await t.pumpWidget(MaterialApp(home: Lcd(state: s)));
      expect(find.byType(ColoredBox), findsWidgets);
      final s2 = CalcState();
      s2.press(KeyId.math);
      await t.pumpWidget(MaterialApp(home: Lcd(state: s2)));
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });
}
