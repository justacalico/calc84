import 'dart:ui' as ui;

import 'package:calc84/model/keymap.dart';
import 'package:calc84/model/settings.dart';
import 'package:calc84/state/graphing.dart';
import 'package:calc84/state/calc_state.dart';
import 'package:flutter/material.dart';
import 'package:calc84/ui/display/graph_painter.dart';
import 'package:flutter_test/flutter_test.dart';

/// Graph painter branches: stat plots, markers, prompts, split labels,
/// and the remaining state paths for window fields and table output.
void main() {
  void paint(CalcState s) {
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    GraphPainter(s).paint(canvas, const Size(320, 240));
    rec.endRecording().dispose();
  }

  group('graph painter branches', () {
    CalcState base() {
      final s = CalcState();
      s.ctx.equation('Y1').expression = 'X²-4';
      return s;
    }

    test('box and modbox stat plots', () {
      final s = base();
      s.ctx.lists['L1'] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 100];
      s.plots[0]
        ..on = true
        ..type = StatPlotType.box
        ..xList = 'L1';
      s.plots[1]
        ..on = true
        ..type = StatPlotType.modBox
        ..xList = 'L1';
      s.plots[2]
        ..on = true
        ..type = StatPlotType.histogram
        ..xList = 'L1';
      paint(s);
      s.plots[1].type = StatPlotType.xyLine;
      s.plots[1].yList = 'L1';
      s.plots[2].type = StatPlotType.scatter;
      s.plots[2].yList = 'L1';
      for (var mk = 0; mk < 3; mk++) {
        s.plots[0].mark = mk;
        s.plots[1].mark = mk;
        s.plots[2].mark = mk;
        paint(s);
      }
    });

    test('markers and calc prompt overlays', () {
      final s = base();
      s.graph.markers.add(CalcMarker('Zero', 2, 0));
      paint(s);
      // Trace coordinate labels in each mode.
      for (final gm in GraphMode.values) {
        final s2 = CalcState();
        s2.modes.graph = gm;
        s2.ctx.equation('X1T').expression = 'T';
        s2.ctx.equation('Y1T').expression = 'T';
        s2.ctx.equation('r1').expression = 'θ';
        s2.ctx.sequences['u']!.expression = 'u(n-1)+1';
        s2.ctx.sequences['u']!.initial[0] = 1;
        s2.press(KeyId.graph);
        s2.press(KeyId.trace);
        s2.press(KeyId.right);
        paint(s2);
      }
    });

    test('graph prompt with cursor renders', () {
      final s = base();
      s.press(KeyId.graph);
      s.press(KeyId.second);
      s.press(KeyId.trace);
      s.press(KeyId.down);
      s.press(KeyId.enter); // zero
      s.insertText('-4');
      paint(s); // prompt + cursor rect drawn
      s.press(KeyId.enter);
      s.insertText('0');
      paint(s);
    });

    test('labels and dot mode', () {
      final s = base();
      s.format.labelOn = true;
      s.modes.connected = ConnectedMode.dot;
      paint(s);
      s.format.axesOn = false;
      s.format.grid = GridStyle.line;
      paint(s);
      s.format.grid = GridStyle.dot;
      s.format.coordOn = false;
      s.press(KeyId.trace);
      paint(s);
    });
  });

  group('table output', () {
    test('tableRows covers equations and delta column', () {
      final s = CalcState();
      s.ctx.equation('Y1').expression = 'X²';
      s.ctx.equation('Y2').expression = 'X+1';
      s.tblAskColX = false;
      final rows = s.tableRows(5);
      expect(rows.length, 5);
      expect(rows.first.length, 3);
    });
  });
}
