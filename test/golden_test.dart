import 'package:calc84/app.dart';
import 'package:calc84/model/keymap.dart';
import 'package:calc84/state/calc_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _loadFonts() async {
  final roboto = FontLoader('Roboto')
    ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
  final condensed = FontLoader('RobotoCondensed')
    ..addFont(rootBundle.load('assets/fonts/RobotoCondensed-Bold.ttf'));
  final icons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('assets/fonts/MaterialIcons-Regular.otf'));
  await roboto.load();
  await condensed.load();
  await icons.load();
}

void main() {
  setUpAll(_loadFonts);

  Future<void> pumpCalc(WidgetTester tester, CalcState state) async {
    tester.view.physicalSize = const Size(840, 1720);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(CalcApp(state: state));
    await tester.pumpAndSettle();
  }

  testWidgets('home screen golden', (tester) async {
    final s = CalcState();
    await pumpCalc(tester, s);
    for (final k in [KeyId.n3, KeyId.add, KeyId.n4, KeyId.mul, KeyId.n5]) {
      s.press(k);
    }
    s.press(KeyId.enter);
    await tester.pump();
    await expectLater(find.byType(CalcApp),
        matchesGoldenFile('goldens/home.png'));
  });

  testWidgets('graph screen golden', (tester) async {
    final s = CalcState();
    await pumpCalc(tester, s);
    s.ctx.equation('Y1').expression = 'X²';
    s.ctx.equation('Y2').expression = 'sin(X)';
    s.press(KeyId.graph);
    await tester.pump();
    await expectLater(find.byType(CalcApp),
        matchesGoldenFile('goldens/graph.png'));
  });

  testWidgets('mode screen golden', (tester) async {
    final s = CalcState();
    await pumpCalc(tester, s);
    s.press(KeyId.mode);
    await tester.pump();
    await expectLater(find.byType(CalcApp),
        matchesGoldenFile('goldens/mode.png'));
  });
}
