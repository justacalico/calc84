import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../model/keymap.dart';
import 'key_button.dart';
import 'theme.dart';

/// The full keypad: five columns of keys plus the arrow cluster.
class Keypad extends StatelessWidget {
  const Keypad({super.key, required this.onPress});

  final void Function(KeyId) onPress;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Row of five pale function keys.
        _row(keypadRows[0]),
        // 2nd/mode/del beside the arrow cluster.
        SizedBox(
          height: 118,
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    _row(keypadRows[1]),
                    _row(keypadRows[2]),
                  ],
                ),
              ),
              Expanded(flex: 2, child: _ArrowCluster(onPress: onPress)),
            ],
          ),
        ),
        for (var r = 3; r < keypadRows.length; r++) _row(keypadRows[r]),
      ],
    );
  }

  Widget _row(List<KeyId> ids) {
    return Expanded(
      child: Row(
        children: [
          for (final id in ids)
            Expanded(
              child: KeyButton(def: keyDefOf(id), onPress: onPress),
            ),
          // Pad short rows so the grid stays aligned.
          for (var i = ids.length; i < 5; i++)
            const Expanded(child: SizedBox.shrink()),
        ],
      ),
    );
  }
}

/// The circular direction pad from the real device.
class _ArrowCluster extends StatelessWidget {
  const _ArrowCluster({required this.onPress});

  final void Function(KeyId) onPress;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final size = c.maxWidth < c.maxHeight ? c.maxWidth : c.maxHeight;
        return Center(
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF3E4145), Color(0xFF232527)],
                      ),
                      border: Border.all(color: Colors.black87),
                      boxShadow: const [
                        BoxShadow(
                            color: Colors.black54,
                            blurRadius: 3,
                            offset: Offset(0, 2)),
                      ],
                    ),
                  ),
                ),
                _arrowBtn(KeyId.up, Alignment.topCenter, Icons.arrow_drop_up,
                    const EdgeInsets.fromLTRB(14, 6, 14, 34)),
                _arrowBtn(KeyId.down, Alignment.bottomCenter,
                    Icons.arrow_drop_down,
                    const EdgeInsets.fromLTRB(14, 34, 14, 6)),
                _arrowBtn(KeyId.left, Alignment.centerLeft, Icons.arrow_left,
                    const EdgeInsets.fromLTRB(6, 14, 34, 14)),
                _arrowBtn(KeyId.right, Alignment.centerRight,
                    Icons.arrow_right,
                    const EdgeInsets.fromLTRB(34, 14, 6, 14)),
                Center(
                  child: Container(
                    width: size * 0.26,
                    height: size * 0.26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: CalcTheme.faceplate,
                      border: Border.all(color: Colors.black54),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// The padding grows the tap target inward while the icon stays at
  /// its hardware position on the ring.
  Widget _arrowBtn(
      KeyId id, Alignment at, IconData icon, EdgeInsets padding) {
    return Align(
      alignment: at,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTapDown: (_) => HapticFeedback.lightImpact(),
        onTap: () => onPress(id),
        child: Padding(
          padding: padding,
          child: Icon(icon, color: Colors.white70, size: 20),
        ),
      ),
    );
  }
}
