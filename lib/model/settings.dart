import 'dart:math' as math;

import '../engine/context.dart';
import '../engine/format.dart';

/// Which family of equations the graph screen plots.
enum GraphMode { func, parametric, polar, sequence }

enum ConnectedMode { connected, dot }

enum SequentialMode { sequential, simultaneous }

enum SplitMode { full, horiz, gt }

enum CoordMode { rect, polar }

enum GridStyle { off, dot, line }

/// All toggles found on the MODE screen.
class ModeSettings {
  Notation notation = Notation.normal;
  int decimals = -1; // -1 = Float
  AngleMode angle = AngleMode.radian;
  GraphMode graph = GraphMode.func;
  ComplexMode complex = ComplexMode.real;
  ConnectedMode connected = ConnectedMode.connected;
  SequentialMode sequential = SequentialMode.sequential;
  SplitMode split = SplitMode.full;
}

/// FORMAT (2nd ZOOM) options.
class FormatSettings {
  CoordMode coord = CoordMode.rect;
  bool coordOn = true;
  GridStyle grid = GridStyle.off;
  bool axesOn = true;
  bool labelOn = false;
  bool exprOn = true;
}

/// WINDOW / TBLSET values.
class WindowSettings {
  double xMin = -10;
  double xMax = 10;
  double xScl = 1;
  double yMin = -10;
  double yMax = 10;
  double yScl = 1;
  double xRes = 1;

  double tMin = 0;
  double tMax = math.pi * 4;
  double tStep = math.pi / 24;

  double thetaMin = 0;
  double thetaMax = math.pi * 2;
  double thetaStep = math.pi / 24;

  int nMin = 1;
  int nMax = 10;
  int plotStart = 1;
  int plotStep = 1;

  double tblStart = 0;
  double tblStep = 1;

  WindowSettings copy() => WindowSettings()
    ..xMin = xMin
    ..xMax = xMax
    ..xScl = xScl
    ..yMin = yMin
    ..yMax = yMax
    ..yScl = yScl
    ..xRes = xRes
    ..tMin = tMin
    ..tMax = tMax
    ..tStep = tStep
    ..thetaMin = thetaMin
    ..thetaMax = thetaMax
    ..thetaStep = thetaStep
    ..nMin = nMin
    ..nMax = nMax
    ..plotStart = plotStart
    ..plotStep = plotStep
    ..tblStart = tblStart
    ..tblStep = tblStep;
}

/// Stat plot definition (Plot1-3).
class StatPlot {
  bool on = false;
  StatPlotType type = StatPlotType.scatter;
  String xList = 'L1';
  String yList = 'L2';
  int mark = 0; // 0 = square, 1 = plus, 2 = dot
}

enum StatPlotType { scatter, xyLine, histogram, box, modBox }

/// A stored program.
class Program {
  Program(this.name, [this.source = '']);
  final String name;
  String source;
}

/// One drawn overlay object on the graph (DRAW menu).
sealed class Drawn {}

class DrawnLine extends Drawn {
  DrawnLine(this.x1, this.y1, this.x2, this.y2);
  final double x1, y1, x2, y2;
}

class DrawnHorizontal extends Drawn {
  DrawnHorizontal(this.y);
  final double y;
}

class DrawnVertical extends Drawn {
  DrawnVertical(this.x);
  final double x;
}

class DrawnFunction extends Drawn {
  DrawnFunction(this.expression);
  final String expression;
}

class DrawnTangent extends Drawn {
  DrawnTangent(this.equation, this.x);
  final String equation;
  final double x;
}

class DrawnPt extends Drawn {
  /// on=true draws, false erases, null toggles.
  DrawnPt(this.x, this.y, this.on);
  final double x, y;
  final bool? on;
}

class DrawnShade extends Drawn {
  DrawnShade(this.lower, this.upper, [this.lo, this.hi]);
  final String lower;
  final String upper;
  final double? lo;
  final double? hi;
}
