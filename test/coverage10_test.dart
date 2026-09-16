import 'package:calc84/engine/matrix.dart';
import 'package:calc84/model/keymap.dart';
import 'package:calc84/model/screens.dart';
import 'package:calc84/model/settings.dart';
import 'package:calc84/state/calc_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// Final sweep over the last uncovered branches: reset, trace arrows,
/// rcl matrix, tvm/solver field arrows, and error paths.
void main() {
  group('reset and clear', () {
    test('resetAll restores defaults', () {
      final s = CalcState();
      s.ctx.vars['A'] = 9;
      s.drawn.add(DrawnPt(1, 1, true));
      s.programs.add(Program('X'));
      s.resetAll();
      expect(s.ctx.vars, isEmpty);
      expect(s.drawn, isEmpty);
      expect(s.programs, isEmpty);
      s.clearEntries();
      expect(s.history, isEmpty);
    });
  });

  group('rcl matrix and eq', () {
    test('rcl pastes matrix and equation text', () {
      final s = CalcState();
      s.ctx.setMatrix('[A]', Matrix(2, 2)..set(0, 0, 5));
      s.ctx.equation('Y1').expression = 'X²';
      s.press(KeyId.second);
      s.press(KeyId.sto);
      s.insertText('[A]');
      expect(s.entry.text, contains('[A]'));
      s.press(KeyId.clear);
      s.press(KeyId.second);
      s.press(KeyId.sto);
      // RCL through the VARS menu pastes the equation text.
      s.press(KeyId.vars);
      s.press(KeyId.right); // Y-VARS tab
      s.press(KeyId.enter); // Function...
      s.press(KeyId.enter); // Y1
      expect(s.entry.text, contains('X²'));
    });
  });

  group('trace arrows', () {
    test('up down switch curves while tracing', () {
      final s = CalcState();
      s.ctx.equation('Y1').expression = 'X';
      s.ctx.equation('Y2').expression = 'X²';
      s.press(KeyId.graph);
      s.press(KeyId.trace);
      s.press(KeyId.up);
      s.press(KeyId.down);
      s.press(KeyId.left);
      s.press(KeyId.right);
    });
  });

  group('tvm field arrows and commit error', () {
    test('left right inside a field, bad commit', () {
      final s = CalcState();
      s.openTvm();
      s.insertText('12');
      s.press(KeyId.left);
      s.press(KeyId.right);
      s.press(KeyId.down);
      s.insertText('bad(');
      s.press(KeyId.down); // commit fails -> error
      expect(s.screen, ScreenId.error);
      s.press(KeyId.enter);
      s.quit();
    });

    test('solve fails cleanly', () {
      final s = CalcState();
      s.openTvm();
      // All zeros: solving N with no pmt is impossible.
      s.press(KeyId.alpha);
      s.press(KeyId.enter);
      expect(s.screen, ScreenId.error);
      s.press(KeyId.enter);
      s.quit();
    });
  });

  group('matrix editing arrow while editing', () {
    test('arrow commits cell mid-edit', () {
      final s = CalcState();
      s.openMatrixEditor('[A]');
      s.press(KeyId.down);
      s.insertText('8');
      s.press(KeyId.right); // commits then moves
      expect(s.ctx.matrices['[A]']!.at(0, 0), 8);
      s.quit();
    });
  });

  group('eq commit in seq mode', () {
    test('typing on u row stores expression', () {
      final s = CalcState();
      s.modes.graph = GraphMode.sequence;
      s.press(KeyId.yEqu);
      s.insertText('n+1');
      s.press(KeyId.enter);
      expect(s.ctx.sequences['u']!.expression, 'n+1');
      s.quit();
    });
  });

  group('solver arrows', () {
    test('arrows and alpha solve on bounds rows', () {
      final s = CalcState();
      s.openSolver();
      s.insertText('X²-9');
      s.press(KeyId.enter);
      s.press(KeyId.left);
      s.press(KeyId.right);
      s.insertText('5');
      s.press(KeyId.enter);
      s.insertText('{-10,10}');
      s.press(KeyId.enter);
      s.press(KeyId.up);
      s.press(KeyId.up);
      s.press(KeyId.alpha);
      s.press(KeyId.enter);
      expect(double.parse(s.solverX.text), closeTo(3, 1e-6));
      s.quit();
    });
  });

  group('link screen', () {
    test('enter on a link item errors', () {
      final s = CalcState();
      s.press(KeyId.second);
      s.press(KeyId.xttn);
      s.press(KeyId.down);
      s.press(KeyId.enter);
      expect(s.screen, ScreenId.error);
      s.press(KeyId.enter);
    });
  });

  group('misc uncovered', () {
    test('del on empty entry and mode row select col clamp', () {
      final s = CalcState();
      s.press(KeyId.del);
      expect(s.entry.text, '');
      s.press(KeyId.mode);
      s.modeSelect(1, 3); // decimals row
      expect(s.modes.decimals, 2);
      s.quit();
    });

    test('second+enter on home does nothing harmful', () {
      final s = CalcState();
      s.insertText('1');
      s.press(KeyId.second);
      s.press(KeyId.enter);
      expect(s.screen, ScreenId.home);
    });

    test('clear on tvm and solver pops', () {
      final s = CalcState();
      s.openTvm();
      s.press(KeyId.clear);
      expect(s.screen, ScreenId.home);
      s.openSolver();
      s.press(KeyId.clear);
      expect(s.screen, ScreenId.home);
    });
  });
}
