import 'package:calc84/model/entry.dart';
import 'package:calc84/model/keymap.dart';
import 'package:calc84/model/screens.dart';
import 'package:calc84/model/settings.dart';
import 'package:calc84/state/calc_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// Final coverage sweep over editor navigation, program list tabs,
/// menu tabs, solver/tvm runs, and clear-key variants.
void main() {
  group('tblset toggles', () {
    test('indpnt and depend ask rows toggle', () {
      final s = CalcState();
      s.press(KeyId.second);
      s.press(KeyId.window);
      // Rows 2 and 3 are the AUTO/ASK toggles.
      s.press(KeyId.down);
      s.press(KeyId.down);
      s.press(KeyId.enter);
      expect(s.indpntAsk, isTrue);
      s.press(KeyId.down);
      s.press(KeyId.enter);
      expect(s.dependAsk, isTrue);
      s.press(KeyId.up);
      s.press(KeyId.enter);
      s.quit();
    });
  });

  group('list editor navigation', () {
    test('arrows move across columns and name row', () {
      final s = CalcState();
      s.openListEditor();
      s.insertText('1');
      s.press(KeyId.enter);
      s.press(KeyId.right);
      s.insertText('2');
      s.press(KeyId.enter);
      expect(s.ctx.list('L2'), [2]);
      s.press(KeyId.left);
      s.press(KeyId.up);
      s.press(KeyId.up); // name row
      s.insertText('MYLIST');
      s.press(KeyId.enter);
      s.press(KeyId.down);
      s.quit();
    });
  });

  group('program list tabs', () {
    test('exec edit and new flows', () {
      final s = CalcState();
      s.programs.add(Program('AA', 'Disp 1'));
      s.press(KeyId.prgm);
      expect(s.screen, ScreenId.programList);
      s.press(KeyId.enter); // EXEC runs it
      expect(s.history.expand((h) => h.outputLines).join(), contains('1'));
      // EDIT tab
      s.press(KeyId.prgm);
      s.press(KeyId.right);
      s.press(KeyId.enter);
      expect(s.screen, ScreenId.programEdit);
      s.press(KeyId.right);
      s.press(KeyId.left);
      s.press(KeyId.down);
      s.quit();
      // NEW tab
      s.press(KeyId.prgm);
      s.press(KeyId.right);
      s.press(KeyId.right);
      s.press(KeyId.enter);
      expect(s.screen, ScreenId.programName);
      s.insertText('NEWPRG');
      s.press(KeyId.enter);
      expect(s.screen, ScreenId.programEdit);
      s.quit();
    });

    test('empty list goes straight to name', () {
      final s = CalcState();
      s.press(KeyId.prgm);
      s.press(KeyId.right);
      s.press(KeyId.right);
      s.press(KeyId.enter);
      expect(s.screen, ScreenId.programName);
      s.quit();
    });
  });

  group('menu tab navigation', () {
    test('left right switch tabs and digit shortcuts', () {
      final s = CalcState();
      s.press(KeyId.math);
      s.press(KeyId.right);
      s.press(KeyId.right);
      s.press(KeyId.left);
      expect(s.menu, isNotNull);
      // digit shortcut selects item
      s.press(KeyId.n1);
      expect(s.entry.text, isNotEmpty);
      s.press(KeyId.clear);
      s.press(KeyId.math);
      s.press(KeyId.up); // wraps cursor
      s.press(KeyId.enter);
      s.press(KeyId.clear);
    });
  });

  group('solver run', () {
    test('solve eqn=0 via alpha enter', () {
      final s = CalcState();
      s.openSolver();
      s.insertText('X-7');
      s.press(KeyId.enter);
      s.insertText('0');
      s.press(KeyId.enter);
      s.press(KeyId.up);
      s.press(KeyId.up);
      s.press(KeyId.alpha);
      s.press(KeyId.enter);
      expect(s.solverX.text, '7');
      s.quit();
    });
  });

  group('tvm run via alpha+enter', () {
    test('solve I% with keys', () {
      final s = CalcState();
      s.openTvm();
      for (final v in ['10', '0', '-900', '100', '0']) {
        s.insertText(v);
        s.press(KeyId.enter);
      }
      s.press(KeyId.enter); // P/Y
      s.press(KeyId.enter); // C/Y
      for (var i = 0; i < 7; i++) {
        s.press(KeyId.up);
      }
      s.press(KeyId.down); // I% row
      s.press(KeyId.alpha);
      s.press(KeyId.enter);
      expect(s.tvm.i, greaterThan(0));
      s.quit();
    });

    test('horizontal arrows toggle pmt row', () {
      final s = CalcState();
      s.openTvm();
      for (var i = 0; i < 7; i++) {
        s.press(KeyId.down);
      }
      s.press(KeyId.right);
      expect(s.tvm.pmtEnd, isFalse);
      s.press(KeyId.left);
      expect(s.tvm.pmtEnd, isTrue);
      s.quit();
    });
  });

  group('clear key variants', () {
    test('clear on list edit removes cell', () {
      final s = CalcState();
      s.ctx.lists['L1'] = [9, 9, 9];
      s.openListEditor();
      s.press(KeyId.clear);
      expect(s.ctx.list('L1').length, 2);
      s.quit();
    });

    test('clear on window edit empties field', () {
      final s = CalcState();
      s.press(KeyId.window);
      s.press(KeyId.clear);
      expect(s.winFields()[0].line.isEmpty, isTrue);
      s.quit();
    });

    test('clear on program edit removes line', () {
      final s = CalcState();
      s.programs.add(Program('P', 'Disp 1\nDisp 2\nDisp 3'));
      s.prgmEditing = 'P';
      s.prgmLines = [
        for (final l in 'Disp 1\nDisp 2\nDisp 3'.split('\n'))
          EntryLine(l)
      ];
      s.push(ScreenId.programEdit);
      s.press(KeyId.clear);
      expect(s.programs.first.source.split('\n').length, 2);
      s.quit();
    });

    test('clear on graph exits overlay', () {
      final s = CalcState();
      s.ctx.equation('Y1').expression = 'X';
      s.press(KeyId.graph);
      s.press(KeyId.trace);
      s.press(KeyId.clear);
      expect(s.graph.tracing, isFalse);
      s.quit();
    });
  });

  group('history scrolling', () {
    test('up cycles through entries and pastes', () {
      final s = CalcState();
      s.insertText('2+2');
      s.press(KeyId.enter);
      s.insertText('3+3');
      s.press(KeyId.enter);
      s.press(KeyId.up);
      s.press(KeyId.up);
      s.press(KeyId.enter); // paste 2+2
      expect(s.entry.text, '2+2');
      s.press(KeyId.clear);
      s.press(KeyId.up);
      s.press(KeyId.down);
    });
  });

  group('rcl paths', () {
    test('rcl var string and equation', () {
      final s = CalcState();
      s.ctx.vars['A'] = 42;
      s.ctx.strings['Str1'] = 'HI';
      s.ctx.equation('Y1').expression = 'X²';
      for (final n in ['A', 'Str1', 'Y1']) {
        s.press(KeyId.second);
        s.press(KeyId.sto);
        s.insertText(n);
        expect(s.entry.text.isNotEmpty, isTrue);
        s.press(KeyId.clear);
      }
    });
  });

  group('graph arrows pan without prompt', () {
    test('cursor moves and zoom box selects', () {
      final s = CalcState();
      s.ctx.equation('Y1').expression = 'X²';
      s.press(KeyId.graph);
      s.press(KeyId.right);
      s.press(KeyId.left);
      s.press(KeyId.up);
      s.press(KeyId.down);
      s.press(KeyId.zoom);
      s.press(KeyId.enter); // ZBox
      s.press(KeyId.right);
      s.press(KeyId.right);
      s.press(KeyId.enter); // first corner
      s.press(KeyId.left);
      s.press(KeyId.down);
      s.press(KeyId.enter); // second corner zooms
      expect(s.screen, ScreenId.graph);
    });
  });

  group('calc via cursor enters', () {
    test('zero found by cursor bounds', () {
      final s = CalcState();
      s.ctx.equation('Y1').expression = 'X²-4';
      s.press(KeyId.graph);
      s.calcAction('zero');
      // Move cursor left of the root then bound it.
      for (var i = 0; i < 30; i++) {
        s.press(KeyId.left);
      }
      s.press(KeyId.enter); // left bound
      for (var i = 0; i < 10; i++) {
        s.press(KeyId.right);
      }
      s.press(KeyId.enter); // right bound
      s.press(KeyId.enter); // guess
      expect(s.graph.markers.any((m) => m.label == 'Zero'), isTrue);
    });

    test('minimum and maximum via cursor', () {
      final s = CalcState();
      s.ctx.equation('Y1').expression = 'X²-4';
      s.press(KeyId.graph);
      s.calcAction('min');
      s.press(KeyId.left);
      s.press(KeyId.enter);
      s.press(KeyId.right);
      s.press(KeyId.right);
      s.press(KeyId.enter);
      s.press(KeyId.enter);
      expect(s.graph.markers.any((m) => m.label == 'Minimum'), isTrue);
    });

    test('integral via cursor', () {
      final s = CalcState();
      s.ctx.equation('Y1').expression = 'X';
      s.press(KeyId.graph);
      s.calcAction('int');
      s.press(KeyId.enter);
      s.press(KeyId.right);
      s.press(KeyId.right);
      s.press(KeyId.enter);
      s.press(KeyId.enter);
      expect(s.graph.markers.isNotEmpty, isTrue);
    });

    test('intersect via cursor enters', () {
      final s = CalcState();
      s.ctx.equation('Y1').expression = 'X';
      s.ctx.equation('Y2').expression = '2-X';
      s.press(KeyId.graph);
      s.calcAction('intersect');
      s.press(KeyId.enter); // first curve
      s.press(KeyId.enter); // second curve
      s.press(KeyId.enter); // guess
      expect(
          s.graph.markers.any((m) => m.label == 'Intersection'), isTrue);
    });
  });
}
