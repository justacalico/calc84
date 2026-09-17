import 'package:calc84/app.dart';
import 'package:calc84/engine/context.dart';
import 'package:calc84/engine/evaluator.dart';
import 'package:calc84/engine/format.dart';
import 'package:calc84/engine/program.dart';
import 'package:calc84/engine/tokenizer.dart';
import 'package:calc84/engine/value.dart';
import 'package:calc84/model/keymap.dart';
import 'package:calc84/model/screens.dart';
import 'package:calc84/model/settings.dart';
import 'package:calc84/state/calc_state.dart';
import 'package:calc84/ui/key_button.dart';
import 'package:calc84/ui/keypad.dart';
import 'package:calc84/ui/lcd.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Final sweep: defensive branches, widget callbacks, and the last
/// uncovered corners.
void main() {
  // Must run before anything else registers the inline evaluator.
  test('evaluateInline throws before registration', () {
    expect(
        () => evaluateInline('1', CalcContext()),
        throwsA(isA<StateError>()));
  });

  group('engine tail', () {
    test('equation arg eval restores a saved X', () {
      final ctx = CalcContext();
      evalSource('3→X', ctx);
      ctx.equation('Y1').expression = 'X+1';
      expect(evalSource('Y1(5)', ctx).asReal, 6);
      expect(ctx.vars['X'], 3);
    });

    test('unparse of decimal via equation store', () {
      final ctx = CalcContext();
      evalSource('2.5→Y1', ctx);
      expect(ctx.equations['Y1']!.expression, '2.5');
    });

    test('scalar min and max', () {
      expect(evalSource('min(3,5)', CalcContext()).asReal, 3);
      expect(evalSource('max(3,5)', CalcContext()).asReal, 5);
    });

    test('complex unary minus still works', () {
      final ctx = CalcContext()..complexMode = ComplexMode.aBi;
      final v = evalSource('-i', ctx);
      expect(v, isA<ComplexValue>());
      expect((v as ComplexValue).v.im, -1);
    });

    test('longest name match and word ops', () {
      expect(tokenize('X1T').single.text, 'X1T');
      expect(tokenize('2 nCr 3').map((t) => t.text).toList(),
          ['2', 'nCr', '3']);
      expect(tokenize('2ˣ√9').map((t) => t.text).toList(), ['2', 'ˣ√', '9']);
    });

    test('format fixed fallback and eng renorm', () {
      final fixed = Formatter(DisplaySettings()..decimals = 9);
      expect(fixed.num(1234.56789), contains('ᴇ'));
      final eng = Formatter(DisplaySettings()..notation = Notation.eng);
      expect(eng.num(999999.9999999), '1ᴇ6');
    });

    test('dms seconds carry bumps minutes', () {
      final f = Formatter(DisplaySettings());
      expect(f.dms(5.5166656), '5°31′');
    });
  });

  group('program tail', () {
    ProgramRunner run(String src) => ProgramRunner(src, CalcContext())..run();

    test('disp shows decimal reals', () {
      expect(run('Disp 1.5').io.lines, ['1.5']);
    });
  });

  group('state tail', () {
    test('format overflow shows the generic error screen', () {
      final s = CalcState();
      s.modes.decimals = 25;
      s.insertText('1.5');
      s.press(KeyId.enter);
      expect(s.screen, ScreenId.error);
    });

    test('table ask rows render after entry', () {
      final s = CalcState();
      s.ctx.equation('Y1').expression = 'X²';
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
      expect(s.tableRows(5), isNotEmpty);
    });

    test('calc value prompt applies empty input as zero', () {
      final s = CalcState();
      s.ctx.equation('Y1').expression = 'X²';
      s.press(KeyId.graph);
      s.press(KeyId.second);
      s.press(KeyId.trace);
      s.press(KeyId.enter); // 1:value
      expect(s.graphPrompt, 'X=');
      s.press(KeyId.enter); // empty prompt -> 0
      expect(s.graphPrompt, isNull);
      expect(s.graph.markers, isNotEmpty);
    });

  });

  group('painter tail', () {
    Future<void> pumpLcd(WidgetTester t, CalcState s) async {
      await t.pumpWidget(MaterialApp(
          home: SizedBox(width: 320, height: 240, child: Lcd(state: s))));
      await t.pump();
    }

    testWidgets('drawf of a defined equation restores X', (t) async {
      final s = CalcState();
      s.ctx.equation('Y1').expression = 'X²';
      s.ctx.vars['X'] = 2;
      s.insertText('DrawF Y1');
      s.press(KeyId.enter);
      s.press(KeyId.graph);
      await pumpLcd(t, s);
      expect(s.ctx.vars['X'], 2);
    });

    testWidgets('tangent skips an undefined point', (t) async {
      final s = CalcState();
      s.ctx.equation('Y1').expression = '1/X';
      s.ctx.vars['X'] = 2;
      s.insertText('Tangent(Y1,0)');
      s.press(KeyId.enter);
      s.press(KeyId.graph);
      await pumpLcd(t, s);
      expect(s.ctx.vars['X'], 2);
    });

    testWidgets('matrix editor shows cell line and edit cursor', (t) async {
      final s = CalcState();
      s.openMatrixEditor('A');
      s.press(KeyId.enter);
      s.press(KeyId.enter);
      expect(s.matRow, 0);
      s.press(KeyId.n7);
      expect(s.matCellEditing, isTrue);
      await pumpLcd(t, s);
      s.press(KeyId.enter);
      expect(s.ctx.matrices['A']!.data[0][0], 7);
      expect(s.matCellEditing, isFalse);
      await pumpLcd(t, s); // render committed cell
    });

    testWidgets('sequence trace label paints', (t) async {
      final s = CalcState();
      s.modes.graph = GraphMode.sequence;
      s.ctx.sequences['u']!.expression = 'n+1';
      s.press(KeyId.graph);
      s.press(KeyId.trace);
      await pumpLcd(t, s);
      expect(s.graph.tracing, isTrue);
      expect(s.graph.tracePoint, isNotNull);
    });
  });

  group('widget tail', () {
    testWidgets('arrow pad buttons dispatch', (t) async {
      KeyId? got;
      t.view.physicalSize = const Size(500, 500);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(
          home: Scaffold(body: Keypad(onPress: (id) => got = id))));
      await t.tap(find.byIcon(Icons.arrow_left));
      expect(got, KeyId.left);
    });

    testWidgets('key button tap cancel resets state', (t) async {
      var presses = 0;
      final def = keyDefOf(KeyId.n1);
      await t.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Center(
                  child: SizedBox(
                      width: 60,
                      height: 60,
                      child:
                          KeyButton(def: def, onPress: (_) => presses++))))));
      final g = await t.startGesture(t.getCenter(find.byType(KeyButton)));
      await g.moveBy(const Offset(0, 300));
      await g.up();
      expect(presses, 0);
    });

    testWidgets('hardware keyboard dispatches to state', (t) async {
      final s = CalcState();
      t.view.physicalSize = const Size(500, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(CalcApp(state: s));
      await t.pumpAndSettle();
      await t.sendKeyEvent(LogicalKeyboardKey.digit4);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pump();
      expect(s.history, isNotEmpty);
    });
  });
}
