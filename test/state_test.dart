import 'package:calc84/model/keymap.dart';
import 'package:calc84/engine/context.dart';
import 'package:calc84/model/screens.dart';
import 'package:calc84/model/settings.dart';
import 'package:calc84/state/calc_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('home screen', () {
    test('typing and evaluating an expression', () {
      final s = CalcState();
      for (final k in [KeyId.n2, KeyId.add, KeyId.n3, KeyId.mul, KeyId.n4]) {
        s.press(k);
      }
      s.press(KeyId.enter);
      expect(s.history.isNotEmpty, isTrue);
      expect(s.history.last.outputLines.last, contains('14'));
    });

    test('clear wipes the entry', () {
      final s = CalcState();
      s.press(KeyId.n5);
      s.press(KeyId.clear);
      expect(s.entry.text, isEmpty);
    });

    test('del removes the last char', () {
      final s = CalcState();
      s.press(KeyId.n1);
      s.press(KeyId.n2);
      s.press(KeyId.del);
      expect(s.entry.text, '1');
    });

    test('division by zero shows the error screen', () {
      final s = CalcState();
      for (final k in [KeyId.n1, KeyId.div, KeyId.n0]) {
        s.press(k);
      }
      s.press(KeyId.enter);
      expect(s.screen, ScreenId.error);
      s.press(KeyId.enter);
      expect(s.screen, ScreenId.home);
    });

    test('ans continues the last result', () {
      final s = CalcState();
      for (final k in [KeyId.n3, KeyId.add, KeyId.n4]) {
        s.press(k);
      }
      s.press(KeyId.enter);
      s.press(KeyId.mul);
      s.press(KeyId.n2);
      s.press(KeyId.enter);
      expect(s.history.last.outputLines.last, contains('14'));
    });

    test('store into a variable', () {
      final s = CalcState();
      for (final k in [KeyId.n9, KeyId.sto, KeyId.alpha, KeyId.math]) {
        s.press(k);
      }
      s.press(KeyId.enter);
      s.press(KeyId.xttn);
      s.press(KeyId.add);
      s.press(KeyId.n1);
      s.press(KeyId.enter);
      expect(s.history.last.outputLines.last, isNotEmpty);
    });
  });

  group('screen navigation', () {
    test('mode opens and returns', () {
      final s = CalcState();
      s.press(KeyId.mode);
      expect(s.screen, ScreenId.mode);
      s.press(KeyId.clear);
      expect(s.screen, ScreenId.home);
    });

    test('y= editor opens', () {
      final s = CalcState();
      s.press(KeyId.yEqu);
      expect(s.screen, ScreenId.yEquals);
    });

    test('window editor opens', () {
      final s = CalcState();
      s.press(KeyId.window);
      expect(s.screen, ScreenId.windowEdit);
    });

    test('stat list editor opens', () {
      final s = CalcState();
      s.press(KeyId.stat);
      expect(s.menu != null || s.screen != ScreenId.home, isTrue);
    });
  });

  group('modifiers', () {
    test('2nd modifier maps to second function', () {
      final s = CalcState();
      s.press(KeyId.second);
      s.press(KeyId.mode); // 2nd+MODE = QUIT
      expect(s.screen, ScreenId.home);
    });

    test('alpha inserts letters', () {
      final s = CalcState();
      s.press(KeyId.alpha);
      s.press(KeyId.math); // A
      expect(s.entry.text, 'A');
    });

    test('2nd then digit gets the second function', () {
      final s = CalcState();
      s.press(KeyId.second);
      s.press(KeyId.n1); // 2nd+1 = L1
      expect(s.entry.text, 'L1');
    });
  });

  group('menus', () {
    test('math menu opens and pastes', () {
      final s = CalcState();
      s.press(KeyId.math);
      expect(s.menu, isNotNull);
      s.press(KeyId.enter); // select first item (▸Frac on most layouts)
      expect(s.menu, isNull);
    });

    test('quit closes a menu', () {
      final s = CalcState();
      s.press(KeyId.math);
      s.press(KeyId.second);
      s.press(KeyId.mode);
      expect(s.menu, isNull);
    });
  });

  group('mode settings', () {
    test('degree mode affects trig', () {
      final s = CalcState();
      s.modeSelect(2, 1);
      for (final k in [
        KeyId.sin,
        KeyId.n9,
        KeyId.n0,
        KeyId.rParen,
      ]) {
        s.press(k);
      }
      s.press(KeyId.enter);
      expect(s.history.last.outputLines.last, contains('1'));
    });
  });
}
