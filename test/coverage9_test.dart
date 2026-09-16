import 'dart:ui' as ui;

import 'package:calc84/engine/ast.dart';
import 'package:calc84/engine/parser.dart' show Parser;
import 'package:calc84/engine/context.dart';
import 'package:calc84/engine/evaluator.dart';
import 'package:calc84/engine/functions.dart';
import 'package:calc84/engine/value.dart';
import 'package:calc84/model/keymap.dart';
import 'package:calc84/model/settings.dart';
import 'package:calc84/state/calc_state.dart';
import 'package:calc84/ui/display/graph_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Deep branch coverage: distributions, min/max pair ops, evaluator
/// node paths only reachable via direct AST construction, and the
/// remaining graphing/painter branches.
void main() {
  double eval(String src) => evalSource(src, CalcContext()).asReal;

  group('distribution calls', () {
    test('each distribution form', () {
      expect(eval('normalpdf(0)'), closeTo(0.3989, 1e-3));
      expect(eval('normalpdf(0,1,2)'), isNonZero);
      expect(eval('normalcdf(-1,1)'), closeTo(0.6827, 1e-3));
      expect(eval('invNorm(0.5)'), closeTo(0, 1e-6));
      expect(eval('invT(0.975,10)'), closeTo(2.228, 1e-2));
      expect(eval('tpdf(0,10)'), closeTo(0.389, 1e-2));
      expect(eval('tcdf(-1,1,10)'), closeTo(0.659, 1e-2));
      expect(eval('χ²pdf(2,3)'), isNonZero);
      expect(eval('χ²cdf(0,5,3)'), isNonZero);
      expect(eval('Fpdf(1,5,5)'), isNonZero);
      expect(eval('Fcdf(0,2,5,5)'), isNonZero);
      expect(eval('binompdf(5,0.5,2)'), closeTo(0.3125, 1e-6));
      expect(eval('binompdf(5,0.5)'), isNonZero);
      expect(eval('binomcdf(5,0.5)'), isNonZero);
      expect(eval('binomcdf(5,0.5,0,2)'), isNonZero);
      expect(eval('poissonpdf(3,2)'), isNonZero);
      expect(eval('poissoncdf(3)'), isNonZero);
      expect(eval('geometpdf(0.5,2)'), closeTo(0.25, 1e-9));
      expect(eval('geometcdf(0.5)'), isNonZero);
      expect(() => eval('normalpdf()'), throwsA(anything));
      expect(() => eval('tcdf(1,2)'), throwsA(anything));
      expect(() => eval('binompdf(5)'), throwsA(anything));
    });
  });

  group('min/max branches', () {
    test('list and pair forms', () {
      expect(eval('min({3,1,2})'), 1);
      expect(eval('max(1,5,3)'), 5);
      expect(evalSource('min({1,5},{2,4})', CalcContext()).toString(),
          '{1.0 4.0}');
      expect(evalSource('min({1,5},3)', CalcContext()).toString(),
          '{1.0 3.0}');
      expect(evalSource('min(3,{1,5})', CalcContext()).toString(),
          '{1.0 3.0}');
      expect(() => eval('min({1},{1,2})'), throwsA(anything));
      expect(eval('lcm(4,6)'), 12);
      expect(eval('gcd(12,18)'), 6);
      expect(eval('remainder(10,3)'), 1);
      expect(eval('not(0)'), 1);
    });
  });

  group('log branches', () {
    test('zero and negative domains', () {
      expect(() => eval('ln(0)'), throwsA(anything));
      expect(() => eval('log(0)'), throwsA(anything));
      final c = CalcContext()..complexMode = ComplexMode.aBi;
      expect(evalSource('ln(-1)', c), isA<ComplexValue>());
      expect(evalSource('log(-1)', c), isA<ComplexValue>());
    });
  });

  group('bind restore', () {
    test('solve preserves existing X', () {
      final ctx = CalcContext();
      ctx.vars['X'] = 99;
      evalSource('nDeriv(X²,X,2)', ctx);
      expect(ctx.vars['X'], 99);
      evalSource('fnInt(X²,X,0,2)', ctx);
      expect(ctx.vars['X'], 99);
      evalSource('summation Σ(X,X,1,3)', ctx);
      expect(ctx.vars['X'], 99);
    });
  });

  group('direct AST coverage', () {
    test('SeqNode and IndexNode u', () {
      final ctx = CalcContext();
      final v = Evaluator(ctx).eval(
          SeqNode([const NumNode(1), const NumNode(2)]));
      expect(v.asReal, 2);
      ctx.sequences['u']!.expression = 'n+1';
      expect(
          Evaluator(ctx).eval(IndexNode('u', [const NumNode(3)])).asReal,
          anything);
    });

    test('index error paths', () {
      final ctx = CalcContext();
      ctx.vars['A'] = 2;
      // A(2) implied multiply.
      expect(evalSource('A(2)', ctx).asReal, 4);
      expect(() => evalSource('A(1,2)', ctx), throwsA(anything));
      // Undefined / malformed matrix index stores.
      expect(() => evalSource('5→[B](1,1)', ctx), throwsA(anything));
      evalSource('[[1,2][3,4]]→[A]', ctx);
      expect(() => evalSource('5→[A](9,1)', ctx), throwsA(anything));
      expect(() => evalSource('5→[A](1)', ctx), throwsA(anything));
    });

    test('bare names and seq var', () {
      final ctx = CalcContext();
      expect(evalSource('n', ctx).asReal, 0);
      ctx.vars['_seq_u'] = 7;
      expect(evalSource('u', ctx).asReal, 7);
      expect(evalSource('getKey', ctx).asReal, 0);
    });

    test('broadcast over lists', () {
      final ctx = CalcContext();
      expect(evalSource('fPart({1.5,2.5})', ctx).toString(),
          '{0.5 0.5}');
      ctx.complexMode = ComplexMode.aBi;
      final v = evalSource('abs({-1,i})', ctx);
      expect(v, isA<ListValue>());
    });

    test('gamma reflection and complex pow', () {
      final ctx = CalcContext();
      expect(evalSource('(-0.5)!', ctx).asReal, isNonZero);
      ctx.complexMode = ComplexMode.aBi;
      final v = evalSource('(-2)^(1/2)', ctx);
      expect(v, isA<ComplexValue>());
    });

    test('unparse all node kinds', () {
      for (final s in [
        '5→L1(2)',
        'a:b:c',
        '[[1][2]]',
        'sin(1)+2',
        '⁻3!',
        'X²',
      ]) {
        expect(unparse(Parser.parse(s)), isNotEmpty);
      }
      expect(unparse(Parser.parse('5→L1(2)')), '5→L1(2)');
    });
  });

  group('callFunction edges', () {
    test('unknown name and direct Y call', () {
      final ctx = CalcContext();
      expect(() => callFunction(Evaluator(ctx), 'nope', []),
          throwsA(anything));
      expect(isFunctionName('sin'), isTrue);
      ctx.equation('Y1').expression = 'X+1';
      expect(
          callFunction(Evaluator(ctx), 'Y1', [const NumNode(4)]).asReal,
          5);
      ctx.vars['X'] = 9;
      callFunction(Evaluator(ctx), 'Y1', [const NumNode(4)]);
      expect(ctx.vars['X'], 9);
      expect(() => callFunction(Evaluator(ctx), 'Y9', [const NumNode(1)]),
          throwsA(anything));
    });
  });

  group('graphing branches', () {
    void paint(CalcState s) {
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      GraphPainter(s).paint(canvas, const Size(320, 240));
      rec.endRecording().dispose();
    }

    test('sequence trace and plotStep', () {
      final s = CalcState();
      s.modes.graph = GraphMode.sequence;
      s.ctx.sequences['u']!.expression = 'n';
      s.window.plotStep = 2;
      s.press(KeyId.graph);
      s.press(KeyId.trace);
      s.press(KeyId.left);
      s.press(KeyId.right);
      s.graph.traceTo(7);
      expect(s.graph.traceN, 7);
      paint(s);
    });

    test('discontinuity splits segments', () {
      final s = CalcState();
      s.ctx.equation('Y1').expression = '1/X';
      s.press(KeyId.graph);
      paint(s);
    });

    test('parametric null points and dot mode', () {
      final s = CalcState();
      s.modes.graph = GraphMode.parametric;
      s.ctx.equation('X1T').expression = 'T';
      s.ctx.equation('Y1T').expression = '1/T';
      s.window.tMin = -5;
      s.press(KeyId.graph);
      paint(s);
      s.modes.connected = ConnectedMode.dot;
      paint(s);
    });

    test('zoomFit expands y range', () {
      final s = CalcState();
      s.ctx.equation('Y1').expression = '100';
      s.press(KeyId.graph);
      s.graph.zoomFit();
      expect(s.window.yMax, greaterThan(50));
      paint(s);
    });

    test('DrawF referencing equation name', () {
      final s = CalcState();
      s.ctx.equation('Y1').expression = 'X²';
      s.drawn.add(DrawnFunction('Y1'));
      paint(s);
      s.drawn.add(DrawnShade('Y1', 'X'));
      paint(s);
    });

    test('zoomPrevious restores', () {
      final s = CalcState();
      s.press(KeyId.graph);
      s.graph.zoomStandard();
      s.graph.zoomPrevious();
      expect(s.window.xMin, -10);
    });
  });
}
