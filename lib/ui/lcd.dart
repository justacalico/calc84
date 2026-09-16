import 'package:flutter/material.dart';

import '../model/screens.dart';
import '../model/settings.dart';
import '../state/calc_state.dart';
import 'display/graph_painter.dart';
import 'display/lcd_text.dart';
import 'display/screen_builders.dart';
import 'theme.dart';

/// The LCD panel: bezel, glass effect, and whichever screen is active.
class Lcd extends StatelessWidget {
  const Lcd({super.key, required this.state});

  final CalcState state;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Container(
        decoration: BoxDecoration(
          color: CalcTheme.lcdEdge,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(
                color: Colors.black87,
                offset: Offset(0, 2),
                blurRadius: 4),
            BoxShadow(
                color: Color(0x22FFFFFF),
                offset: Offset(0, -1),
                blurRadius: 1),
          ],
          border: Border.all(color: Colors.black, width: 1.5),
        ),
        padding: const EdgeInsets.all(7),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: _LcdGlass(state: state),
        ),
      ),
    );
  }
}

class _LcdGlass extends StatelessWidget {
  const _LcdGlass({required this.state});

  final CalcState state;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        return Stack(
          children: [
            Positioned.fill(child: _ScreenBody(state: state)),
            // Glass sheen.
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: const Alignment(0.3, 0.3),
                      colors: [
                        Colors.white.withValues(alpha: 0.10),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ScreenBody extends StatelessWidget {
  const _ScreenBody({required this.state});

  final CalcState state;

  @override
  Widget build(BuildContext context) {
    if (state.screen == ScreenId.off) {
      return const ColoredBox(color: Color(0xFF0C0E0C));
    }
    if (state.menu != null) {
      return CustomPaint(
        painter:
            TextScreenPainter(ScreenBuilders.menu(state, state.menu!)),
      );
    }
    if (state.screen == ScreenId.graph) {
      return _graphSplit(context);
    }
    final content = ScreenBuilders.build(state);
    return CustomPaint(painter: TextScreenPainter(content));
  }

  Widget _graphSplit(BuildContext context) {
    switch (state.modes.split) {
      case SplitMode.full:
        return CustomPaint(painter: GraphPainter(state));
      case SplitMode.gt:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: CustomPaint(painter: GraphPainter(state))),
            Expanded(
              child: CustomPaint(
                painter: TextScreenPainter(
                    ScreenBuilders.tableView(state),
                    showHeader: false),
              ),
            ),
          ],
        );
      case SplitMode.horiz:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: CustomPaint(painter: GraphPainter(state))),
            Expanded(
              child: CustomPaint(
                painter: TextScreenPainter(
                    ScreenBuilders.homeView(state),
                    showHeader: false),
              ),
            ),
          ],
        );
    }
  }
}
