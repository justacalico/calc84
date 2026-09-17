import 'package:flutter/material.dart';

import '../state/calc_state.dart';
import 'keypad.dart';
import 'lcd.dart';
import 'theme.dart';

/// The calculator body: screen, branding strip, keypad, all with the
/// molded plastic look of the real hardware.
class CalculatorShell extends StatelessWidget {
  const CalculatorShell({super.key, required this.state});

  final CalcState state;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 860),
        child: AspectRatio(
          aspectRatio: 0.52,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [CalcTheme.bodyTop, CalcTheme.bodyBottom],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.black, width: 2),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black54,
                    blurRadius: 24,
                    offset: Offset(0, 10)),
                BoxShadow(
                    color: Color(0x2EFFFFFF),
                    blurRadius: 2,
                    offset: Offset(0, -1)),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
            child: Column(
              children: [
                const _Brand(),
                const SizedBox(height: 8),
                Lcd(state: state),
                const SizedBox(height: 10),
                Expanded(child: Keypad(onPress: state.press)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'CALC-84',
          style: CalcTheme.keyLabel(size: 15, color: CalcTheme.brand)
              .copyWith(letterSpacing: 1.5, fontStyle: FontStyle.italic),
        ),
      ],
    );
  }
}
