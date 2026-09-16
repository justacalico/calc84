import 'package:calc84/engine/matrix.dart';
import 'package:calc84/model/entry.dart';
import 'package:calc84/model/keymap.dart';
import 'package:calc84/model/screens.dart';
import 'package:calc84/model/settings.dart';
import 'package:calc84/state/calc_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fills remaining state-layer coverage: every home command, editor,
/// menu action, graph operation and error path reachable by keys.
void main() {
  CalcState home(String src) {
    final s = CalcState();
    s.insertText(src);
    s.press(KeyId.enter);
    return s;
  }

  String out(CalcState s) =>
      s.history.expand((h) => h.outputLines).join(' ');

  group('home commands', () {
    test('draw commands create overlays', () {
      final s = CalcState();
      for (final cmd in [
        'Line(0,0,1,1)',
        'Horizontal 2',
        'Vertical -3',
        'DrawF X+1',
        'DrawInv X+1',
        'Tangent(X²,2)',
        'Shade(X-5,X²)',
        'Shade(0,5,-2,2)',
        'Pt-On(1,1)',
        'Pt-Off(2,2)',
        'Pt-Change(3,3)',
      ]) {
        s.insertText(cmd);
        s.press(KeyId.enter);
      }
      expect(s.drawn.length, greaterThan(8));
      s.insertText('StorePic Pic1');
      s.press(KeyId.enter);
      s.insertText('ClrDraw');
      s.press(KeyId.enter);
      expect(s.drawn, isEmpty);
      s.insertText('RecallPic Pic1');
      s.press(KeyId.enter);
      expect(s.drawn, isNotEmpty);
    });

    test('regression commands run from home', () {
      final s = CalcState();
      s.ctx.lists['L1'] = [1, 2, 3, 4];
      s.ctx.lists['L2'] = [2, 4, 6, 8];
      for (final cmd in [
        '1-Var Stats L1',
        '2-Var Stats L1,L2',
        'Med-Med L1,L2',
        'LinReg(ax+b) L1,L2',
        'LinReg(a+bx) L1,L2',
        'QuadReg L1,L2',
        'CubicReg L1,L2',
        'QuartReg L1,L2',
        'ExpReg L1,L2',
        'PwrReg L1,L2',
      ]) {
        s.insertText(cmd);
        s.press(KeyId.enter);
        expect(s.screen, isNot(ScreenId.error), reason: cmd);
      }
      s.ctx.lists['L3'] = [2, 3, 5, 8];
      s.insertText('LnReg L1,L3');
      s.press(KeyId.enter);
      expect(s.screen, isNot(ScreenId.error));
      expect(out(s), contains('a='));
    });

    test('clr and list ops', () {
      final s = CalcState();
      s.ctx.lists['L1'] = [1, 2, 3];
      s.insertText('ClrList L1');
      s.press(KeyId.enter);
      expect(s.ctx.list('L1'), isEmpty);
      s.insertText('{3,1,2}→L1');
      s.press(KeyId.enter);
      s.insertText('SortA(L1)');
      s.press(KeyId.enter);
      expect(s.ctx.list('L1'), [1, 2, 3]);
      s.insertText('SortD(L1)');
      s.press(KeyId.enter);
      expect(s.ctx.list('L1'), [3, 2, 1]);
      s.insertText('ClrHome');
      s.press(KeyId.enter);
      expect(out(s), '"Done"');
      s.insertText('5→A');
      s.press(KeyId.enter);
      s.insertText('DelVar A');
      s.press(KeyId.enter);
      expect(s.ctx.vars.containsKey('A'), isFalse);
      s.insertText('ClrAllLists');
      s.press(KeyId.enter);
      expect(s.ctx.list('L2'), isEmpty);
    });
  });

  group('program run through keys', () {
    test('input pause and resume', () {
      final s = CalcState();
      s.programs.add(Program('ASK', 'Input A\nDisp A*2'));
      s.insertText('prgmASK');
      s.press(KeyId.enter);
      expect(s.running, isNotNull);
      expect(s.running!.io.paused, isTrue);
      s.insertText('21');
      s.press(KeyId.enter);
      expect(out(s), contains('42'));
    });

    test('menu pause resumes by digit', () {
      final s = CalcState();
      s.programs.add(Program('M', 'Menu("T","A",1)\nLbl 1\nDisp 7'));
      s.insertText('prgmM');
      s.press(KeyId.enter);
      expect(s.running!.io.paused, isTrue);
      s.press(KeyId.enter);
      expect(out(s), contains('7'));
    });

    test('clear stops a running program', () {
      final s = CalcState();
      s.programs.add(Program('P', 'Input A\nDisp A'));
      s.insertText('prgmP');
      s.press(KeyId.enter);
      s.press(KeyId.clear);
      expect(s.running, isNull);
    });
  });

  group('error screen', () {
    test('error nav and goto', () {
      final s = home('1/0');
      expect(s.screen, ScreenId.error);
      s.press(KeyId.down);
      s.press(KeyId.enter); // Goto returns to entry
      expect(s.screen, ScreenId.home);
      s.insertText('1/0');
      s.press(KeyId.enter);
      expect(s.screen, ScreenId.error);
      s.press(KeyId.enter); // Quit
      expect(s.screen, ScreenId.home);
    });

    test('errors from menus', () {
      final s = CalcState();
      s.press(KeyId.second);
      s.press(KeyId.xttn); // LINK
      s.press(KeyId.enter);
      expect(s.screen, ScreenId.error);
      s.press(KeyId.enter);
    });
  });

  group('graph ops through keys', () {
    CalcState graphed() {
      final s = CalcState();
      s.ctx.equation('Y1').expression = 'X²-4';
      s.ctx.equation('Y2').expression = '2X';
      s.press(KeyId.graph);
      return s;
    }

    test('zoom menu actions all apply', () {
      final s = graphed();
      s.press(KeyId.zoom);
      final zooms = s.menu!.tabItems.length;
      for (var i = 0; i < zooms; i++) {
        s.press(KeyId.zoom);
        for (var j = 0; j < i; j++) {
          s.press(KeyId.down);
        }
        s.press(KeyId.enter);
      }
    });

    test('calc zero and value through prompts', () {
      final s = graphed();
      s.press(KeyId.second);
      s.press(KeyId.trace); // CALC
      s.press(KeyId.down); // zero
      s.press(KeyId.enter);
      s.insertText('-4'); // left bound
      s.press(KeyId.enter);
      s.insertText('0'); // right bound
      s.press(KeyId.enter);
      s.insertText('-2'); // guess
      s.press(KeyId.enter);
      expect(s.graph.markers, isNotEmpty);
      expect(s.graph.markers.last.label, 'Zero');
    });

    test('calc intersect and dy/dx', () {
      final s = graphed();
      s.press(KeyId.second);
      s.press(KeyId.trace);
      for (var i = 0; i < 4; i++) {
        s.press(KeyId.down); // intersect
      }
      s.press(KeyId.enter);
      s.press(KeyId.enter); // first curve
      s.press(KeyId.enter); // second curve
      s.insertText('2');
      s.press(KeyId.enter); // guess
      expect(s.graph.markers.any((m) => m.label == 'Intersection'), isTrue);
    });

    test('trace typing opens X= prompt', () {
      final s = graphed();
      s.press(KeyId.trace);
      s.insertText('3');
      s.press(KeyId.enter);
      expect(s.graph.traceParam, closeTo(3, 1e-9));
    });

    test('table arrows and editing', () {
      final s = graphed();
      s.indpntAsk = true;
      s.tblAskColX = true;
      s.press(KeyId.second);
      s.press(KeyId.graph);
      expect(s.screen, ScreenId.table);
      s.insertText('5');
      s.press(KeyId.enter);
      s.press(KeyId.down);
      s.press(KeyId.left);
      s.press(KeyId.right);
      s.press(KeyId.up);
    });
  });

  group('window fields per mode', () {
    for (final g in GraphMode.values) {
      test('window fields in $g', () {
        final s = CalcState();
        s.modes.graph = g;
        s.press(KeyId.window);
        final fields = s.winFields();
        for (var i = 0; i < fields.length; i++) {
          s.insertText('${i + 1}');
          s.press(KeyId.enter);
        }
        expect(s.screen, ScreenId.windowEdit);
      });
    }

    test('tblset both indpnt modes', () {
      final s = CalcState();
      s.press(KeyId.second);
      s.press(KeyId.window);
      final n = s.tblFields().length;
      for (var i = 0; i < n; i++) {
        s.press(KeyId.down);
      }
      s.press(KeyId.enter);
    });
  });

  group('mode and format selects', () {
    test('every mode row', () {
      final s = CalcState();
      s.press(KeyId.mode);
      for (var r = 0; r < 8; r++) {
        s.press(KeyId.right);
        s.press(KeyId.enter);
        s.press(KeyId.left);
        s.press(KeyId.enter);
        if (r < 7) s.press(KeyId.down);
      }
      expect(s.modes.split, SplitMode.full);
      s.quit();
    });

    test('every format row', () {
      final s = CalcState();
      s.press(KeyId.second);
      s.press(KeyId.zoom);
      for (var r = 0; r < 6; r++) {
        s.press(KeyId.right);
        s.press(KeyId.enter);
        s.press(KeyId.left);
        s.press(KeyId.enter);
        if (r < 5) s.press(KeyId.down);
      }
      s.quit();
    });
  });

  group('stat plots editor', () {
    test('opens plot editor and toggles', () {
      final s = CalcState();
      s.press(KeyId.second);
      s.press(KeyId.yEqu); // STAT PLOT
      expect(s.screen, ScreenId.statPlots);
      s.press(KeyId.enter); // edit Plot1
      expect(s.screen, ScreenId.statPlotEdit);
      s.press(KeyId.enter); // toggle On
      expect(s.plots[0].on, isTrue);
      for (var r = 1; r < 5; r++) {
        s.press(KeyId.down);
        s.press(KeyId.right);
        s.press(KeyId.left);
      }
      s.quit();
    });

    test('plots off item', () {
      final s = CalcState();
      s.plots[0].on = true;
      s.press(KeyId.second);
      s.press(KeyId.yEqu);
      for (var i = 0; i < 3; i++) {
        s.press(KeyId.down);
      }
      s.press(KeyId.enter); // PlotsOff
      expect(s.plots.every((p) => !p.on), isTrue);
    });
  });

  group('memory management', () {
    test('delete entries of each type', () {
      final s = CalcState();
      s.ctx.vars['A'] = 5;
      s.ctx.lists['L1'] = [1];
      s.ctx.setMatrix('[A]', Matrix(1, 1));
      s.ctx.strings['Str1'] = 'x';
      s.programs.add(Program('P'));
      s.press(KeyId.second);
      s.press(KeyId.add);
      s.press(KeyId.down);
      s.press(KeyId.enter);
      expect(s.screen, ScreenId.memManage);
      final count = s.memItems().length;
      for (var i = 0; i < count; i++) {
        s.press(KeyId.enter); // delete top item
      }
      expect(s.programs, isEmpty);
      s.quit();
    });

    test('reset and clear entries', () {
      final s = CalcState();
      s.ctx.vars['A'] = 5;
      s.press(KeyId.second);
      s.press(KeyId.add);
      // Reset
      for (var i = 0; i < 5; i++) {
        s.press(KeyId.down);
      }
      s.press(KeyId.enter);
      expect(s.ctx.getVar('A'), 0);
    });
  });

  group('solver and tvm edges', () {
    test('solver bounds row and error', () {
      final s = CalcState();
      s.openSolver();
      s.insertText('X²-4');
      s.press(KeyId.enter);
      s.insertText('0');
      s.press(KeyId.enter); // bound lo row
      s.insertText('{-10,10}');
      s.press(KeyId.enter);
      s.press(KeyId.up);
      s.press(KeyId.alpha);
      s.press(KeyId.enter); // SOLVE on X row
      expect(s.solverX.text, isNotEmpty);
      s.quit();
    });

    test('tvm solves other fields and PMT toggle', () {
      final s = CalcState();
      s.openTvm();
      final vals = ['12', '6', '-1000', '0', '1061.68'];
      for (final v in vals) {
        s.insertText(v);
        s.press(KeyId.enter);
      }
      // cursor on P/Y — commit and move on
      s.press(KeyId.enter);
      s.press(KeyId.enter);
      // row 7: PMT: END/BEGIN toggle
      s.press(KeyId.enter);
      expect(s.tvm.pmtEnd, isFalse);
      s.press(KeyId.enter);
      // solve N
      for (var i = 0; i < 7; i++) {
        s.press(KeyId.up);
      }
      s.press(KeyId.alpha);
      s.press(KeyId.enter);
      expect(s.tvm.n, closeTo(12, 0.1));
      s.quit();
    });
  });

  group('misc state paths', () {
    test('ins and del on entry', () {
      final s = CalcState();
      s.insertText('13');
      s.press(KeyId.left);
      s.press(KeyId.second);
      s.press(KeyId.del); // INS toggles to overwrite
      s.insertText('2');
      expect(s.entry.text, '12');
      s.press(KeyId.second);
      s.press(KeyId.del); // back to insert
      s.insertText('0');
      expect(s.entry.text, '120');
      s.press(KeyId.del);
      expect(s.entry.text, '12');
    });

    test('alpha lock and letters', () {
      final s = CalcState();
      s.press(KeyId.alpha);
      s.press(KeyId.alpha); // lock
      s.press(KeyId.math); // A
      s.press(KeyId.math); // A again without re-alpha
      expect(s.entry.text, 'AA');
      s.press(KeyId.alpha); // unlock
      s.press(KeyId.n5);
      expect(s.entry.text, 'AA5');
    });

    test('off screen wakes on ON', () {
      final s = CalcState();
      s.press(KeyId.second);
      s.press(KeyId.on);
      expect(s.screen, ScreenId.off);
      s.press(KeyId.n5);
      expect(s.screen, ScreenId.off);
      s.press(KeyId.on);
      expect(s.screen, ScreenId.home);
    });

    test('clock and about screens', () {
      final s = CalcState();
      s.openClock();
      s.press(KeyId.down);
      s.press(KeyId.enter);
      s.quit();
      s.openAbout();
      s.quit();
      expect(s.screen, ScreenId.home);
    });

    test('program editor insert and delete lines', () {
      final s = CalcState();
      s.programs.add(Program('P', 'Disp 1\nDisp 2'));
      s.prgmEditing = 'P';
      s.prgmLines = [
        for (final l in 'Disp 1\nDisp 2'.split('\n')) EntryLine(l),
      ];
      s.push(ScreenId.programEdit);
      s.press(KeyId.enter); // insert line after 0
      s.insertText('Disp 9');
      s.press(KeyId.down);
      s.press(KeyId.del);
      s.press(KeyId.clear); // removes line
      expect(s.programs.first.source.split('\n').length, greaterThan(1));
      s.quit();
    });

    test('rcl of list and matrix', () {
      final s = CalcState();
      s.ctx.lists['L1'] = [1, 2];
      s.ctx.setMatrix('[A]', Matrix(1, 1)..set(0, 0, 9));
      s.press(KeyId.second);
      s.press(KeyId.sto);
      s.press(KeyId.second);
      s.press(KeyId.n1); // L1
      expect(s.entry.text, contains('1'));
      s.press(KeyId.clear);
      s.press(KeyId.second);
      s.press(KeyId.sto);
      s.insertText('[A]');
      expect(s.entry.text, contains('[A]'));
    });

    test('home arrows move cursor and insert', () {
      final s = CalcState();
      s.insertText('12');
      s.press(KeyId.left);
      s.insertText('0');
      expect(s.entry.text, '102');
      s.press(KeyId.right);
      s.press(KeyId.right);
      s.insertText('3');
      expect(s.entry.text, '1023');
    });
  });
}
