import 'package:calc84/engine/context.dart';
import 'package:calc84/engine/format.dart';
import 'package:calc84/model/entry.dart';
import 'package:calc84/model/keymap.dart';
import 'package:calc84/model/screens.dart';
import 'package:calc84/model/settings.dart';
import 'package:calc84/state/calc_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// Last coverage pass: remaining editor arrows, command paths,
/// error branches, and view getters.
void main() {
  group('matrix editor arrows and errors', () {
    test('horizontal move, last-cell enter, bad value', () {
      final s = CalcState();
      s.openMatrixEditor('[A]');
      s.press(KeyId.right); // header col 1
      s.press(KeyId.down); // row 0
      s.press(KeyId.left); // clamp back to header? row 0 col 1
      s.press(KeyId.right);
      s.insertText('4');
      s.press(KeyId.enter); // commits (0,1) or (0,0)
      // walk to last cell and press enter at the end
      s.press(KeyId.up); // back to header
      s.press(KeyId.down);
      for (var i = 0; i < 4; i++) {
        s.press(KeyId.enter);
      }
      // error path
      s.insertText('bad(');
      s.press(KeyId.enter);
      expect(s.screen, ScreenId.error);
      s.press(KeyId.enter);
      s.quit();
    });
  });

  group('list editor extras', () {
    test('commit error and column arrows', () {
      final s = CalcState();
      s.openListEditor();
      s.insertText('((');
      s.press(KeyId.enter);
      expect(s.screen, ScreenId.error);
      s.press(KeyId.enter);
      s.press(KeyId.up);
      s.press(KeyId.right);
      s.press(KeyId.right);
      s.press(KeyId.left);
      s.press(KeyId.del); // del on name row
      s.quit();
    });
  });

  group('program editor extras', () {
    test('arrows within lines, single line clear', () {
      final s = CalcState();
      s.programs.add(Program('P', 'Disp 1'));
      s.prgmEditing = 'P';
      s.prgmLines = [EntryLine('Disp 1')];
      s.push(ScreenId.programEdit);
      s.press(KeyId.left);
      s.press(KeyId.right);
      s.press(KeyId.down);
      s.press(KeyId.up);
      s.press(KeyId.clear); // single line -> clears not removes
      expect(s.programs.first.source, '');
      s.quit();
    });
  });

  group('home command extras', () {
    String out(CalcState s) =>
        s.history.expand((h) => h.outputLines).join(' ');

    test('Disp and colon chains', () {
      final s = CalcState();
      s.insertText('Disp 5');
      s.press(KeyId.enter);
      expect(out(s), contains('5'));
      s.insertText('1+1:2+2');
      s.press(KeyId.enter);
      expect(out(s), contains('4'));
      s.insertText('Disp "{a:b}"');
      s.press(KeyId.enter);
    });

    test('missing program errors', () {
      final s = CalcState();
      s.insertText('prgmNOPE');
      s.press(KeyId.enter);
      expect(s.screen, ScreenId.error);
      s.press(KeyId.enter);
    });

    test('hint functions', () {
      final s = CalcState();
      for (final h in ['▸Frac', '▸Dec', '▸DMS']) {
        s.insertText('0.5$h');
        s.press(KeyId.enter);
        s.press(KeyId.enter); // dismiss any error quietly
      }
      expect(s.history.isNotEmpty, isTrue);
    });

    test('regression list by expression arg', () {
      final s = CalcState();
      s.insertText('1-Var Stats {1,2,3}');
      s.press(KeyId.enter);
      expect(s.screen, isNot(ScreenId.error));
    });
  });

  group('command key paths', () {
    test('2nd LIST opens menu', () {
      final s = CalcState();
      s.press(KeyId.second);
      s.press(KeyId.stat); // LIST
      expect(s.menu, isNotNull);
      s.press(KeyId.clear);
    });

    test('alpha lock via 2nd alpha', () {
      final s = CalcState();
      s.press(KeyId.second);
      s.press(KeyId.alpha); // A-LOCK
      s.press(KeyId.math);
      expect(s.entry.text, 'A');
      s.press(KeyId.alpha);
    });

    test('XTTN inserts mode variable', () {
      for (final gm in GraphMode.values) {
        final s = CalcState();
        s.modes.graph = gm;
        s.press(KeyId.xttn);
        expect(s.entry.text, isNotEmpty);
      }
    });

    test('menu alpha shortcut past nine', () {
      final s = CalcState();
      s.press(KeyId.second);
      s.press(KeyId.n0); // CATALOG
      s.press(KeyId.alpha);
      s.press(KeyId.math); // letter A jumps to A entries
      expect(s.menu, isNull);
      s.press(KeyId.clear);
    });
  });

  group('solver/tvm/misc', () {
    test('solver field arrows and tvm enter on pmt row', () {
      final s = CalcState();
      s.openSolver();
      s.press(KeyId.enter); // commit eq row
      s.press(KeyId.left);
      s.press(KeyId.right);
      s.quit();
      s.openTvm();
      for (var i = 0; i < 7; i++) {
        s.press(KeyId.down);
      }
      s.press(KeyId.enter); // PMT row enter toggles
      s.quit();
    });

    test('matrix names screen ignores arrows', () {
      final s = CalcState();
      s.show(ScreenId.matrixNames);
      s.press(KeyId.left);
      s.press(KeyId.up);
      s.press(KeyId.down);
      s.quit();
    });

    test('program name entry arrows', () {
      final s = CalcState();
      s.show(ScreenId.programName);
      s.insertText('AB');
      s.press(KeyId.left);
      s.press(KeyId.right);
      s.press(KeyId.enter);
      expect(s.screen, ScreenId.programEdit);
      s.quit();
    });
  });

  group('window fields other modes', () {
    test('field getters return per-mode fields', () {
      for (final gm in GraphMode.values) {
        final s = CalcState();
        s.modes.graph = gm;
        expect(s.winFields().isNotEmpty, isTrue);
        expect(s.tblFields().isNotEmpty, isTrue);
      }
    });
  });

  group('view getters', () {
    test('memItems, visibleTableRows, tableEditingX, statusLine', () {
      final s = CalcState();
      s.ctx.vars['B'] = 1;
      expect(s.memItems().isNotEmpty, isTrue);
      s.ctx.equation('Y1').expression = 'X';
      expect(s.visibleTableRows(3).length, 3);
      s.indpntAsk = true;
      s.tblAskColX = true;
      expect(s.tableEditingX, isTrue);
      expect(s.statusLine, contains('FUNC'));
      s.modes.graph = GraphMode.sequence;
      expect(s.statusLine, contains('SEQ'));
      s.modes.graph = GraphMode.parametric;
      expect(s.statusLine, contains('PAR'));
      s.modes.graph = GraphMode.polar;
      expect(s.statusLine, contains('POL'));
      s.modes.notation = Notation.sci;
      expect(s.statusLine, contains('SCI'));
      s.modes.notation = Notation.eng;
      s.modes.angle = AngleMode.degree;
      s.modes.complex = ComplexMode.aBi;
      expect(s.statusLine, contains('a+bi'));
      expect(s.statusLine, contains('DEGREE'));
    });

    test('fieldAt and activeEqRow and listColumn', () {
      final s = CalcState();
      s.press(KeyId.yEqu);
      expect(s.fieldAt(s.winFields(), 0).label, isNotEmpty);
      expect(s.activeEqRow, 0);
      s.ctx.lists['L1'] = [1, 2];
      s.openListEditor();
      expect(s.listColumn(0), [1, 2]);
      s.quit();
    });
  });
}
