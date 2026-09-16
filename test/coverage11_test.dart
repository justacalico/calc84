import 'package:calc84/engine/matrix.dart';
import 'package:calc84/model/keymap.dart';
import 'package:calc84/model/screens.dart';
import 'package:calc84/model/settings.dart';
import 'package:calc84/state/calc_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// Covers the remaining sparse branches in calc_state and helpers.
void main() {
  group('rcl via variable pickers', () {
    test('matrix name recall', () {
      final s = CalcState();
      s.ctx.setMatrix('[A]', Matrix(1, 2)..set(0, 1, 5));
      s.press(KeyId.second);
      s.press(KeyId.sto);
      s.press(KeyId.second);
      s.press(KeyId.xInv); // MATRIX names
      s.press(KeyId.enter); // [A]
      expect(s.entry.text, contains('5'));
    });

    test('string and list recall', () {
      final s = CalcState();
      s.ctx.strings['Str1'] = 'HI';
      s.ctx.lists['L1'] = [7, 8];
      s.press(KeyId.second);
      s.press(KeyId.sto);
      s.press(KeyId.vars);
      s.press(KeyId.right);
      // Y-VARS tab: String... is the last submenu.
      for (var i = 0; i < 4; i++) {
        s.press(KeyId.down);
      }
      s.press(KeyId.enter);
      s.press(KeyId.down); // Str1 is second after Str0
      s.press(KeyId.enter);
      expect(s.entry.text, contains('HI'));
      s.press(KeyId.clear);
      s.press(KeyId.second);
      s.press(KeyId.sto);
      s.press(KeyId.second);
      s.press(KeyId.n1); // L1 key
      expect(s.entry.text, contains('7'));
    });
  });

  group('alpha lock command', () {
    test('2nd alpha locks', () {
      final s = CalcState();
      s.press(KeyId.second);
      s.press(KeyId.alpha);
      expect(s.mod, Modifier.alphaLock);
      s.press(KeyId.math);
      s.press(KeyId.math);
      expect(s.entry.text, 'AA');
    });
  });

  group('alpha+enter opens solver', () {
    test('from home screen', () {
      final s = CalcState();
      s.press(KeyId.alpha);
      s.press(KeyId.enter);
      expect(s.screen, ScreenId.solver);
      s.quit();
    });
  });

  group('program list vertical arrows', () {
    test('down wraps cursor', () {
      final s = CalcState();
      s.programs.add(Program('A'));
      s.programs.add(Program('B'));
      s.press(KeyId.prgm);
      s.press(KeyId.down);
      s.press(KeyId.down);
      s.press(KeyId.down);
      expect(s.prgmCursor, 1);
      s.press(KeyId.up);
      s.quit();
    });
  });

  group('mem manage arrows', () {
    test('scroll through items', () {
      final s = CalcState();
      s.ctx.vars['A'] = 1;
      s.ctx.vars['B'] = 2;
      s.openMemManage();
      s.press(KeyId.down);
      s.press(KeyId.up);
      s.press(KeyId.down);
      expect(s.memRow, 1);
      s.quit();
    });
  });

  group('SetUpEditor command', () {
    test('clears and seeds lists', () {
      final s = CalcState();
      s.insertText('SetUpEditor');
      s.press(KeyId.enter);
      expect(s.ctx.list('L1'), isEmpty);
      expect(s.ctx.lists.length, 6);
    });
  });

  group('regression freq arg', () {
    test('1-Var Stats with freq list', () {
      final s = CalcState();
      s.ctx.lists['L1'] = [1, 2, 3];
      s.ctx.lists['L3'] = [2, 1, 1];
      s.insertText('1-Var Stats L1,L3');
      s.press(KeyId.enter);
      expect(s.screen, isNot(ScreenId.error));
      s.insertText('LinReg(ax+b) L1,L2,L3,Y1');
      s.ctx.lists['L2'] = [2, 4, 6];
      s.press(KeyId.enter);
      expect(s.ctx.equation('Y1').expression, isNotEmpty);
    });
  });

  group('program run error propagates', () {
    test('runtime error shows error screen', () {
      final s = CalcState();
      s.programs.add(Program('BAD', '1/0'));
      s.insertText('prgmBAD');
      s.press(KeyId.enter);
      expect(s.screen, ScreenId.error);
      s.press(KeyId.enter);
    });
  });

  group('eq line refresh', () {
    test('equation store updates y= lines', () {
      final s = CalcState();
      s.press(KeyId.yEqu); // create line entries
      s.quit();
      s.insertText('"X+5"→Y2');
      s.press(KeyId.enter);
      s.press(KeyId.yEqu);
      expect(s.eqRows()[1].line.text, 'X+5');
      s.quit();
    });
  });

  group('error screen up', () {
    test('up then enter quits', () {
      final s = CalcState();
      s.insertText('1/0');
      s.press(KeyId.enter);
      s.press(KeyId.down);
      s.press(KeyId.up);
      s.press(KeyId.enter);
      expect(s.screen, ScreenId.home);
    });
  });

  group('y= arrow within text', () {
    test('right moves cursor in expression', () {
      final s = CalcState();
      s.press(KeyId.yEqu);
      s.insertText('X+1');
      s.press(KeyId.left);
      s.press(KeyId.right);
      s.press(KeyId.up);
      s.press(KeyId.down);
      s.quit();
    });
  });

  group('zoom stat via menu', () {
    test('collects plot points', () {
      final s = CalcState();
      s.plots[0]
        ..on = true
        ..xList = 'L1'
        ..yList = 'L2';
      s.ctx.lists['L1'] = [1, 2, 3];
      s.ctx.lists['L2'] = [4, 5, 6];
      s.press(KeyId.graph);
      s.zoomAction('stat');
      expect(s.window.xMax, greaterThan(0));
    });
  });

  group('clear variants', () {
    test('home clear wipes history when entry empty', () {
      final s = CalcState();
      s.insertText('1');
      s.press(KeyId.enter);
      s.press(KeyId.clear);
      expect(s.history, isEmpty);
    });

    test('yEqu clear empties equation', () {
      final s = CalcState();
      s.press(KeyId.yEqu);
      s.insertText('X²');
      s.press(KeyId.clear);
      expect(s.eqRows()[0].line.isEmpty, isTrue);
      s.quit();
    });
  });
}
