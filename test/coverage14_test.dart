import 'package:calc84/model/keymap.dart';
import 'package:calc84/ui/key_button.dart';
import 'package:calc84/ui/keypad.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Key presses are easier to land: the whole grid cell is the hitbox
/// and the arrow pad targets are wider than the icons they hold.
void main() {
  Future<void> pumpKeypad(
      WidgetTester t, void Function(KeyId) onPress) async {
    t.view.physicalSize = const Size(500, 500);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
        home: Scaffold(body: Keypad(onPress: onPress))));
    await t.pump();
  }

  group('generous key hitboxes', () {
    testWidgets('tapping the legend strip hits the key', (t) async {
      KeyId? got;
      await pumpKeypad(t, (id) => got = id);
      await t.tap(find.text('L1'));
      expect(got, KeyId.n1);
    });

    testWidgets('tapping the cell edge hits the key', (t) async {
      KeyId? got;
      await pumpKeypad(t, (id) => got = id);
      final cell = t.getRect(find.ancestor(
          of: find.byKey(const ValueKey('key-n5')),
          matching: find.byType(KeyButton)));
      await t.tapAt(cell.topLeft + const Offset(2, 2));
      expect(got, KeyId.n5);
    });

    testWidgets('arrow pad edge taps still dispatch', (t) async {
      KeyId? got;
      await pumpKeypad(t, (id) => got = id);
      final icon = t.getCenter(find.byIcon(Icons.arrow_left));
      await t.tapAt(icon + const Offset(0, 20));
      expect(got, KeyId.left);
    });
  });

  group('key press haptics', () {
    var haptics = 0;

    setUp(() {
      haptics = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'HapticFeedback.vibrate' &&
            call.arguments == 'HapticFeedbackType.lightImpact') {
          haptics++;
        }
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    testWidgets('pressing a key vibrates', (t) async {
      await pumpKeypad(t, (_) {});
      await t.tap(find.byKey(const ValueKey('key-n1')));
      expect(haptics, 1);
    });

    testWidgets('pressing an arrow vibrates', (t) async {
      await pumpKeypad(t, (_) {});
      await t.tap(find.byIcon(Icons.arrow_left));
      expect(haptics, 1);
    });
  });
}
