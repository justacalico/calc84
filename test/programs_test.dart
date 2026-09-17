import 'package:calc84/engine/context.dart';
import 'package:calc84/engine/evaluator.dart';
import 'package:calc84/engine/format.dart';
import 'package:calc84/engine/program.dart';
import 'package:calc84/engine/tvm.dart';
import 'package:calc84/engine/value.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() => registerInlineEval(evalSource));

  group('program runner', () {
    ProgramRunner run(String src) {
      final r = ProgramRunner(src, CalcContext());
      r.run();
      return r;
    }

    test('Disp output', () {
      final r = run('Disp 1+2\nDisp "HI"');
      expect(r.io.lines, ['3', 'HI']);
      expect(r.io.done, isTrue);
    });

    test('If/Then/Else/End', () {
      final r = run('1→A\nIf A=1\nThen\nDisp "YES"\nElse\nDisp "NO"\nEnd');
      expect(r.io.lines, ['YES']);
    });

    test('single-line If', () {
      final r = run('0→A\nIf A=0\nDisp "ZERO"');
      expect(r.io.lines, ['ZERO']);
    });

    test('For loop', () {
      final r = run('For(I,1,5)\nDisp I\nEnd');
      expect(r.io.lines, ['1', '2', '3', '4', '5']);
    });

    test('While loop', () {
      final r = run('1→I\nWhile I≤3\nDisp I\nI+1→I\nEnd');
      expect(r.io.lines, ['1', '2', '3']);
    });

    test('Repeat loop', () {
      final r = run('0→I\nRepeat I>3\nI+1→I\nEnd\nDisp I');
      expect(r.io.lines, ['4']);
    });

    test('Goto and Lbl', () {
      final r = run('Goto B\nDisp "SKIP"\nLbl B\nDisp "DONE"');
      expect(r.io.lines, ['DONE']);
    });

    test('Input pauses and resumes', () {
      final r = ProgramRunner('Input X\nDisp X*2', CalcContext());
      r.run();
      expect(r.io.paused, isTrue);
      r.resume('21');
      expect(r.io.lines, ['42']);
    });

    test('Menu jumps to labels', () {
      final r = run('Menu("PICK","A",A,"B",B)\nLbl A\nDisp "A"\nStop\nLbl B\nDisp "B"');
      // Menu waits for selection.
      expect(r.io.paused, isTrue);
    });
  });

  group('TVM', () {
    test('solve for FV', () {
      final t = TvmSolver()
        ..n = 12
        ..i = 6
        ..pv = -1000
        ..pmt = 0;
      final fv = t.solve('FV');
      expect(fv, closeTo(1061.68, 0.01));
    });

    test('solve for PV round-trips', () {
      final t = TvmSolver()
        ..n = 24
        ..i = 5
        ..pmt = -50
        ..fv = 0;
      final pv = t.solve('PV');
      expect(pv, greaterThan(0));
      final t2 = TvmSolver()
        ..n = 24
        ..i = 5
        ..pv = pv
        ..pmt = -50
        ..fv = 0;
      expect(t2.solve('N'), closeTo(24, 0.01));
    });

    test('solve for I%', () {
      final t = TvmSolver()
        ..n = 12
        ..pv = -1000
        ..pmt = 0
        ..fv = 2000;
      expect(t.solve('I%'), closeTo(71.36, 0.05));
    });
  });

  group('format', () {
    test('float vs fixed decimals', () {
      final f = Formatter(DisplaySettings());
      expect(f.format(const RealValue(1.5)).lines, ['1.5']);
      f.settings.decimals = 2;
      expect(f.format(const RealValue(mathPi)).lines, ['3.14']);
    });

    test('sci notation', () {
      final f = Formatter(DisplaySettings()..notation = Notation.sci);
      expect(f.format(const RealValue(12345)).lines.first, contains('ᴇ'));
    });

    test('matrix grid output', () {
      final f = Formatter(DisplaySettings());
      final m = evalSource('[[1,2][3,4]]', CalcContext());
      final out = f.format(m);
      expect(out.matrixGrid, isNotNull);
      expect(out.matrixGrid!.length, 2);
    });

    test('list renders braces', () {
      final f = Formatter(DisplaySettings());
      final out = f.format(evalSource('{1,2,3}', CalcContext()));
      expect(out.lines.first, contains('{'));
    });
  });
}

const mathPi = 3.141592653589793;
