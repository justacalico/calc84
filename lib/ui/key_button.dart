import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../model/keymap.dart';
import 'theme.dart';

/// One skeuomorphic plastic key with its 2nd/alpha legend above it.
/// The whole cell is the hitbox, so taps on the legend strip or the
/// thin gaps around the cap still land on the key.
class KeyButton extends StatefulWidget {
  const KeyButton({super.key, required this.def, required this.onPress});

  final KeyDef def;
  final void Function(KeyId) onPress;

  @override
  State<KeyButton> createState() => _KeyButtonState();
}

class _KeyButtonState extends State<KeyButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        setState(() => _down = true);
        HapticFeedback.lightImpact();
      },
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: () => widget.onPress(widget.def.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 13,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (widget.def.secondLabel != null)
                      Flexible(
                        child: Text(
                          widget.def.secondLabel!,
                          overflow: TextOverflow.clip,
                          softWrap: false,
                          style:
                              CalcTheme.legend(color: CalcTheme.legend2nd),
                        ),
                      ),
                    if (widget.def.alphaLabel != null)
                      Text(
                        widget.def.alphaLabel!,
                        softWrap: false,
                        style:
                            CalcTheme.legend(color: CalcTheme.legendAlpha),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _KeyCap(
                key: ValueKey('key-${widget.def.id.name}'),
                def: widget.def,
                down: _down,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KeyCap extends StatelessWidget {
  const _KeyCap({super.key, required this.def, required this.down});

  final KeyDef def;
  final bool down;

  @override
  Widget build(BuildContext context) {
    final (top, bottom) = switch (def.style) {
      KeyStyle.blue => (CalcTheme.keyBlue, CalcTheme.keyBlueDark),
      KeyStyle.green => (CalcTheme.keyGreen, CalcTheme.keyGreenDark),
      KeyStyle.light => (CalcTheme.keyLightTop, CalcTheme.keyLightBottom),
      KeyStyle.dark => (CalcTheme.keyTop, CalcTheme.keyBottom),
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 60),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: down ? [bottom, bottom] : [top, bottom],
        ),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: Colors.black87, width: 1),
        boxShadow: down
            ? const [
                BoxShadow(
                    color: Colors.black54,
                    offset: Offset(0, 1),
                    blurRadius: 1),
              ]
            : const [
                BoxShadow(
                    color: Colors.black87,
                    offset: Offset(0, 2.5),
                    blurRadius: 3),
                BoxShadow(
                    color: Color(0x33FFFFFF),
                    offset: Offset(0, 1),
                    blurRadius: 0.5),
              ],
      ),
      child: Center(
        child: Transform.translate(
          offset: Offset(0, down ? 1 : 0),
          child: _label(),
        ),
      ),
    );
  }

  Widget _label() {
    final label = def.label;
    final size = label.length > 4 ? 11.0 : 13.0;
    final style = CalcTheme.keyLabel(size: size);
    if (label.endsWith('→')) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label.substring(0, label.length - 1), style: style),
          Icon(Icons.east, size: size + 2, color: style.color),
        ],
      );
    }
    return Text(label, style: style);
  }
}
