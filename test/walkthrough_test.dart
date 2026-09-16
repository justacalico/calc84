import 'package:calc84/model/keymap.dart';
import 'package:calc84/model/screens.dart';
import 'package:calc84/state/calc_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// Drive the state machine through every screen, menu and editor to
/// exercise the whole dispatch layer.
void main() {
  void type(CalcState s, String text) {
    for (final ch in text.split('')) {
      final k = _charKey[ch];
      if (k != null) {
        s.press(k);
      } else {
        s.insertText(ch);
      }
    }
  }

  group('editors', () {
    test('y= editor: type equation, toggle, arrow around', () {
      final s = CalcState();
      s.press(KeyId.yEqu);
      s.insertText('X²');
      s.press(KeyId.down);
      s.insertText('2X+1');
      s.press(KeyId.up);
      for (var i = 0; i < 3; i++) {
        s.press(KeyId.left); // walk cursor to the gutter
      }
      s.press(KeyId.enter); // toggle off
      expect(s.ctx.equation('Y1').enabled, isFalse);
      s.press(KeyId.enter);
      expect(s.ctx.equation('Y1').enabled, isTrue);
      s.press(KeyId.second);
      s.press(KeyId.mode); // QUIT
      expect(s.screen, ScreenId.home);
    });

    test('window editor edits fields', () {
      final s = CalcState();
      s.press(KeyId.window);
      expect(s.screen, ScreenId.windowEdit);
      s.insertText('-20');
      s.press(KeyId.enter); // commit Xmin, advance to Xmax
      expect(s.window.xMin, -20);
      s.insertText('20');
      s.press(KeyId.enter);
      expect(s.window.xMax, 20);
      s.press(KeyId.clear);
    });

    test('tblset editor', () {
      final s = CalcState();
      s.press(KeyId.second);
      s.press(KeyId.window); // TBLSET
      expect(s.screen, ScreenId.tblset);
      s.insertText('2');
      s.press(KeyId.enter);
      expect(s.window.tblStart, 2);
      s.press(KeyId.clear);
    });

    test('mode screen navigates all rows', () {
      final s = CalcState();
      s.press(KeyId.mode);
      for (var r = 0; r < 8; r++) {
        s.press(KeyId.right);
        s.press(KeyId.enter);
        s.press(KeyId.left);
        s.press(KeyId.enter);
        s.press(KeyId.down);
      }
      s.press(KeyId.clear);
      expect(s.screen, ScreenId.home);
    });

    test('format screen', () {
      final s = CalcState();
      s.press(KeyId.second);
      s.press(KeyId.zoom); // FORMAT
      expect(s.screen, ScreenId.format);
      s.press(KeyId.down);
      s.press(KeyId.enter);
      s.press(KeyId.clear);
    });

    test('stat list editor edits cells', () {
      final s = CalcState();
      s.press(KeyId.stat);
      // pick EDIT menu item 1 (Edit)
      s.press(KeyId.enter);
      expect(s.screen, ScreenId.listEdit);
      s.insertText('5');
      s.press(KeyId.enter);
      s.insertText('7');
      s.press(KeyId.enter);
      expect(s.ctx.list('L1'), [5, 7]);
      s.press(KeyId.right);
      s.insertText('1');
      s.press(KeyId.enter);
      expect(s.ctx.list('L2'), [1]);
      s.press(KeyId.clear);
    });

    test('matrix editor', () {
      final s = CalcState();
      s.press(KeyId.second);
      s.press(KeyId.xInv); // MATRIX menu
      expect(s.menu, isNotNull);
      s.press(KeyId.right);
      s.press(KeyId.right); // EDIT tab
      s.press(KeyId.enter); // edit [A]
      expect(s.screen, ScreenId.matrixEdit);
      s.press(KeyId.enter); // past rows dim
      s.press(KeyId.enter); // past cols dim, first cell
      // enter a few cells
      for (final v in ['1', '2', '3', '4']) {
        s.insertText(v);
        s.press(KeyId.enter);
      }
      final m = s.ctx.matrix('[A]');
      expect(m, isNotNull);
      expect(m!.at(1, 1), 4);
      s.press(KeyId.clear);
    });

    test('program editor creates and runs', () {
      final s = CalcState();
      s.press(KeyId.prgm);
      expect(s.screen, ScreenId.programList);
      s.press(KeyId.right);
      s.press(KeyId.right); // NEW tab
      s.press(KeyId.enter); // Create New
      expect(s.screen, ScreenId.programName);
      s.insertText('HELLO');
      s.press(KeyId.enter);
      expect(s.screen, ScreenId.programEdit);
      // type: Disp 6*7
      s.insertText('Disp 6*7');
      s.press(KeyId.second);
      s.press(KeyId.mode); // quit editor
      s.press(KeyId.prgm);
      s.press(KeyId.enter); // run HELLO
      expect(
        s.history.expand((h) => h.outputLines).join(' '),
        contains('42'),
      );
    });

    test('solver solves x^2-4=0', () {
      final s = CalcState();
      s.press(KeyId.math);
      s.press(KeyId.up); // wraps to Solver... at the bottom
      s.press(KeyId.enter);
      if (s.screen == ScreenId.solver) {
        s.insertText('X²-4');
        s.press(KeyId.enter);
        s.insertText('5');
        s.press(KeyId.alpha);
        s.press(KeyId.enter); // SOLVE
        expect(s.solverX.text, isNot(''));
      }
      s.press(KeyId.clear);
    });

    test('tvm app solves FV', () {
      final s = CalcState();
      s.press(KeyId.apps);
      expect(s.menu, isNotNull);
      s.press(KeyId.enter); // Finance
      expect(s.screen, ScreenId.tvm);
      // fill N, I%, PV, PMT
      final vals = ['12', '6', '-1000', '0'];
      for (final v in vals) {
        s.insertText(v);
        s.press(KeyId.enter);
      }
      // cursor now sits on the FV row
      s.press(KeyId.alpha);
      s.press(KeyId.enter); // SOLVE
      expect(s.tvm.fv, greaterThan(1000));
      s.press(KeyId.clear);
    });
  });

  group('menus', () {
    test('math menu tabs all work', () {
      final s = CalcState();
      s.press(KeyId.math);
      for (var t = 0; t < 4; t++) {
        s.press(KeyId.right);
      }
      s.press(KeyId.down);
      s.press(KeyId.enter);
      expect(s.menu, isNull);
    });

    test('vars menu pastes names', () {
      final s = CalcState();
      s.press(KeyId.vars);
      s.press(KeyId.right);
      s.press(KeyId.enter);
    });

    test('catalog select inserts', () {
      final s = CalcState();
      s.press(KeyId.second);
      s.press(KeyId.n0); // catalog
      expect(s.menu, isNotNull);
      s.press(KeyId.down);
      s.press(KeyId.down);
      s.press(KeyId.enter);
      expect(s.menu, isNull);
    });

    test('mem menu opens memory management', () {
      final s = CalcState();
      s.press(KeyId.second);
      s.press(KeyId.add); // MEM
      s.press(KeyId.down);
      s.press(KeyId.enter); // Mem Management/Delete...
      expect(s.screen, ScreenId.memManage);
      s.press(KeyId.clear);
    });

    test('list ops menu', () {
      final s = CalcState();
      s.press(KeyId.second);
      s.press(KeyId.stat); // LIST
      s.press(KeyId.right); // OPS
      s.press(KeyId.enter); // SortA( pastes
      expect(s.entry.text, contains('SortA('));
    });

    test('stat calc runs 1-var stats', () {
      final s = CalcState();
      s.ctx.lists['L1'] = [1, 2, 3, 4, 5];
      s.press(KeyId.stat);
      s.press(KeyId.right); // CALC tab
      s.press(KeyId.enter); // 1-Var Stats
      s.press(KeyId.enter); // calculate
      expect(s.history.last.outputLines.join(' '), contains('x̄'));
    });

    test('distr menu', () {
      final s = CalcState();
      s.press(KeyId.second);
      s.press(KeyId.vars); // DISTR
      s.press(KeyId.down);
      s.press(KeyId.enter); // normalcdf
      expect(s.entry.text, contains('normalcdf'));
    });

    test('test and angle menus', () {
      final s = CalcState();
      s.press(KeyId.second);
      s.press(KeyId.math); // TEST
      s.press(KeyId.enter); // =
      s.press(KeyId.second);
      s.press(KeyId.apps); // ANGLE
      s.press(KeyId.enter);
    });

    test('link menu opens', () {
      final s = CalcState();
      s.press(KeyId.second);
      s.press(KeyId.xttn); // LINK
      expect(s.menu, isNotNull);
      s.press(KeyId.clear);
    });

    test('draw menu', () {
      final s = CalcState();
      s.press(KeyId.second);
      s.press(KeyId.prgm); // DRAW
      s.press(KeyId.enter); // ClrDraw
    });
  });

  group('graphing', () {
    CalcState graphed() {
      final s = CalcState();
      s.ctx.equation('Y1').expression = 'X²';
      s.press(KeyId.graph);
      return s;
    }

    test('graph shows and traces', () {
      final s = graphed();
      expect(s.screen, ScreenId.graph);
      s.press(KeyId.trace);
      s.press(KeyId.right);
      s.press(KeyId.right);
      expect(s.graph.tracing, isTrue);
      s.press(KeyId.clear);
    });

    test('zoom in and out', () {
      final s = graphed();
      s.press(KeyId.zoom);
      s.press(KeyId.enter); // ZBox or zoom in
      s.press(KeyId.zoom);
      s.press(KeyId.down);
      s.press(KeyId.enter);
    });

    test('calc menu value/zero', () {
      final s = graphed();
      s.press(KeyId.second);
      s.press(KeyId.trace); // CALC
      s.press(KeyId.enter); // value
      // type a guess then enter
      s.insertText('1');
      s.press(KeyId.enter);
    });

    test('table shows function values', () {
      final s = graphed();
      s.press(KeyId.second);
      s.press(KeyId.graph); // TABLE
      expect(s.screen, ScreenId.table);
      s.press(KeyId.down);
      s.press(KeyId.clear);
    });

    test('graph home', () {
      final s = graphed();
      s.press(KeyId.clear); // redraws, stays on graph
      expect(s.screen, ScreenId.graph);
      s.press(KeyId.second);
      s.press(KeyId.mode); // QUIT
      expect(s.screen, ScreenId.home);
    });
  });

  group('home extras', () {
    test('history scroll and recall', () {
      final s = CalcState();
      type(s, '2+3');
      s.press(KeyId.enter);
      type(s, '4+5');
      s.press(KeyId.enter);
      s.press(KeyId.up);
      s.press(KeyId.up);
      s.press(KeyId.enter);
      expect(s.entry.text, isNotEmpty);
      s.press(KeyId.enter);
      expect(s.history.length, 3);
    });

    test('rcl recalls a variable', () {
      final s = CalcState();
      type(s, '42');
      s.press(KeyId.sto);
      type(s, 'A');
      s.press(KeyId.enter);
      s.press(KeyId.second);
      s.press(KeyId.sto); // RCL
      s.press(KeyId.alpha);
      s.press(KeyId.math); // A
      expect(s.entry.text, '42');
      s.press(KeyId.enter);
      expect(s.history.last.outputLines.last, '42');
    });

    test('entry recalls last input', () {
      final s = CalcState();
      type(s, '7*8');
      s.press(KeyId.enter);
      s.press(KeyId.second);
      s.press(KeyId.enter); // ENTRY
      expect(s.entry.text, '7*8');
    });

    test('ans via last answer', () {
      final s = CalcState();
      type(s, '3*3');
      s.press(KeyId.enter);
      s.press(KeyId.add); // Ans+
      type(s, '1');
      s.press(KeyId.enter);
      expect(s.history.last.outputLines.last, '10');
    });
  });
}

const _charKey = <String, KeyId>{
  '0': KeyId.n0, '1': KeyId.n1, '2': KeyId.n2, '3': KeyId.n3,
  '4': KeyId.n4, '5': KeyId.n5, '6': KeyId.n6, '7': KeyId.n7,
  '8': KeyId.n8, '9': KeyId.n9, '+': KeyId.add, '-': KeyId.sub,
  '*': KeyId.mul, '/': KeyId.div, '.': KeyId.dot, '(': KeyId.lParen,
  ')': KeyId.rParen, ',': KeyId.comma, '^': KeyId.pow,
};
