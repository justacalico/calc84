import 'dart:math' as math;

import '../engine/calculus.dart';
import '../engine/context.dart';
import '../engine/evaluator.dart';
import '../engine/value.dart';
import '../model/settings.dart';

/// Which curve families exist for the current graph mode.
class EquationSet {
  EquationSet(this.names);

  final List<String> names;
}

/// A marker produced by the CALC menu (zero, min, max, intersect).
class CalcMarker {
  CalcMarker(this.label, this.x, this.y);
  final String label;
  final double x, y;
}

/// Drives the graph screen: sampling, the free cursor, tracing,
/// zoom operations and the CALC workflows.
class GraphController {
  GraphController(this.ctx, this.modes, this.window, this.format);

  final CalcContext ctx;
  final ModeSettings modes;
  final WindowSettings window;
  final FormatSettings format;

  WindowSettings? previousWindow;
  WindowSettings? storedWindow;

  /// Free cursor position in graph coordinates.
  double cursorX = 0;
  double cursorY = 0;
  bool cursorVisible = false;

  /// Trace state.
  bool tracing = false;
  int traceIndex = 0;
  double traceParam = 0; // X in func, T in par, theta in pol, n in seq
  int traceN = 1;

  /// CALC menu operation in progress.
  String? calcOp; // value|zero|min|max|intersect|dydx|int
  int calcStep = 0;
  final List<double> calcBounds = [];
  int calcFirst = 0;
  double? calcGuess;
  final List<CalcMarker> markers = [];

  /// ZBox state.
  bool boxing = false;
  double? boxX1, boxY1;

  /// Integral shading region.
  (double, double)? integralShade;
  String? integralEq;

  List<String> get equationNames => switch (modes.graph) {
        GraphMode.func => ['Y1', 'Y2', 'Y3', 'Y4', 'Y5', 'Y6', 'Y7',
            'Y8', 'Y9', 'Y0'],
        GraphMode.parametric => ['X1T', 'X2T', 'X3T', 'X4T', 'X5T', 'X6T'],
        GraphMode.polar => ['r1', 'r2', 'r3', 'r4', 'r5', 'r6'],
        GraphMode.sequence => ['u', 'v', 'w'],
      };

  List<String> get activeEquations => switch (modes.graph) {
        GraphMode.parametric => [
            for (final n in equationNames)
              if ((ctx.equations[n]?.isDefined ?? false) &&
                  (ctx.equations[n]?.enabled ?? false) &&
                  (ctx.equations['Y${n[1]}T']?.isDefined ?? false) &&
                  (ctx.equations['Y${n[1]}T']?.enabled ?? false))
                n
          ],
        _ => [
            for (final n in equationNames)
              if ((ctx.equations[n]?.isDefined ?? false) &&
                  (ctx.equations[n]?.enabled ?? false))
                n
          ],
      };

  List<String> get sequenceNames =>
      ['u', 'v', 'w'].where((n) {
        final s = ctx.sequences[n];
        return s != null && s.isDefined && s.enabled;
      }).toList();

  /// Evaluate an equation with its independent variable bound.
  double? evalAt(String name, double t) {
    try {
      final varName = switch (modes.graph) {
        GraphMode.func => 'X',
        GraphMode.parametric => 'T',
        GraphMode.polar => 'θ',
        GraphMode.sequence => 'n',
      };
      double? result;
      final expr = ctx.equations[name]?.expression ??
          ctx.sequences[name]?.expression;
      if (expr == null) return null;
      result = _bindEval(varName, t, expr);
      return result;
    } catch (_) {
      return null;
    }
  }

  double? _bindEval(String varName, double t, String expr) {
    final saved = ctx.vars[varName];
    ctx.vars[varName] = t;
    try {
      final v = evalSource(expr, ctx).asReal;
      return v.isFinite ? v : null;
    } on CalcException {
      return null;
    } finally {
      if (saved == null) {
        ctx.vars.remove(varName);
      } else {
        ctx.vars[varName] = saved;
      }
    }
  }

  /// Parametric partner name: X1T -> Y1T.
  String _partnerOf(String name) =>
      name.startsWith('X') ? 'Y${name[1]}T' : 'X${name[1]}T';

  /// Screen point for a curve at parameter t.
  (double, double)? pointAt(String name, double t) {
    switch (modes.graph) {
      case GraphMode.func:
        final y = evalAt(name, t);
        return y == null ? null : (t, y);
      case GraphMode.parametric:
        final xn = name.startsWith('X') ? name : _partnerOf(name);
        final x = evalAt(xn, t);
        final y = evalAt(_partnerOf(xn), t);
        return (x == null || y == null) ? null : (x, y);
      case GraphMode.polar:
        final r = evalAt(name, t);
        return r == null ? null : (r * math.cos(t), r * math.sin(t));
      case GraphMode.sequence:
        final y = evalAt(name, t);
        return y == null ? null : (t, y);
    }
  }

  /// Parameter range for the curve.
  (double, double, double) paramRange() => switch (modes.graph) {
        GraphMode.func => (window.xMin, window.xMax, 0.0),
        GraphMode.parametric => (window.tMin, window.tMax, window.tStep),
        GraphMode.polar =>
          (window.thetaMin, window.thetaMax, window.thetaStep),
        GraphMode.sequence =>
          (window.nMin.toDouble(), window.nMax.toDouble(), 1.0),
      };

  /// Sample points for one equation, as a list of polylines (breaks
  /// on discontinuity).
  List<List<(double, double)>> plotPoints(String name, int width) {
    final out = <List<(double, double)>>[];
    var current = <(double, double)>[];
    switch (modes.graph) {
      case GraphMode.func:
        final samples = width * window.xRes.round().clamp(1, 8);
        for (var i = 0; i <= samples; i++) {
          final x = window.xMin + (window.xMax - window.xMin) * i / samples;
          final p = pointAt(name, x);
          if (p == null ||
              (modes.connected == ConnectedMode.connected &&
                  current.isNotEmpty &&
                  (p.$2 - current.last.$2).abs() >
                      (window.yMax - window.yMin) * 1.5)) {
            if (current.isNotEmpty) out.add(current);
            current = [];
            if (p == null) continue;
          }
          current.add(p);
          if (modes.connected == ConnectedMode.dot && current.length > 1) {
            out.add(current);
            current = [];
          }
        }
      case GraphMode.parametric || GraphMode.polar:
        final (lo, hi, step) = paramRange();
        final s = step <= 0 ? (hi - lo) / 150 : step;
        for (var t = lo; t <= hi + s * 0.5; t += s) {
          final p = pointAt(name, t.clamp(lo, hi));
          if (p == null) {
            if (current.isNotEmpty) out.add(current);
            current = [];
            continue;
          }
          current.add(p);
          if (modes.connected == ConnectedMode.dot && current.length > 1) {
            out.add(current);
            current = [];
          }
        }
      case GraphMode.sequence:
        for (var n = window.nMin; n <= window.nMax; n++) {
          if ((n - window.plotStart) % math.max(1, window.plotStep) != 0) {
            continue;
          }
          final p = pointAt(name, n.toDouble());
          if (p != null) current.add(p);
        }
    }
    if (current.isNotEmpty) out.add(current);
    return out;
  }

  // ---- zoom ---------------------------------------------------------------

  void _saveWindow() => previousWindow = window.copy();

  void zoomStandard() {
    _saveWindow();
    window.xMin = -10;
    window.xMax = 10;
    window.xScl = 1;
    window.yMin = -10;
    window.yMax = 10;
    window.yScl = 1;
    window.xRes = 1;
  }

  void zoomDecimal() {
    _saveWindow();
    window.xMin = -4.7;
    window.xMax = 4.7;
    window.xScl = 1;
    window.yMin = -3.1;
    window.yMax = 3.1;
    window.yScl = 1;
  }

  void zoomTrig() {
    _saveWindow();
    final rad = modes.angle == AngleMode.radian;
    window.xMin = rad ? -math.pi * 2.0933333 : -352.5;
    window.xMax = rad ? math.pi * 2.0933333 : 352.5;
    window.xScl = rad ? math.pi / 2 : 90;
    window.yMin = -4;
    window.yMax = 4;
    window.yScl = 1;
  }

  void zoomSquare() {
    _saveWindow();
    // Make pixels square given the classic 26.4:10-ish window ratio.
    const ratio = 95 / 63;
    final mid = (window.yMin + window.yMax) / 2;
    final half = (window.xMax - window.xMin) / 2 / ratio;
    window.yMin = mid - half;
    window.yMax = mid + half;
  }

  void zoomInteger() {
    _saveWindow();
    window.xMin = -47;
    window.xMax = 47;
    window.xScl = 10;
    window.yMin = -31;
    window.yMax = 31;
    window.yScl = 10;
  }

  void zoomIn([double factor = 4]) => _zoom(factor);

  void zoomOut([double factor = 4]) => _zoom(1 / factor);

  void _zoom(double factor) {
    _saveWindow();
    final cx = cursorVisible ? cursorX : (window.xMin + window.xMax) / 2;
    final cy = cursorVisible ? cursorY : (window.yMin + window.yMax) / 2;
    final hw = (window.xMax - window.xMin) / 2 / factor;
    final hh = (window.yMax - window.yMin) / 2 / factor;
    window.xMin = cx - hw;
    window.xMax = cx + hw;
    window.yMin = cy - hh;
    window.yMax = cy + hh;
  }

  void zoomPrevious() {
    final p = previousWindow;
    if (p == null) return;
    final cur = window.copy();
    window
      ..xMin = p.xMin
      ..xMax = p.xMax
      ..xScl = p.xScl
      ..yMin = p.yMin
      ..yMax = p.yMax
      ..yScl = p.yScl
      ..xRes = p.xRes;
    previousWindow = cur;
  }

  void zoomStore() => storedWindow = window.copy();

  void zoomRecall() {
    final s = storedWindow;
    if (s == null) return;
    window
      ..xMin = s.xMin
      ..xMax = s.xMax
      ..xScl = s.xScl
      ..yMin = s.yMin
      ..yMax = s.yMax
      ..yScl = s.yScl
      ..xRes = s.xRes;
  }

  void zoomFit() {
    _saveWindow();
    var lo = double.infinity;
    var hi = -double.infinity;
    for (final name in activeEquations) {
      for (final seg in plotPoints(name, 96)) {
        for (final p in seg) {
          if (p.$2 < lo) lo = p.$2;
          if (p.$2 > hi) hi = p.$2;
        }
      }
    }
    if (!lo.isFinite || !hi.isFinite) return;
    final pad = (hi - lo).abs() * 0.08;
    window.yMin = lo - pad;
    window.yMax = hi + pad;
  }

  /// ZoomStat: fit window around all stat plot points.
  void zoomStat(List<(double, double)> pts) {
    if (pts.isEmpty) return;
    _saveWindow();
    var x0 = double.infinity, x1 = -double.infinity;
    var y0 = double.infinity, y1 = -double.infinity;
    for (final p in pts) {
      x0 = math.min(x0, p.$1);
      x1 = math.max(x1, p.$1);
      y0 = math.min(y0, p.$2);
      y1 = math.max(y1, p.$2);
    }
    final dx = math.max(1, (x1 - x0) * 0.1);
    final dy = math.max(1, (y1 - y0) * 0.1);
    window.xMin = x0 - dx;
    window.xMax = x1 + dx;
    window.yMin = y0 - dy;
    window.yMax = y1 + dy;
  }

  void applyBox() {
    if (boxX1 == null || boxY1 == null) return;
    _saveWindow();
    final x0 = math.min(boxX1!, cursorX);
    final x1 = math.max(boxX1!, cursorX);
    final y0 = math.min(boxY1!, cursorY);
    final y1 = math.max(boxY1!, cursorY);
    if ((x1 - x0).abs() < 1e-12 || (y1 - y0).abs() < 1e-12) return;
    window.xMin = x0;
    window.xMax = x1;
    window.yMin = y0;
    window.yMax = y1;
    boxing = false;
    boxX1 = null;
    boxY1 = null;
  }

  // ---- tracing ---------------------------------------------------------------

  void startTrace() {
    tracing = true;
    traceIndex = 0;
    switch (modes.graph) {
      case GraphMode.func:
        traceParam = (window.xMin + window.xMax) / 2;
      case GraphMode.parametric:
        traceParam = window.tMin;
      case GraphMode.polar:
        traceParam = window.thetaMin;
      case GraphMode.sequence:
        traceN = window.plotStart;
    }
    _recenterOnTrace();
  }

  void stopTrace() => tracing = false;

  List<String> get traceables =>
      modes.graph == GraphMode.sequence ? sequenceNames : activeEquations;

  String? get traceName {
    final t = traceables;
    if (t.isEmpty) return null;
    return t[traceIndex.clamp(0, t.length - 1)];
  }

  (double, double)? get tracePoint {
    final name = traceName;
    if (name == null) return null;
    final t = modes.graph == GraphMode.sequence
        ? traceN.toDouble()
        : traceParam;
    return pointAt(name, t);
  }

  void traceLeft() {
    if (modes.graph == GraphMode.sequence) {
      traceN = math.max(window.nMin, traceN - 1);
      return;
    }
    final step = (window.xMax - window.xMin) / 94;
    traceParam -= step;
    final (lo, hi, s) = paramRange();
    if (s > 0) traceParam = traceParam.clamp(lo, hi);
  }

  void traceRight() {
    if (modes.graph == GraphMode.sequence) {
      traceN = math.min(window.nMax, traceN + 1);
      return;
    }
    final step = (window.xMax - window.xMin) / 94;
    traceParam += step;
    final (lo, hi, s) = paramRange();
    if (s > 0) traceParam = traceParam.clamp(lo, hi);
  }

  void traceUp() {
    final t = traceables;
    if (t.isNotEmpty) traceIndex = (traceIndex - 1) % t.length;
  }

  void traceDown() {
    final t = traceables;
    if (t.isNotEmpty) traceIndex = (traceIndex + 1) % t.length;
  }

  /// Typing a number while tracing jumps to that parameter value.
  void traceTo(double v) {
    if (modes.graph == GraphMode.sequence) {
      traceN = v.round().clamp(window.nMin, window.nMax);
    } else {
      traceParam = v;
      final (lo, hi, s) = paramRange();
      if (s > 0) traceParam = traceParam.clamp(lo, hi);
    }
  }

  void _recenterOnTrace() {
    final p = tracePoint;
    if (p == null) return;
    if (modes.graph != GraphMode.func) {
      cursorX = p.$1;
      cursorY = p.$2;
    }
    if (p.$2 < window.yMin || p.$2 > window.yMax) {
      final h = (window.yMax - window.yMin) / 2;
      window.yMin = p.$2 - h;
      window.yMax = p.$2 + h;
    }
  }

  /// Move the free cursor by pixels, converting to graph units.
  void moveCursor(double dx, double dy, double pxW, double pxH) {
    cursorVisible = true;
    cursorX += dx * (window.xMax - window.xMin) / pxW;
    cursorY -= dy * (window.yMax - window.yMin) / pxH;
  }

  // ---- CALC menu --------------------------------------------------------------

  String get calcPrompt {
    switch (calcOp) {
      case 'zero':
      case 'min':
      case 'max':
        return switch (calcStep) {
          0 => 'Left Bound?',
          1 => 'Right Bound?',
          _ => 'Guess?',
        };
      case 'intersect':
        return switch (calcStep) {
          0 => 'First curve?',
          1 => 'Second curve?',
          _ => 'Guess?',
        };
      case 'int':
        return calcStep == 0 ? 'Lower Limit?' : 'Upper Limit?';
      case 'value':
        return 'X=';
      case 'dydx':
        return 'X=';
    }
    return '';
  }

  /// Run the numeric CALC op once all inputs are gathered.
  /// Returns the marker, or null if it failed.
  CalcMarker? finishCalc() {
    final names = traceables;
    if (names.isEmpty) return null;
    final name = names[traceIndex.clamp(0, names.length - 1)];
    switch (calcOp) {
      case 'zero':
        return _root(name);
      case 'min':
        return _extremum(name, true);
      case 'max':
        return _extremum(name, false);
      case 'intersect':
        return _intersect(name, names);
      case 'dydx':
        return _derivative(name);
      case 'int':
        return _integral(name);
      case 'value':
        final x = calcGuess ?? cursorX;
        final y = evalAt(name, x);
        if (y == null) return null;
        return CalcMarker('Y=', x, y);
    }
    return null;
  }

  double Function(double) _f(String name) =>
      (x) => evalAt(name, x) ?? double.nan;

  CalcMarker? _root(String name) {
    final f = _f(name);
    try {
      var lo = calcBounds[0], hi = calcBounds[1];
      if (lo > hi) {
        final t = lo;
        lo = hi;
        hi = t;
      }
      final x = Calculus.solve(f, lo, hi);
      return CalcMarker('Zero', x, f(x));
    } catch (_) {
      return null;
    }
  }

  CalcMarker? _extremum(String name, bool min) {
    final f = _f(name);
    var lo = calcBounds[0], hi = calcBounds[1];
    if (lo > hi) {
      final t = lo;
      lo = hi;
      hi = t;
    }
    final x = min ? Calculus.fMin(f, lo, hi) : Calculus.fMax(f, lo, hi);
    return CalcMarker(min ? 'Minimum' : 'Maximum', x, f(x));
  }

  CalcMarker? _intersect(String name, List<String> names) {
    if (names.length < 2) return null;
    final other = names[(traceIndex + 1) % names.length];
    double f(double x) => _f(name)(x) - _f(other)(x);
    final g = calcGuess ?? (window.xMin + window.xMax) / 2;
    final span = (window.xMax - window.xMin) / 20;
    try {
      final x = Calculus.solve(f, g - span, g + span);
      return CalcMarker('Intersection', x, _f(name)(x));
    } catch (_) {
      return null;
    }
  }

  CalcMarker? _derivative(String name) {
    final x = calcGuess ?? cursorX;
    final d = Calculus.derivative(_f(name), x);
    return CalcMarker('dy/dx=', x, d);
  }

  CalcMarker? _integral(String name) {
    var lo = calcBounds[0], hi = calcBounds[1];
    if (lo > hi) {
      final t = lo;
      lo = hi;
      hi = t;
    }
    final v = Calculus.integrate(_f(name), lo, hi);
    integralShade = (lo, hi);
    integralEq = name;
    return CalcMarker('∫f(x)dx=', (lo + hi) / 2, v);
  }

  void clearCalc() {
    calcOp = null;
    calcStep = 0;
    calcBounds.clear();
    calcGuess = null;
    calcFirst = 0;
  }

  void reset() {
    tracing = false;
    cursorVisible = false;
    boxing = false;
    markers.clear();
    integralShade = null;
    clearCalc();
  }
}
