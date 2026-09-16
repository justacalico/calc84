import 'package:calc84/engine/context.dart';
import 'package:calc84/engine/evaluator.dart';
import 'package:calc84/engine/matrix.dart';
import 'package:calc84/engine/tibasic.dart';
import 'package:calc84/engine/tokenizer.dart';
import 'package:calc84/engine/tvm.dart';
import 'package:calc84/engine/value.dart';
import 'package:calc84/model/keymap.dart';
import 'package:calc84/model/screens.dart';
import 'package:calc84/model/settings.dart';
import 'package:calc84/state/calc_state.dart';
import 'package:calc84/ui/lcd.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Last-mile coverage: leftover engine branches, state paths and the
/// remaining render-only lines.
void main() {
  double ev(String src, [CalcContext? ctx]) =>
      evalSource(src, ctx ?? CalcContext()).asReal;

  group('engine leftovers', () {
    test('getKey, n and bare sequence names', () {
      final s = CalcState();
      s.press(KeyId.n5); // code 83
      expect(evalSource('getKey', s.ctx).asReal, 83);
      expect(ev('n'), 0);
      s.ctx.sequences['u']!.expression = 'n+1';
      expect(evalSource('u', s.ctx).asReal, 1); // u(nMin)=1
    });

    test('sequence eval restores saved vars', () {
      final ctx = CalcContext();
      ctx.sequences['u']!.expression = 'n*10';
      ctx.vars['n'] = 9;
      ctx.vars['_seq_v'] = 4;
      expect(ev('u(3)', ctx), 30);
      expect(ctx.vars['n'], 9);
      expect(ctx.vars['_seq_v'], 4);
    });

    test('gamma reflection and complex inverses', () {
      expect(ev('(-0.6)!'), closeTo(2.218, 1e-3));
      expect(ev('χ²pdf(2,0.5)'), greaterThan(0));
      final ctx = CalcContext()..complexMode = ComplexMode.aBi;
      expect(evalSource('cosh⁻¹(0.5)', ctx), isA<ComplexValue>());
      expect(evalSource('tanh⁻¹(2)', ctx), isA<ComplexValue>());
    });

    test('list broadcast, matrix element store, misc', () {
      final ctx = CalcContext();
      expect(evalSource('-{1,2}', ctx).toString(), '{-1.0 -2.0}');
      evalSource('[[1,2][3,4]]→[A]', ctx);
      evalSource('9→[A](1,2)', ctx);
      expect(evalSource('[A](1,2)', ctx).asReal, 9);
      evalSource('min(3,{1,5})', ctx);
      expect(ev('median(7)', ctx), 7);
      expect(ev('variance({5})', ctx), 0);
      expect(ev('variance({1,2,3})', ctx), 1);
      expect(
          evalSource('rref([[0,2][0,4]])', ctx).toString(), contains('1'));
    });

    test('store to function-token name and roots', () {
      final ctx = CalcContext();
      evalSource('5→u(', ctx);
      expect(ctx.sequences['u']!.expression, '5');
      expect(ev('3ˣ√8'), 2);
      expect('${tokenize('1+2').first}', contains('number'));
      expect(() => evalSource('1#2', ctx), throwsA(isA<CalcException>()));
      expect(() => TvmSolver().solve('P/Y'), throwsA(isA<CalcException>()));
    });

    test('adaptive integration refines', () {
      // Oscillatory enough that the coarse pass misses.
      expect(ev('fnInt(sin(40X),X,0,6)'), closeTo(0.012, 1e-2));
    });
  });

  group('ti-basic leftovers', () {
    test('ClrHome, single-line If and nested skip', () {
      final ctx = CalcContext()..complexMode = ComplexMode.aBi;
      ProgramRunner run(String src) => ProgramRunner(src, ctx)..run();
      expect(run('Disp 1\nClrHome\nDisp 2').io.lines, ['2']);
      expect(run('If 1=2:Disp 5\nDisp 7').io.lines, ['7']);
      expect(run('If 1=1:Then:Disp 5:End').io.lines, ['5']);
      expect(run('If 1=2\nThen\nDisp 8\nEnd\nDisp 3').io.lines, ['3']);
      expect(
          run('If 1=2\nThen\nIf 1=1\nThen\nDisp 9\nEnd\nEnd\nDisp 4')
              .io
              .lines,
          ['4']);
      evalSource('[[1]]→[A]', ctx);
      final r = run('Disp [A]\nDisp i');
      expect(r.io.lines, hasLength(2));
    });
  });

  group('state leftovers', () {
    test('window editor arrows move rows', () {
      final s = CalcState();
      s.press(KeyId.window);
      expect(s.winRow, 0);
      s.press(KeyId.down);
      expect(s.winRow, 1);
      s.press(KeyId.up);
      expect(s.winRow, 0);
    });

    test('ins toggles insert mode and del removes mid-entry', () {
      final s = CalcState();
      s.insertText('12');
      s.press(KeyId.left);
      s.press(KeyId.del); // deletes the 2
      expect(s.entry.text, '1');
      s.press(KeyId.second);
      s.press(KeyId.del); // INS: overwrite mode
      s.insertText('3');
      expect(s.entry.text, '13');
    });

    test('generic errors show the error screen', () {
      final s = CalcState();
      s.entry.setText('5→'); // dangling store → non-CalcException
      s.press(KeyId.enter);
      expect(s.screen, ScreenId.error);
    });

    test('Med-Med stores equation and handles tiny lists', () {
      final s = CalcState();
      s.ctx.lists['L1'] = [1, 2];
      s.ctx.lists['L2'] = [3, 4];
      s.insertText('Med-Med L1,L2,Y1');
      s.press(KeyId.enter);
      expect(s.ctx.equation('Y1').expression, contains('X'));
    });

    test('home eval refreshes y= editor lines', () {
      final s = CalcState();
      s.press(KeyId.yEqu);
      s.insertText('X+1');
      s.press(KeyId.second);
      s.press(KeyId.mode); // quit
      s.entry.setText('2+2');
      s.press(KeyId.enter);
      expect(s.history.last.outputLines.last, '4');
    });

    test('table ask mode collects X entries', () {
      final s = CalcState();
      s.ctx.equation('Y1').expression = 'X*2';
      s.press(KeyId.second);
      s.press(KeyId.window); // TBLSET
      s.press(KeyId.down);
      s.press(KeyId.down); // Indpnt row
      s.press(KeyId.enter); // toggle to Ask
      s.press(KeyId.second);
      s.press(KeyId.graph); // TABLE
      s.press(KeyId.n3);
      s.press(KeyId.enter);
      expect(s.tblAskXs, [3]);
    });

    test('solver restores X and reports no-solution', () {
      final s = CalcState();
      s.insertText('5→X');
      s.press(KeyId.enter);
      s.solverEq.setText('X-2.5');
      s.screen = ScreenId.solver;
      s.solverRow = 1; // the X= line
      s.press(KeyId.alpha);
      s.press(KeyId.enter); // SOLVE
      expect(s.history.last.outputLines.last, contains('2.5'));
      expect(s.ctx.vars['X'], closeTo(2.5, 1e-9));

      final s2 = CalcState();
      s2.solverEq.setText('X²+1');
      s2.screen = ScreenId.solver;
      s2.solverRow = 1;
      s2.press(KeyId.alpha);
      s2.press(KeyId.enter);
      expect(s2.screen, ScreenId.error);
    });
  });

  group('graph leftovers', () {
    test('sequence param range and plotting', () {
      final s = CalcState();
      s.modes.graph = GraphMode.sequence;
      s.ctx.sequences['u']!.expression = 'n+1';
      s.press(KeyId.graph);
      expect(s.graph.plotPoints('u', 95), isNotEmpty);
      s.window.plotStep = 2;
      expect(s.graph.plotPoints('u', 95), isNotEmpty);
    });

    test('polar plotting handles null points and dot mode', () {
      final s = CalcState();
      s.modes.graph = GraphMode.polar;
      s.ctx.equation('r1').expression = '√(3-θ)';
      s.press(KeyId.graph);
      expect(s.graph.plotPoints('r1', 95), isNotEmpty);
      s.modes.connected = ConnectedMode.dot;
      s.ctx.equation('r1').expression = 'sin(θ)';
      expect(s.graph.plotPoints('r1', 95), isNotEmpty);
    });

    test('trace recenters window when y is offscreen', () {
      final s = CalcState();
      s.ctx.equation('Y1').expression = 'X³';
      s.press(KeyId.graph);
      s.window.yMin = 5;
      s.window.yMax = 10; // trace point at x=0 gives y=0 < yMin
      s.press(KeyId.trace);
      expect(s.window.yMin, lessThan(0));
    });

    test('calc value prompt marks a point', () {
      final s = CalcState();
      s.ctx.equation('Y1').expression = 'X²';
      s.press(KeyId.graph);
      s.press(KeyId.second);
      s.press(KeyId.trace); // CALC menu
      s.press(KeyId.enter); // 1:value
      s.insertText('3');
      s.press(KeyId.enter);
      expect(s.graph.markers, isNotEmpty);
    });

    test('y-vars parametric and polar submenus', () {
      final s = CalcState();
      s.press(KeyId.vars);
      s.press(KeyId.right); // Y-VARS
      s.press(KeyId.down); // Parametric...
      s.press(KeyId.enter);
      expect(s.menu!.tabItems.first.label, 'X1T');
      final s2 = CalcState();
      s2.press(KeyId.vars);
      s2.press(KeyId.right);
      s2.press(KeyId.down);
      s2.press(KeyId.down); // Polar...
      s2.press(KeyId.enter);
      expect(s2.menu!.tabItems.first.label, 'r1');
    });
  });

  group('render leftovers', () {
    Future<void> show(WidgetTester t, CalcState s) async {
      await t.pumpWidget(MaterialApp(
          home: SizedBox(width: 320, height: 240, child: Lcd(state: s))));
      await t.pump();
    }

    testWidgets('y= headers in par/pol/seq', (t) async {
      for (final m in [
        GraphMode.parametric,
        GraphMode.polar,
        GraphMode.sequence
      ]) {
        final s = CalcState();
        s.modes.graph = m;
        s.ctx.sequences['u']!.enabled = false;
        s.press(KeyId.yEqu);
        await show(t, s);
      }
    });

    testWidgets('table ask X edit line', (t) async {
      final s = CalcState();
      s.indpntAsk = true;
      s.screen = ScreenId.table;
      s.press(KeyId.n5);
      await show(t, s);
    });

    testWidgets('list and matrix cell editing', (t) async {
      final s = CalcState();
      s.press(KeyId.stat);
      s.press(KeyId.enter); // Edit...
      s.press(KeyId.n5);
      await show(t, s);

      final s2 = CalcState();
      s2.ctx.setMatrix('[A]', Matrix(2, 2)..set(0, 0, 5));
      s2.screen = ScreenId.matrixEdit;
      s2.matrixName = '[A]';
      s2.matRow = -1;
      s2.press(KeyId.n3); // editing dims
      await show(t, s2);
      s2.press(KeyId.enter);
      s2.press(KeyId.n7); // cell editing
      await show(t, s2);
    });

    testWidgets('empty program list and cursor mid-run', (t) async {
      final s = CalcState();
      s.press(KeyId.prgm);
      await show(t, s);
      s.press(KeyId.clear);
      s.insertText('12+34');
      s.press(KeyId.left);
      s.press(KeyId.left); // cursor inside the run
      await show(t, s);
    });

    testWidgets('drawn tangent/shade and polar/seq trace labels', (t) async {
      final s = CalcState();
      s.ctx.vars['X'] = 2; // exercises saved-var restore in painters
      s.ctx.equation('Y1').expression = 'X²';
      s.insertText('DrawF X²');
      s.press(KeyId.enter);
      s.insertText('Tangent(Y1,1)');
      s.press(KeyId.enter);
      s.insertText('Tangent(1/(X-1),1)'); // eval throws inside painter
      s.press(KeyId.enter);
      s.insertText('Shade(X,X²)');
      s.press(KeyId.enter);
      s.press(KeyId.graph);
      s.press(KeyId.trace);
      await show(t, s);

      final p = CalcState();
      p.modes.graph = GraphMode.polar;
      p.ctx.equation('r1').expression = '2';
      p.press(KeyId.graph);
      p.press(KeyId.trace);
      await show(t, p);

      final q = CalcState();
      q.modes.graph = GraphMode.sequence;
      q.ctx.sequences['u']!.expression = 'n+1';
      q.press(KeyId.graph);
      q.press(KeyId.trace);
      await show(t, q);
    });
  });
}
