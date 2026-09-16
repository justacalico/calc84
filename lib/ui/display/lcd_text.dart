import 'package:flutter/material.dart';

import '../theme.dart';

/// One styled run of LCD text.
class LcdRun {
  const LcdRun(this.text, {this.inverse = false, this.dim = false});

  final String text;
  final bool inverse;
  final bool dim;
}

/// A line of LCD content.
class LcdLine {
  LcdLine(this.runs, {this.right = false, this.indent = 0});

  LcdLine.text(String text,
      {bool inverse = false, this.right = false, bool dim = false})
      : runs = [LcdRun(text, inverse: inverse, dim: dim)],
        indent = 0;

  final List<LcdRun> runs;
  final bool right;
  final double indent;
}

/// Cursor overlay description.
class LcdCursor {
  const LcdCursor(this.line, this.char, {this.insert = true});

  final int line;
  final int char;
  final bool insert;
}

/// What a text screen needs painted.
class ScreenContent {
  ScreenContent({
    required this.lines,
    this.cursor,
    this.indicator,
    this.pinBottom = true,
    this.scrollOffset = 0,
  });

  final List<LcdLine> lines;
  final LcdCursor? cursor;

  /// '2nd' or 'α' shown in the header area.
  final String? indicator;

  /// Home-style screens pin content to the bottom and scroll up.
  final bool pinBottom;
  final int scrollOffset;
}

/// Paints LcdLines with a proportional font, inverse video and a
/// block cursor.
class TextScreenPainter extends CustomPainter {
  TextScreenPainter(this.content, {this.showHeader = true});

  final ScreenContent content;
  final bool showHeader;

  static const double padX = 5;
  static const double headerH = 13;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Offset.zero & size, Paint()..color = CalcTheme.lcdBg);

    if (showHeader) {
      _header(canvas, size);
    }
    final top = showHeader ? headerH + 1 : 2.0;
    final lineH = (size.height - top - 3) / 10.5;
    final fontSize = lineH * 0.72;

    final lines = content.lines;
    var start = 0;
    var y = top;
    if (content.pinBottom) {
      final visible = ((size.height - top - 2) / lineH).floor();
      start = (lines.length - visible - content.scrollOffset)
          .clamp(0, lines.length);
      final end = (lines.length - content.scrollOffset)
          .clamp(0, lines.length);
      final shown = lines.sublist(start, end);
      y = size.height - 2 - shown.length * lineH;
      _paintLines(canvas, shown, y, lineH, fontSize, size, start);
    } else {
      _paintLines(canvas, lines, y, lineH, fontSize, size, 0);
    }
  }

  void _header(Canvas canvas, Size size) {
    final tp = TextPainter(
      text: TextSpan(
        text: content.indicator ?? '',
        style: CalcTheme.lcd(size: 9, bold: true, color: CalcTheme.lcdText),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, const Offset(padX, 1.5));
    canvas.drawLine(Offset(0, headerH), Offset(size.width, headerH),
        Paint()..color = CalcTheme.lcdGrid);
  }

  void _paintLines(Canvas canvas, List<LcdLine> lines, double y0,
      double lineH, double fontSize, Size size, int firstLineIndex) {
    var y = y0;
    for (var li = 0; li < lines.length; li++) {
      final line = lines[li];
      final globalLine = firstLineIndex + li;
      final isCursorLine =
          content.cursor != null && content.cursor!.line == globalLine;

      // Measure everything first for right alignment.
      final painters = <TextPainter>[];
      var w = 0.0;
      for (final run in line.runs) {
        final tp = TextPainter(
          text: TextSpan(
            text: run.text,
            style: CalcTheme.lcd(
                size: fontSize,
                color: run.inverse ? CalcTheme.lcdBg : CalcTheme.lcdText),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        painters.add(tp);
        w += tp.width;
      }

      var x = padX + line.indent;
      if (line.right) x = size.width - padX - w;

      var charIdx = 0;
      for (var ri = 0; ri < line.runs.length; ri++) {
        final run = line.runs[ri];
        final tp = painters[ri];
        if (run.inverse) {
          canvas.drawRect(
            Rect.fromLTWH(x, y, tp.width, lineH),
            Paint()..color = CalcTheme.lcdInverse,
          );
        }
        tp.paint(canvas, Offset(x, y + (lineH - tp.height) / 2));

        if (isCursorLine) {
          final cur = content.cursor!;
          final start = charIdx;
          final end = charIdx + run.text.length;
          if (cur.char >= start && cur.char <= end) {
            final local = cur.char - start;
            final before = run.text.substring(0, local);
            final bp = TextPainter(
              text: TextSpan(
                  text: before, style: CalcTheme.lcd(size: fontSize)),
              textDirection: TextDirection.ltr,
            )..layout();
            final cx = x + bp.width;
            final atEnd = local == run.text.length;
            final wBox = atEnd
                ? fontSize * 0.5
                : _charWidth(run.text[local], fontSize);
            canvas.drawRect(
              Rect.fromLTWH(cx, y + lineH - 2.5, wBox, 2),
              Paint()..color = CalcTheme.lcdText,
            );
          }
        }

        x += tp.width;
        charIdx += run.text.length;
      }
      y += lineH;
    }
  }

  double _charWidth(String c, double fontSize) {
    final tp = TextPainter(
      text: TextSpan(text: c, style: CalcTheme.lcd(size: fontSize)),
      textDirection: TextDirection.ltr,
    )..layout();
    return tp.width;
  }

  @override
  bool shouldRepaint(TextScreenPainter old) => true;
}
