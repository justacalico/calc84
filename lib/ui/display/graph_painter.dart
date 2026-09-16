import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../engine/evaluator.dart';
import '../../engine/format.dart';
import '../../engine/value.dart';
import '../../model/settings.dart';
import '../../state/calc_state.dart';
import '../theme.dart';

/// Renders the graph screen: grid, axes, curves, stat plots, drawn
/// objects, trace/free cursors, markers and prompts.
class GraphPainter extends CustomPainter {
  GraphPainter(this.s, {this.fmt});

  final CalcState s;
  final Formatter? fmt;

  double _px(double x, Size size) =>
      (x - s.window.xMin) / (s.window.xMax - s.window.xMin) * size.width;

  double _py(double y, Size size) =>
      size.height -
      (y - s.window.yMin) / (s.window.yMax - s.window.yMin) * size.height;

  double _xAt(double px, Size size) =>
      s.window.xMin + px / size.width * (s.window.xMax - s.window.xMin);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = CalcTheme.lcdBg);
    _grid(canvas, size);
    if (s.format.axesOn) _axes(canvas, size);
    _integralShade(canvas, size);
    _equations(canvas, size);
    _statPlots(canvas, size);
    _drawnObjects(canvas, size);
    _markers(canvas, size);
    if (s.graph.boxing) _boxSelect(canvas, size);
    _cursorLayer(canvas, size);
    _overlay(canvas, size);
  }

  void _grid(Canvas canvas, Size size) {
    final p = Paint()..color = CalcTheme.lcdGrid;
    switch (s.format.grid) {
      case GridStyle.off:
        return;
      case GridStyle.dot:
        for (var x = _firstTick(s.window.xMin, s.window.xScl);
            x <= s.window.xMax;
            x += s.window.xScl) {
          for (var y = _firstTick(s.window.yMin, s.window.yScl);
              y <= s.window.yMax;
              y += s.window.yScl) {
            canvas.drawCircle(Offset(_px(x, size), _py(y, size)), 0.8, p);
          }
        }
      case GridStyle.line:
        for (var x = _firstTick(s.window.xMin, s.window.xScl);
            x <= s.window.xMax;
            x += s.window.xScl) {
          canvas.drawLine(Offset(_px(x, size), 0),
              Offset(_px(x, size), size.height), p);
        }
        for (var y = _firstTick(s.window.yMin, s.window.yScl);
            y <= s.window.yMax;
            y += s.window.yScl) {
          canvas.drawLine(Offset(0, _py(y, size)),
              Offset(size.width, _py(y, size)), p);
        }
    }
  }

  double _firstTick(double lo, double step) =>
      step <= 0 ? lo : (lo / step).ceil() * step;

  void _axes(Canvas canvas, Size size) {
    final p = Paint()
      ..color = CalcTheme.lcdAxes
      ..strokeWidth = 1.2;
    if (s.window.yMin <= 0 && s.window.yMax >= 0) {
      final y = _py(0, size);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
      _ticks(canvas, size, true, y);
    }
    if (s.window.xMin <= 0 && s.window.xMax >= 0) {
      final x = _px(0, size);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
      _ticks(canvas, size, false, x);
    }
    if (s.format.labelOn) {
      _label(canvas, 'x', size.width - 10, _py(0, size) - 12);
      _label(canvas, 'y', _px(0, size) + 4, 3);
    }
  }

  void _ticks(Canvas canvas, Size size, bool xAxis, double at) {
    final p = Paint()
      ..color = CalcTheme.lcdAxes
      ..strokeWidth = 1;
    final scl = xAxis ? s.window.xScl : s.window.yScl;
    if (scl <= 0) return;
    final lo = xAxis ? s.window.xMin : s.window.yMin;
    final hi = xAxis ? s.window.xMax : s.window.yMax;
    for (var t = _firstTick(lo, scl); t <= hi; t += scl) {
      if (t.abs() < scl * 0.01) continue;
      if (xAxis) {
        final x = _px(t, size);
        canvas.drawLine(Offset(x, at - 2), Offset(x, at + 2), p);
      } else {
        final y = _py(t, size);
        canvas.drawLine(Offset(at - 2, y), Offset(at + 2, y), p);
      }
    }
  }

  void _label(Canvas canvas, String text, double x, double y,
      {Color? color, double size = 9}) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: CalcTheme.lcd(size: size, color: color ?? CalcTheme.lcdDim)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x, y));
  }

  static const _curveColors = [
    Color(0xFF2456C8), // blue
    Color(0xFFD02020), // red
    Color(0xFF1B8A3C), // green
    Color(0xFFC014C0), // magenta
    Color(0xFFE08800), // orange
    Color(0xFF00A0A8), // teal
    Color(0xFF000000),
    Color(0xFF8040C0),
    Color(0xFF608000),
    Color(0xFFC06020),
  ];

  void _equations(Canvas canvas, Size size) {
    final names = s.graph.activeEquations;
    for (var i = 0; i < names.length; i++) {
      final color = _curveColors[i % _curveColors.length];
      final paint = Paint()
        ..color = color
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke;
      final dot = Paint()..color = color;
      for (final seg in s.graph.plotPoints(names[i], size.width.round())) {
        if (s.modes.connected == ConnectedMode.dot ||
            s.modes.graph == GraphMode.sequence) {
          for (final p in seg) {
            canvas.drawCircle(Offset(_px(p.$1, size), _py(p.$2, size)), 1.3,
                dot);
          }
          continue;
        }
        final path = Path();
        var first = true;
        for (final p in seg) {
          final pt = Offset(_px(p.$1, size), _py(p.$2, size));
          if (pt.dy < -size.height * 2 || pt.dy > size.height * 3) {
            first = true;
            continue;
          }
          if (first) {
            path.moveTo(pt.dx, pt.dy);
            first = false;
          } else {
            path.lineTo(pt.dx, pt.dy);
          }
        }
        canvas.drawPath(path, paint);
      }
    }
  }

  void _statPlots(Canvas canvas, Size size) {
    for (var i = 0; i < s.plots.length; i++) {
      final plot = s.plots[i];
      if (!plot.on) continue;
      final color = _curveColors[(i + 4) % _curveColors.length];
      final xs = s.ctx.list(plot.xList);
      final ys = s.ctx.list(plot.yList);
      final pts = <Offset>[];
      for (var k = 0; k < xs.length && k < ys.length; k++) {
        pts.add(Offset(_px(xs[k], size), _py(ys[k], size)));
      }
      switch (plot.type) {
        case StatPlotType.scatter:
          _marks(canvas, pts, color, plot.mark);
        case StatPlotType.xyLine:
          _marks(canvas, pts, color, plot.mark);
          if (pts.length > 1) {
            final path = Path()..moveTo(pts[0].dx, pts[0].dy);
            for (final p in pts.skip(1)) {
              path.lineTo(p.dx, p.dy);
            }
            canvas.drawPath(
                path,
                Paint()
                  ..color = color
                  ..strokeWidth = 1.2
                  ..style = PaintingStyle.stroke);
          }
        case StatPlotType.histogram:
          _histogram(canvas, size, xs, color);
        case StatPlotType.box || StatPlotType.modBox:
          _boxPlot(canvas, size, xs, i, color);
      }
    }
  }

  void _marks(Canvas canvas, List<Offset> pts, Color color, int mark) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.4;
    for (final pt in pts) {
      switch (mark) {
        case 0:
          canvas.drawRect(
              Rect.fromCenter(center: pt, width: 4, height: 4), p);
        case 1:
          canvas.drawLine(
              pt - const Offset(3, 0), pt + const Offset(3, 0), p);
          canvas.drawLine(
              pt - const Offset(0, 3), pt + const Offset(0, 3), p);
        case 2:
          canvas.drawCircle(pt, 1.6, p);
      }
    }
  }

  void _histogram(Canvas canvas, Size size, List<double> data, Color color) {
    if (data.isEmpty) return;
    final bucket = s.window.xScl > 0 ? s.window.xScl : 1.0;
    final counts = <int, int>{};
    for (final v in data) {
      final b = (v / bucket).floor();
      counts[b] = (counts[b] ?? 0) + 1;
    }
    final p = Paint()
      ..color = color.withValues(alpha: 0.45)
      ..style = PaintingStyle.fill;
    final edge = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (final e in counts.entries) {
      final x0 = e.key * bucket;
      final rect = Rect.fromLTRB(
          _px(x0, size), _py(e.value.toDouble(), size),
          _px(x0 + bucket, size), _py(0, size));
      canvas.drawRect(rect, p);
      canvas.drawRect(rect, edge);
    }
  }

  void _boxPlot(Canvas canvas, Size size, List<double> data, int slot,
      Color color) {
    if (data.length < 5) return;
    final sorted = List.of(data)..sort();
    double q(double frac) {
      final pos = (sorted.length - 1) * frac;
      final lo = pos.floor();
      final hi = pos.ceil();
      return sorted[lo] + (sorted[hi] - sorted[lo]) * (pos - lo);
    }

    final q1 = q(0.25), med = q(0.5), q3 = q(0.75);
    var lo = sorted.first, hi = sorted.last;
    List<double> outliers = const [];
    if (s.plots[slot].type == StatPlotType.modBox) {
      final iqr = q3 - q1;
      final lf = q1 - 1.5 * iqr, hf = q3 + 1.5 * iqr;
      final inlier = sorted.where((v) => v >= lf && v <= hf).toList();
      outliers = sorted.where((v) => v < lf || v > hf).toList();
      if (inlier.isNotEmpty) {
        lo = inlier.first;
        hi = inlier.last;
      }
    }
    final yMid = s.window.yMin +
        (s.window.yMax - s.window.yMin) * (0.75 - slot * 0.2);
    final y0 = _py(yMid + (s.window.yMax - s.window.yMin) * 0.03, size);
    final y1 = _py(yMid - (s.window.yMax - s.window.yMin) * 0.03, size);
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.4;
    final yc = (y0 + y1) / 2;
    canvas.drawRect(
        Rect.fromLTRB(_px(q1, size), y0, _px(q3, size), y1), p);
    canvas.drawLine(Offset(_px(med, size), y0), Offset(_px(med, size), y1), p);
    canvas.drawLine(Offset(_px(lo, size), yc), Offset(_px(q1, size), yc), p);
    canvas.drawLine(Offset(_px(q3, size), yc), Offset(_px(hi, size), yc), p);
    for (final x in [lo, hi]) {
      canvas.drawLine(Offset(_px(x, size), yc - 3),
          Offset(_px(x, size), yc + 3), p);
    }
    for (final o in outliers) {
      canvas.drawCircle(Offset(_px(o, size), yc), 1.6, p);
    }
  }

  void _drawnObjects(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFF303234)
      ..strokeWidth = 1.3;
    for (final d in s.drawn) {
      switch (d) {
        case DrawnLine():
          canvas.drawLine(Offset(_px(d.x1, size), _py(d.y1, size)),
              Offset(_px(d.x2, size), _py(d.y2, size)), p);
        case DrawnHorizontal():
          canvas.drawLine(Offset(0, _py(d.y, size)),
              Offset(size.width, _py(d.y, size)), p);
        case DrawnVertical():
          canvas.drawLine(Offset(_px(d.x, size), 0),
              Offset(_px(d.x, size), size.height), p);
        case DrawnFunction():
          _plotInline(canvas, size, d.expression, p);
        case DrawnTangent():
          _tangent(canvas, size, d, p);
        case DrawnShade():
          _shade(canvas, size, d);
        case DrawnPt():
          if (d.on ?? true) {
            canvas.drawCircle(Offset(_px(d.x, size), _py(d.y, size)), 2, p);
          }
      }
    }
  }

  void _plotInline(Canvas canvas, Size size, String expr, Paint p) {
    final path = Path();
    var first = true;
    final n = size.width.round();
    for (var i = 0; i <= n; i++) {
      final x = _xAt(i.toDouble(), size);
      double? y;
      try {
        final saved = s.ctx.vars['X'];
        s.ctx.vars['X'] = x;
        final v = _evalInline(expr);
        if (saved == null) {
          s.ctx.vars.remove('X');
        } else {
          s.ctx.vars['X'] = saved;
        }
        y = v;
      } catch (_) {
        y = null;
      }
      if (y == null || !y.isFinite) {
        first = true;
        continue;
      }
      final pt = Offset(i.toDouble(), _py(y, size));
      if (first) {
        path.moveTo(pt.dx, pt.dy);
        first = false;
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    canvas.drawPath(path, p);
  }

  // _plotInline binds X around every call, so no save/restore here.
  double? _evalInline(String expr) {
    try {
      final name = expr.trim();
      final eq = s.ctx.equations[name];
      if (eq != null && eq.isDefined) {
        return evalSource(eq.expression, s.ctx).asReal;
      }
      return evalSource(expr, s.ctx).asReal;
    } catch (_) {
      return null;
    }
  }

  void _tangent(Canvas canvas, Size size, DrawnTangent d, Paint p) {
    // Tangent of an equation at x.
    double? f(double x) {
      final name = d.equation.trim();
      if (s.ctx.equations[name]?.isDefined ?? false) {
        final saved = s.ctx.vars['X'];
        s.ctx.vars['X'] = x;
        try {
          return evalSource(s.ctx.equations[name]!.expression, s.ctx)
              .asReal;
        } on CalcException {
          return null;
        } finally {
          if (saved == null) {
            s.ctx.vars.remove('X');
          } else {
            s.ctx.vars['X'] = saved;
          }
        }
      }
      return null;
    }

    final y0 = f(d.x);
    if (y0 == null) return;
    const h = 1e-4;
    final dy = (f(d.x + h) ?? y0) - (f(d.x - h) ?? y0);
    final slope = dy / (2 * h);
    final ya = y0 + slope * (s.window.xMin - d.x);
    final yb = y0 + slope * (s.window.xMax - d.x);
    canvas.drawLine(Offset(_px(s.window.xMin, size), _py(ya, size)),
        Offset(_px(s.window.xMax, size), _py(yb, size)), p);
  }

  void _shade(Canvas canvas, Size size, DrawnShade d) {
    final lo = d.lo ?? s.window.xMin;
    final hi = d.hi ?? s.window.xMax;
    final paint = Paint()..color = const Color(0x335577CC);
    final n = size.width.round();
    for (var i = 0; i <= n; i += 2) {
      final x = _xAt(i.toDouble(), size);
      if (x < lo || x > hi) continue;
      final saved = s.ctx.vars['X'];
      s.ctx.vars['X'] = x;
      double? a, b;
      try {
        a = evalSource(d.lower, s.ctx).asReal;
        b = evalSource(d.upper, s.ctx).asReal;
      } catch (_) {}
      if (saved == null) {
        s.ctx.vars.remove('X');
      } else {
        s.ctx.vars['X'] = saved;
      }
      if (a == null || b == null) continue;
      final y0 = _py(math.min(a, b), size);
      final y1 = _py(math.max(a, b), size);
      canvas.drawRect(Rect.fromLTRB(i.toDouble(), y1, i + 2, y0), paint);
    }
  }

  void _integralShade(Canvas canvas, Size size) {
    final r = s.graph.integralShade;
    final eq = s.graph.integralEq;
    if (r == null || eq == null) return;
    final paint = Paint()..color = const Color(0x3344AA33);
    for (var i = 0; i <= size.width.round(); i += 2) {
      final x = _xAt(i.toDouble(), size);
      if (x < r.$1 || x > r.$2) continue;
      final y = s.graph.evalAt(eq, x);
      if (y == null) continue;
      final y0 = _py(0, size);
      final y1 = _py(y, size);
      canvas.drawRect(
          Rect.fromLTRB(i.toDouble(), math.min(y0, y1), i + 2, math.max(y0, y1)),
          paint);
    }
  }

  void _markers(Canvas canvas, Size size) {
    for (final m in s.graph.markers) {
      final pt = Offset(_px(m.x, size), _py(m.y, size));
      canvas.drawCircle(
          pt,
          3,
          Paint()
            ..color = CalcTheme.lcdInverse
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2);
      _label(canvas, m.label, 4, size.height - 24, size: 8);
      _label(canvas, 'X=${_n(m.x)}  Y=${_n(m.y)}', 4, size.height - 13,
          size: 8);
    }
  }

  String _n(double v) => (fmt ?? Formatter(DisplaySettings())).num(v);

  void _boxSelect(Canvas canvas, Size size) {
    if (s.graph.boxX1 == null) return;
    final rect = Rect.fromPoints(
        Offset(_px(s.graph.boxX1!, size), _py(s.graph.boxY1!, size)),
        Offset(_px(s.graph.cursorX, size), _py(s.graph.cursorY, size)));
    canvas.drawRect(
        rect,
        Paint()
          ..color = CalcTheme.lcdText
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8);
  }

  void _cursorLayer(Canvas canvas, Size size) {
    final g = s.graph;
    if (g.tracing) {
      final p = g.tracePoint;
      if (p != null) {
        final pt = Offset(_px(p.$1, size), _py(p.$2, size));
        final c = Paint()..color = CalcTheme.lcdText;
        canvas.drawLine(pt - const Offset(4, 0), pt + const Offset(4, 0), c);
        canvas.drawLine(pt - const Offset(0, 4), pt + const Offset(0, 4), c);
      }
    } else if (g.cursorVisible || g.boxing) {
      final pt = Offset(_px(g.cursorX, size), _py(g.cursorY, size));
      final c = Paint()
        ..color = CalcTheme.lcdText
        ..strokeWidth = 1;
      canvas.drawLine(pt - const Offset(4, 0), pt + const Offset(4, 0), c);
      canvas.drawLine(pt - const Offset(0, 4), pt + const Offset(0, 4), c);
      canvas.drawCircle(pt, 2, c);
    }
  }

  void _overlay(Canvas canvas, Size size) {
    final g = s.graph;
    final f = fmt ?? Formatter(DisplaySettings());
    if (g.tracing && g.traceName != null && s.format.exprOn) {
      _label(canvas, g.traceName!, 4, 4, color: CalcTheme.lcdText, size: 10);
    }
    if (s.format.coordOn) {
      if (g.tracing) {
        final p = g.tracePoint;
        if (p != null) {
          final t = _traceCoordLabel(f, p);
          _label(canvas, t, 4, size.height - 13,
              color: CalcTheme.lcdText, size: 9);
        }
      } else if (g.cursorVisible || g.boxing) {
        final text = s.format.coord == CoordMode.rect
            ? 'X=${f.num(g.cursorX)}  Y=${f.num(g.cursorY)}'
            : 'R=${f.num(math.sqrt(g.cursorX * g.cursorX + g.cursorY * g.cursorY))}  θ=${f.num(math.atan2(g.cursorY, g.cursorX))}';
        _label(canvas, text, 4, size.height - 13,
            color: CalcTheme.lcdText, size: 9);
      }
    }
    if (g.calcOp != null) {
      _label(canvas, g.calcPrompt, 4, size.height - 24,
          color: CalcTheme.lcdText, size: 10);
    }
    if (s.graphPrompt != null) {
      final (text, cur) = s.promptLine.render();
      _label(canvas, '${s.graphPrompt}$text', 4, size.height - 13,
          color: CalcTheme.lcdText, size: 10);
      final tp = TextPainter(
        text: TextSpan(
            text: '${s.graphPrompt}${text.substring(0, cur)}',
            style: CalcTheme.lcd(size: 10)),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.drawRect(
          Rect.fromLTWH(4 + tp.width, size.height - 12, 5, 1.5),
          Paint()..color = CalcTheme.lcdText);
    }
  }

  String _traceCoordLabel(Formatter f, (double, double) p) {
    final g = s.graph;
    return switch (s.modes.graph) {
      GraphMode.parametric =>
        'T=${f.num(g.traceParam)}  X=${f.num(p.$1)}  Y=${f.num(p.$2)}',
      GraphMode.polar =>
        'θ=${f.num(g.traceParam)}  X=${f.num(p.$1)}  Y=${f.num(p.$2)}',
      GraphMode.sequence =>
        'n=${g.traceN}  ${g.traceName ?? 'u'}(n)=${f.num(p.$2)}',
      GraphMode.func => 'X=${f.num(p.$1)}  Y=${f.num(p.$2)}',
    };
  }

  @override
  bool shouldRepaint(GraphPainter old) => true;
}
