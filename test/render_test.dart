import 'dart:ui' as ui;

import 'package:calc84/engine/matrix.dart';
import 'package:calc84/model/entry.dart';
import 'package:calc84/model/keymap.dart';
import 'package:calc84/model/screens.dart';
import 'package:calc84/model/settings.dart';
import 'package:calc84/state/calc_state.dart';
import 'package:calc84/ui/display/graph_painter.dart';
import 'package:calc84/ui/display/screen_builders.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders every screen builder and the graph painter across the
/// supported modes so the whole display layer is exercised.
void main() {
  void paintGraph(CalcState s) {
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    GraphPainter(s).paint(canvas, const Size(320, 240));
    rec.endRecording().dispose();
  }

  CalcState at(ScreenId id, void Function(CalcState)? setup) {
    final s = CalcState();
    setup?.call(s);
    s.show(id);
    return s;
  }

  group('screen builders', () {
    test('home with history and matrix grid', () {
      final s = CalcState();
      s.insertText('2+3');
      s.press(KeyId.enter);
      s.insertText('[[1,2][3,4]]');
      s.press(KeyId.enter);
      s.insertText('{1,2,3}');
      s.press(KeyId.enter);
      s.press(KeyId.up);
      final c = ScreenBuilders.build(s);
      expect(c.lines, isNotEmpty);
      s.press(KeyId.second);
      expect(ScreenBuilders.build(s).indicator, isNotEmpty);
      s.press(KeyId.sto);
      expect(
          ScreenBuilders.build(s).lines.last.runs.single.text, 'Rcl');
    });

    test('every editor screen builds', () {
      final cases = <ScreenId>[
        ScreenId.yEquals,
        ScreenId.windowEdit,
        ScreenId.tblset,
        ScreenId.mode,
        ScreenId.format,
        ScreenId.table,
        ScreenId.statPlots,
        ScreenId.statPlotEdit,
        ScreenId.listEdit,
        ScreenId.matrixEdit,
        ScreenId.programList,
        ScreenId.programEdit,
        ScreenId.programName,
        ScreenId.solver,
        ScreenId.tvm,
        ScreenId.memManage,
        ScreenId.about,
        ScreenId.clock,
        ScreenId.error,
        ScreenId.off,
        ScreenId.matrixNames,
        ScreenId.menu,
      ];
      for (final id in cases) {
        final s = at(id, (s) {
          s.ctx.equation('Y1').expression = 'X²';
          s.ctx.lists['L1'] = [1, 2, 3];
          s.ctx.lists['L2'] = [4, 5, 6];
          s.ctx.setMatrix('[A]', Matrix(2, 2)..set(0, 0, 9));
          s.programs.add(Program('TEST', 'Disp 1'));
          s.editingPlot = 0;
          s.plots[0].on = true;
          s.matrixName = '[A]';
          s.prgmEditing = 'TEST';
          s.prgmLines = [EntryLine('Disp 1')];
          s.errorCode = 'SYNTAX';
        });
        expect(() => ScreenBuilders.build(s), returnsNormally,
            reason: '$id');
      }
    });

    test('menus build on every tab', () {
      final s = CalcState();
      s.ctx.lists['L1'] = [1];
      final factory = s.menus;
      final all = [
        factory.math(),
        factory.test(),
        factory.angle(),
        factory.distr(),
        factory.matrix(),
        factory.list(),
        factory.stat(),
        factory.draw(),
        factory.vars(),
        factory.zoom(),
        factory.calc(),
        factory.catalog(),
        factory.apps(),
        factory.link(),
        factory.mem(),
      ];
      for (final m in all) {
        for (var t = 0; t < m.tabs.length; t++) {
          m.tabIndex = t;
          for (var i = 0; i < m.tabItems.length; i++) {
            m.cursor[t] = i;
            expect(ScreenBuilders.menu(s, m).lines, isNotEmpty,
                reason: '${m.title} tab ${m.tabs[t]}');
          }
        }
      }
    });

    test('cell editing text', () {
      final s = CalcState();
      expect(ScreenBuilders.cellEditing(s, '5', '12'), isA<String>());
    });
  });

  group('graph painter', () {
    test('function mode with trace and cursor', () {
      final s = CalcState();
      s.ctx.equation('Y1').expression = 'X²';
      s.ctx.equation('Y2').expression = 'sin(X)';
      s.press(KeyId.graph);
      paintGraph(s);
      s.press(KeyId.trace);
      s.press(KeyId.right);
      paintGraph(s);
      s.press(KeyId.down);
      paintGraph(s);
    });

    test('parametric and polar modes', () {
      final s = CalcState();
      s.modes.graph = GraphMode.parametric;
      s.ctx.equation('X1T').expression = 'cos(T)';
      s.ctx.equation('Y1T').expression = 'sin(T)';
      paintGraph(s);
      s.graph.startTrace();
      s.graph.traceRight();
      paintGraph(s);

      s.modes.graph = GraphMode.polar;
      s.ctx.equation('r1').expression = '2sin(2θ)';
      paintGraph(s);
      s.graph.traceLeft();
      paintGraph(s);
    });

    test('sequence mode', () {
      final s = CalcState();
      s.modes.graph = GraphMode.sequence;
      s.ctx.sequences['u']!.expression = 'u(n-1)+1';
      s.ctx.sequences['u']!.initial[0] = 0;
      paintGraph(s);
      s.graph.startTrace();
      s.graph.traceRight();
      paintGraph(s);
    });

    test('stat plots, drawn objects, box zoom and markers', () {
      final s = CalcState();
      s.ctx.equation('Y1').expression = 'X²-4';
      s.ctx.lists['L1'] = [1, 2, 3, 4];
      s.ctx.lists['L2'] = [1, 4, 9, 16];
      s.plots[0].on = true;
      for (final t in StatPlotType.values) {
        s.plots[0].type = t;
        paintGraph(s);
      }
      s.plots[0].on = false;
      s.drawn.addAll([
        DrawnLine(0, 0, 5, 5),
        DrawnHorizontal(2),
        DrawnVertical(-3),
        DrawnFunction('X+1'),
        DrawnTangent('Y1', 2),
        DrawnPt(1, 1, true),
        DrawnPt(2, 2, false),
        DrawnPt(3, 3, null),
        DrawnShade('X-5', 'X²/4'),
        DrawnShade('0', '5', -2, 2),
      ]);
      paintGraph(s);

      // ZBox corner selection.
      s.press(KeyId.zoom);
      s.press(KeyId.enter);
      s.press(KeyId.right);
      s.press(KeyId.down);
      paintGraph(s);
      s.press(KeyId.enter);
      s.press(KeyId.left);
      s.press(KeyId.up);
      paintGraph(s);
      s.press(KeyId.enter);
      paintGraph(s);
    });

    test('grid styles, axes off, markers', () {
      final s = CalcState();
      s.ctx.equation('Y1').expression = 'X³/10';
      for (final g in GridStyle.values) {
        s.format.grid = g;
        paintGraph(s);
      }
      s.format.axesOn = false;
      paintGraph(s);
      s.format.axesOn = true;
      // CALC markers and integral shade.
      s.graph.calcOp = 'int';
      s.graph.calcBounds.addAll([-2, 2]);
      expect(s.graph.finishCalc(), isNotNull);
      paintGraph(s);
      s.graph.calcOp = 'value';
      s.graph.calcGuess = 1.5;
      expect(s.graph.finishCalc(), isNotNull);
      paintGraph(s);
    });

    test('every calc op produces markers or null safely', () {
      final s = CalcState();
      s.ctx.equation('Y1').expression = 'X²-4';
      s.ctx.equation('Y2').expression = '2X';
      s.press(KeyId.graph);
      s.press(KeyId.trace);
      for (final op in ['zero', 'min', 'max', 'int']) {
        s.graph.calcOp = op;
        s.graph.calcStep = 0;
        s.graph.calcBounds
          ..clear()
          ..addAll([-4, 0]);
        expect(s.graph.calcPrompt, isNotEmpty);
        s.graph.finishCalc();
      }
      s.graph.calcOp = 'intersect';
      s.graph.calcStep = 2;
      s.graph.calcGuess = 2;
      expect(s.graph.finishCalc(), isNotNull);
      s.graph.calcOp = 'dydx';
      s.graph.calcGuess = 1;
      expect(s.graph.finishCalc(), isNotNull);
      s.graph.clearCalc();
      expect(s.graph.calcPrompt, isEmpty);
    });

    test('all zoom presets', () {
      final s = CalcState();
      s.ctx.equation('Y1').expression = 'sin(X)';
      final g = s.graph;
      g.zoomStandard();
      g.zoomDecimal();
      g.zoomTrig();
      g.zoomSquare();
      g.zoomInteger();
      g.zoomIn();
      g.zoomOut();
      g.zoomPrevious();
      g.zoomStore();
      g.zoomIn();
      g.zoomRecall();
      g.zoomFit();
      s.ctx.lists['L1'] = [0, 1, 2];
      s.ctx.lists['L2'] = [2, 5, 3];
      g.zoomStat([(0, 0), (5, 5)]);
      g.startTrace();
      g.traceLeft();
      g.traceRight();
      g.traceUp();
      g.traceDown();
      g.traceTo(1.5);
      g.moveCursor(10, -5, 320, 240);
      g.stopTrace();
      paintGraph(s);
    });
  });

  group('context', () {
    test('sequences evaluate and cache', () {
      final s = CalcState();
      s.ctx.sequences['u']!.expression = 'u(n-1)+2';
      s.ctx.sequences['u']!.initial[0] = 3;
      expect(s.ctx.sequenceAt('u', 5), 11);
      expect(s.ctx.sequenceAt('u', 3), 7);
      s.ctx.clearSequenceCache();
      expect(s.ctx.sequenceAt('u', 5), 11);
      expect(() => s.ctx.sequenceAt('v', 5), throwsA(anything));
      s.ctx.reset();
      expect(s.ctx.getVar('A'), 0);
    });
  });
}
