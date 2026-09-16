import 'package:calc84/model/keymap.dart';
import 'package:calc84/model/screens.dart';
import 'package:calc84/model/settings.dart';
import 'package:calc84/state/calc_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// Remaining state paths: every zoom action, CALC value/dy/dx prompts,
/// table cell entry, list/matrix editor ops, regression StoreEq,
/// program resume errors, and eq-gutter toggles.
void main() {
  group('zoom actions', () {
    CalcState gs() {
      final s = CalcState();
      s.ctx.equation('Y1').expression = 'X²';
      s.press(KeyId.graph);
      return s;
    }

    void zoom(CalcState s, int item) {
      s.press(KeyId.zoom);
      for (var i = 0; i < item; i++) {
        s.press(KeyId.down);
      }
      s.press(KeyId.enter);
    }

    test('all zoom menu entries', () {
      final s = gs();
      // 1:ZBox needs a drag; enter starts box select.
      zoom(s, 0);
      s.press(KeyId.right);
      s.press(KeyId.down);
      s.press(KeyId.enter);
      s.press(KeyId.left);
      s.press(KeyId.up);
      s.press(KeyId.enter);
      zoom(s, 1); // Zoom In
      zoom(s, 2); // Zoom Out
      zoom(s, 3); // ZDecimal
      zoom(s, 4); // ZSquare
      zoom(s, 5); // ZStandard
      zoom(s, 6); // ZTrig
      zoom(s, 7); // ZInteger
      s.ctx.lists['L1'] = [1, 2, 3];
      s.plots[0].on = true;
      zoom(s, 8); // ZoomStat
      zoom(s, 9); // ZoomFit
      s.zoomAction('previous');
      s.zoomAction('store');
      s.zoomAction('recall');
      expect(s.screen, ScreenId.graph);
    });
  });

  group('calc value and dydx prompts', () {
    test('value prompt applies', () {
      final s = CalcState();
      s.ctx.equation('Y1').expression = 'X²';
      s.press(KeyId.graph);
      s.calcAction('value');
      s.insertText('3');
      s.press(KeyId.enter);
      expect(s.graph.markers.any((m) => m.label == 'Y='), isTrue);
    });

    test('dydx prompt applies', () {
      final s = CalcState();
      s.ctx.equation('Y1').expression = 'X²';
      s.press(KeyId.graph);
      s.calcAction('dydx');
      s.insertText('2');
      s.press(KeyId.enter);
      expect(s.graph.markers.isNotEmpty, isTrue);
    });

    test('prompt arrows move cursor and bad input errors', () {
      final s = CalcState();
      s.ctx.equation('Y1').expression = 'X²';
      s.press(KeyId.graph);
      s.calcAction('value');
      s.insertText('12');
      s.press(KeyId.left);
      s.insertText('0');
      s.press(KeyId.right);
      s.press(KeyId.enter);
      expect(s.graph.markers.isNotEmpty, isTrue);
      s.calcAction('value');
      s.insertText(')');
      s.press(KeyId.enter);
      expect(s.screen, ScreenId.error);
      s.press(KeyId.enter);
    });

    test('typed intersect bounds', () {
      final s = CalcState();
      s.ctx.equation('Y1').expression = 'X²';
      s.ctx.equation('Y2').expression = 'X';
      s.press(KeyId.graph);
      s.calcAction('intersect');
      s.insertText('0');
      s.press(KeyId.enter); // first curve
      s.insertText('0');
      s.press(KeyId.enter); // second curve
      s.insertText('0');
      s.press(KeyId.enter); // guess
      expect(s.graph.markers.any((m) => m.label == 'Intersection'),
          isTrue);
    });
  });

  group('table cell entry', () {
    test('typed X cells accumulate and edit', () {
      final s = CalcState();
      s.ctx.equation('Y1').expression = 'X²';
      s.indpntAsk = true;
      s.tblAskColX = true;
      s.press(KeyId.second);
      s.press(KeyId.graph);
      s.insertText('1');
      s.press(KeyId.enter);
      s.insertText('2');
      s.press(KeyId.enter);
      s.insertText('3');
      s.press(KeyId.enter);
      expect(s.tblAskXs.length, 3);
      s.press(KeyId.up);
      s.insertText('9');
      s.press(KeyId.enter);
      s.insertText('bad(');
      s.press(KeyId.enter);
      expect(s.screen, ScreenId.error);
      s.press(KeyId.enter);
    });
  });

  group('list editor ops', () {
    test('cell commit, name row, insert and delete', () {
      final s = CalcState();
      s.openListEditor();
      s.insertText('5');
      s.press(KeyId.enter);
      s.insertText('6');
      s.press(KeyId.enter);
      expect(s.ctx.list('L1'), [5, 6]);
      // Up to the column name to edit it.
      s.press(KeyId.up);
      s.press(KeyId.up);
      s.press(KeyId.up);
      // Delete element then clear column.
      s.press(KeyId.down);
      s.press(KeyId.del);
      s.press(KeyId.clear);
      s.quit();
    });
  });

  group('matrix editor resize', () {
    test('resize header commits', () {
      final s = CalcState();
      s.openMatrixEditor('[A]');
      s.insertText('3');
      s.press(KeyId.enter); // rows = 3
      s.insertText('3');
      s.press(KeyId.enter); // cols = 3, cursor lands on cell (0,0)
      expect(s.ctx.matrices['[A]']!.rows, 3);
      s.insertText('7');
      s.press(KeyId.enter);
      expect(s.ctx.matrices['[A]']!.at(0, 0), 7);
      s.quit();
    });
  });

  group('regression store-eq', () {
    test('LinReg with Y1 store builds equation', () {
      final s = CalcState();
      s.ctx.lists['L1'] = [1, 2, 3];
      s.ctx.lists['L2'] = [2, 4, 6];
      s.insertText('LinReg(ax+b) L1,L2,Y1');
      s.press(KeyId.enter);
      expect(s.ctx.equation('Y1').expression, isNotEmpty);
      s.insertText('ExpReg L1,L2,Y2');
      s.press(KeyId.enter);
      expect(s.ctx.equation('Y2').expression, contains('^X'));
      s.insertText('LnReg L1,L2,Y3');
      s.press(KeyId.enter);
      expect(s.ctx.equation('Y3').expression, contains('ln'));
      s.insertText('PwrReg L1,L2,Y4');
      s.press(KeyId.enter);
      expect(s.ctx.equation('Y4').expression, contains('X^'));
    });
  });

  group('program resume error', () {
    test('bad input during Input shows error', () {
      final s = CalcState();
      s.programs.add(Program('P', 'Input A\nDisp A'));
      s.insertText('prgmP');
      s.press(KeyId.enter);
      s.insertText('((');
      s.press(KeyId.enter);
      expect(s.screen, ScreenId.error);
      expect(s.running, isNull);
    });
  });

  group('eq gutter toggles', () {
    test('par pair toggles together', () {
      final s = CalcState();
      s.modes.graph = GraphMode.parametric;
      s.ctx.equation('X1T').expression = 'T';
      s.ctx.equation('Y1T').expression = 'T';
      s.press(KeyId.yEqu);
      s.press(KeyId.left);
      s.press(KeyId.left); // gutter
      s.press(KeyId.enter); // toggle off
      expect(s.ctx.equation('X1T').enabled, isFalse);
      expect(s.ctx.equation('Y1T').enabled, isFalse);
      s.quit();
    });

    test('seq rows and nMin edit', () {
      final s = CalcState();
      s.modes.graph = GraphMode.sequence;
      s.press(KeyId.yEqu);
      s.press(KeyId.left);
      s.press(KeyId.enter); // toggle u off
      expect(s.ctx.sequences['u']!.enabled, isFalse);
      s.press(KeyId.right);
      // down to u(nMin) row (index 3)
      for (var i = 0; i < 3; i++) {
        s.press(KeyId.down);
      }
      s.press(KeyId.del);
      s.press(KeyId.del);
      s.insertText('5');
      s.press(KeyId.enter);
      expect(s.ctx.sequences['u']!.initial.first, 5);
      s.quit();
    });
  });

  group('error screen digits', () {
    test('1 quits, 2 goes to entry', () {
      final s = CalcState();
      s.insertText('1/0');
      s.press(KeyId.enter);
      s.press(KeyId.n1);
      expect(s.screen, ScreenId.home);
      s.insertText('1/0');
      s.press(KeyId.enter);
      s.press(KeyId.n2);
      expect(s.screen, ScreenId.home);
    });
  });

  group('field commit error', () {
    test('bad window value shows error', () {
      final s = CalcState();
      s.press(KeyId.window);
      s.insertText('bad(');
      s.press(KeyId.enter);
      expect(s.screen, ScreenId.error);
      s.press(KeyId.enter);
      s.quit();
    });
  });
}
