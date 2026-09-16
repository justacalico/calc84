import 'package:flutter/material.dart';

import '../model/keymap.dart';
import 'theme.dart';

/// One skeuomorphic plastic key with its 2nd/alpha legend above it.
class KeyButton extends StatelessWidget {
  const KeyButton({super.key, required this.def, required this.onPress});

  final KeyDef def;
  final void Function(KeyId) onPress;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 13,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (def.secondLabel != null)
                Padding(
                  padding: const EdgeInsets.only(left: 3),
                  child: Text(
                    def.secondLabel!,
                    style: CalcTheme.legend(color: CalcTheme.legend2nd),
                  ),
                )
              else
                const SizedBox.shrink(),
              if (def.alphaLabel != null)
                Padding(
                  padding: const EdgeInsets.only(right: 3),
                  child: Text(
                    def.alphaLabel!,
                    style: CalcTheme.legend(color: CalcTheme.legendAlpha),
                  ),
                )
              else
                const SizedBox.shrink(),
            ],
          ),
        ),
        _KeyCap(def: def, onPress: onPress),
      ],
    );
  }
}

class _KeyCap extends StatefulWidget {
  const _KeyCap({required this.def, required this.onPress});

  final KeyDef def;
  final void Function(KeyId) onPress;

  @override
  State<_KeyCap> createState() => _KeyCapState();
}

class _KeyCapState extends State<_KeyCap> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final (top, bottom) = switch (widget.def.style) {
      KeyStyle.blue => (CalcTheme.keyBlue, CalcTheme.keyBlueDark),
      KeyStyle.green => (CalcTheme.keyGreen, CalcTheme.keyGreenDark),
      KeyStyle.light => (CalcTheme.keyLightTop, CalcTheme.keyLightBottom),
      KeyStyle.dark => (CalcTheme.keyTop, CalcTheme.keyBottom),
    };
    return Expanded(
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) {
          setState(() => _down = false);
          widget.onPress(widget.def.id);
        },
        onTapCancel: () => setState(() => _down = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 60),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: _down ? [bottom, bottom] : [top, bottom],
            ),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: Colors.black87, width: 1),
            boxShadow: _down
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
              offset: Offset(0, _down ? 1 : 0),
              child: Text(
                widget.def.label,
                style: CalcTheme.keyLabel(
                  size: widget.def.label.length > 4 ? 11 : 13,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
