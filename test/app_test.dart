import 'package:calc84/app.dart';
import 'package:calc84/model/keymap.dart';
import 'package:calc84/state/calc_state.dart';
import 'package:calc84/ui/key_button.dart';
import 'package:calc84/ui/shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app renders the calculator shell', (tester) async {
    await tester.pumpWidget(const CalcApp());
    await tester.pumpAndSettle();
    expect(find.byType(CalculatorShell), findsOneWidget);
    expect(find.text('CALC-84'), findsOneWidget);
  });

  testWidgets('tapping keys types an expression', (tester) async {
    final state = CalcState();
    await tester.pumpWidget(CalcApp(state: state));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('key-n1')));
    await tester.tap(find.byKey(const ValueKey('key-add')));
    await tester.tap(find.byKey(const ValueKey('key-n1')));
    await tester.pump();
    expect(state.entry.text, '1+1');
  });

  testWidgets('enter evaluates and shows the result', (tester) async {
    final state = CalcState();
    await tester.pumpWidget(CalcApp(state: state));
    await tester.pumpAndSettle();
    for (final id in [KeyId.n2, KeyId.add, KeyId.n2]) {
      await tester.tap(find.byKey(ValueKey('key-${id.name}')));
    }
    await tester.tap(find.byKey(const ValueKey('key-enter')));
    await tester.pump();
    expect(state.history.last.outputLines.last, '4');
  });

  testWidgets('keyboard input works', (tester) async {
    final state = CalcState();
    await tester.pumpWidget(CalcApp(state: state));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.digit5);
    await tester.pump();
    expect(state.entry.text, '5');
  });
}
