import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'model/keymap.dart';
import 'state/calc_state.dart';
import 'ui/shell.dart';

class CalcApp extends StatefulWidget {
  const CalcApp({super.key, this.state});

  final CalcState? state;

  @override
  State<CalcApp> createState() => _CalcAppState();
}

class _CalcAppState extends State<CalcApp> {
  late final CalcState state = widget.state ?? CalcState();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CALC-84 Plus CE',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0C0E),
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      home: _CalcPage(state: state),
    );
  }
}

class _CalcPage extends StatefulWidget {
  const _CalcPage({required this.state});

  final CalcState state;

  @override
  State<_CalcPage> createState() => _CalcPageState();
}

class _CalcPageState extends State<_CalcPage> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final mapped = _keyMap[e.logicalKey];
    if (mapped != null) {
      widget.state.press(mapped);
      return KeyEventResult.handled;
    }
    final char = e.character;
    if (char != null && char.isNotEmpty) {
      final k = _charKeys[char];
      if (k != null) {
        widget.state.press(k);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  static final _keyMap = <LogicalKeyboardKey, KeyId>{
    LogicalKeyboardKey.enter: KeyId.enter,
    LogicalKeyboardKey.numpadEnter: KeyId.enter,
    LogicalKeyboardKey.backspace: KeyId.del,
    LogicalKeyboardKey.arrowUp: KeyId.up,
    LogicalKeyboardKey.arrowDown: KeyId.down,
    LogicalKeyboardKey.arrowLeft: KeyId.left,
    LogicalKeyboardKey.arrowRight: KeyId.right,
    LogicalKeyboardKey.escape: KeyId.clear,
    LogicalKeyboardKey.delete: KeyId.del,
    LogicalKeyboardKey.f1: KeyId.yEqu,
    LogicalKeyboardKey.f2: KeyId.window,
    LogicalKeyboardKey.f3: KeyId.zoom,
    LogicalKeyboardKey.f4: KeyId.trace,
    LogicalKeyboardKey.f5: KeyId.graph,
    LogicalKeyboardKey.tab: KeyId.second,
    LogicalKeyboardKey.capsLock: KeyId.alpha,
    LogicalKeyboardKey.numpadAdd: KeyId.add,
    LogicalKeyboardKey.numpadSubtract: KeyId.sub,
    LogicalKeyboardKey.numpadMultiply: KeyId.mul,
    LogicalKeyboardKey.numpadDivide: KeyId.div,
    LogicalKeyboardKey.numpadDecimal: KeyId.dot,
    LogicalKeyboardKey.numpad0: KeyId.n0,
    LogicalKeyboardKey.numpad1: KeyId.n1,
    LogicalKeyboardKey.numpad2: KeyId.n2,
    LogicalKeyboardKey.numpad3: KeyId.n3,
    LogicalKeyboardKey.numpad4: KeyId.n4,
    LogicalKeyboardKey.numpad5: KeyId.n5,
    LogicalKeyboardKey.numpad6: KeyId.n6,
    LogicalKeyboardKey.numpad7: KeyId.n7,
    LogicalKeyboardKey.numpad8: KeyId.n8,
    LogicalKeyboardKey.numpad9: KeyId.n9,
  };

  static const _charKeys = <String, KeyId>{
    '0': KeyId.n0, '1': KeyId.n1, '2': KeyId.n2, '3': KeyId.n3,
    '4': KeyId.n4, '5': KeyId.n5, '6': KeyId.n6, '7': KeyId.n7,
    '8': KeyId.n8, '9': KeyId.n9, '+': KeyId.add, '-': KeyId.sub,
    '*': KeyId.mul, '/': KeyId.div, '.': KeyId.dot, '(': KeyId.lParen,
    ')': KeyId.rParen, ',': KeyId.comma, '^': KeyId.pow,
    '=': KeyId.xttn,
  };

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        body: SafeArea(
          child: Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                colors: [Color(0xFF16181C), Color(0xFF0B0C0E)],
                radius: 1.2,
              ),
            ),
            child: CalculatorShell(state: widget.state),
          ),
        ),
      ),
    );
  }
}
