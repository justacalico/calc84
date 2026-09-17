import '../../model/screens.dart';
import '../../model/settings.dart';
import '../../state/calc_state.dart';
import 'lcd_text.dart';

/// Builds the LCD content for every non-graph screen.
class ScreenBuilders {
  static ScreenContent build(CalcState s) {
    final c = switch (s.screen) {
      ScreenId.home => _home(s),
      ScreenId.yEquals => _yEquals(s),
      ScreenId.windowEdit => _fields(s, 'WINDOW', s.winFields(), s.winRow),
      ScreenId.tblset => _tblset(s),
      ScreenId.mode => _options(s, s.modeRows(), s.modeRow, s.modeCol),
      ScreenId.format => _options(s, s.formatRows(), s.fmtRow, s.fmtCol),
      ScreenId.table => _table(s),
      ScreenId.statPlots => _statPlots(s),
      ScreenId.statPlotEdit => _statPlotEdit(s),
      ScreenId.listEdit => _listEdit(s),
      ScreenId.matrixEdit => _matrixEdit(s),
      ScreenId.programList => _programList(s),
      ScreenId.programEdit => _programEdit(s),
      ScreenId.programName => _programName(s),
      ScreenId.solver => _solver(s),
      ScreenId.tvm => _tvm(s),
      ScreenId.memManage => _memManage(s),
      ScreenId.about => _about(s),
      ScreenId.clock => _clock(s),
      ScreenId.error => _error(s),
      _ => ScreenContent(lines: []),
    };
    final ind = s.modifierIndicator;
    if (ind.isNotEmpty) {
      return ScreenContent(
        lines: c.lines,
        cursor: c.cursor,
        indicator: ind,
        pinBottom: c.pinBottom,
        scrollOffset: c.scrollOffset,
      );
    }
    if (s.pendingRcl.isNotEmpty) {
      return ScreenContent(
        lines: [...c.lines, LcdLine.text('Rcl')],
        cursor: c.cursor,
        pinBottom: c.pinBottom,
        scrollOffset: c.scrollOffset,
      );
    }
    return c;
  }

  // ---- home ---------------------------------------------------------------

  static ScreenContent _home(CalcState s) {
    final lines = <LcdLine>[];
    var i = 0;
    for (final h in s.history) {
      if (h.input.isNotEmpty) {
        lines.add(LcdLine.text(h.input,
            inverse: s.historyCursor == i));
      }
      i++;
      for (final l in h.outputLines) {
        lines.add(LcdLine.text(l, right: true));
      }
      if (h.matrixGrid != null) {
        for (final row in h.matrixGrid!) {
          lines.add(LcdLine.text('[ ${row.join(' ')} ]', right: true));
        }
      }
    }
    final (text, cur) = s.entry.render();
    lines.add(LcdLine.text(text));
    return ScreenContent(
      lines: lines,
      cursor: LcdCursor(lines.length - 1, cur, insert: s.entry.insertMode),
    );
  }

  // ---- y= ------------------------------------------------------------------

  static ScreenContent _yEquals(CalcState s) {
    final lines = <LcdLine>[];
    final rows = s.eqRows();
    final header = switch (s.modes.graph) {
      GraphMode.func => 'FUNC',
      GraphMode.parametric => 'PAR',
      GraphMode.polar => 'POL',
      GraphMode.sequence => 'SEQ',
    };
    lines.add(LcdLine.text('$header  Plot1 Plot2 Plot3', dim: false));
    int? cursorLine;
    var cursorChar = 0;
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      final enabled = r.name.endsWith('(nMin)')
          ? true
          : (s.modes.graph == GraphMode.sequence
              ? s.ctx.sequences[r.name]?.enabled ?? false
              : s.ctx.equations[r.name]?.enabled ?? true);
      final nameInverse = i == s.activeEqRow && s.eqGutterActive;
      final label = '${r.name}=';
      final (text, cur) = r.line.render();
      lines.add(LcdLine([
        LcdRun(enabled ? label : '·$label', inverse: nameInverse),
        LcdRun(' $text'),
      ]));
      if (i == s.activeEqRow && !s.eqGutterActive) {
        cursorLine = lines.length - 1;
        cursorChar = cur + label.length + 1;
      }
    }
    return ScreenContent(
      lines: lines,
      pinBottom: false,
      cursor: cursorLine == null
          ? null
          : LcdCursor(cursorLine, cursorChar),
    );
  }

  // ---- generic field editors -------------------------------------------------

  static ScreenContent _fields(
      CalcState s, String title, List<Field> fields, int row) {
    final lines = <LcdLine>[LcdLine.text(title, inverse: true)];
    LcdCursor? cursor;
    for (var i = 0; i < fields.length; i++) {
      final f = fields[i];
      final (text, cur) = f.line.render();
      lines.add(LcdLine([LcdRun(f.label), LcdRun(text)]));
      if (i == row) {
        cursor = LcdCursor(i + 1, f.label.length + cur);
      }
    }
    return ScreenContent(lines: lines, pinBottom: false, cursor: cursor);
  }

  static ScreenContent _tblset(CalcState s) {
    final lines = <LcdLine>[LcdLine.text('TABLE SETUP', inverse: true)];
    final fields = s.tblFields();
    LcdCursor? cursor;
    for (var i = 0; i < fields.length; i++) {
      final (text, cur) = fields[i].line.render();
      lines.add(LcdLine([LcdRun(fields[i].label), LcdRun(text)]));
      if (i == s.tblRow) {
        cursor = LcdCursor(i + 1, fields[i].label.length + cur);
      }
    }
    lines.add(LcdLine([
      const LcdRun('Indpnt: '),
      LcdRun('Auto', inverse: !s.indpntAsk && s.tblRow == 2),
      const LcdRun('  '),
      LcdRun('Ask', inverse: s.indpntAsk && s.tblRow == 2),
      if (!s.indpntAsk && s.tblRow == 2) const LcdRun(''),
    ]));
    lines.add(LcdLine([
      const LcdRun('Depend: '),
      LcdRun('Auto', inverse: !s.dependAsk && s.tblRow == 3),
      const LcdRun('  '),
      LcdRun('Ask', inverse: s.dependAsk && s.tblRow == 3),
    ]));
    return ScreenContent(lines: lines, pinBottom: false, cursor: cursor);
  }

  // ---- mode / format -------------------------------------------------------------

  static ScreenContent _options(
      CalcState s, List<(List<String>, int)> rows, int row, int col) {
    final lines = <LcdLine>[];
    for (var i = 0; i < rows.length; i++) {
      final (options, sel) = rows[i];
      final runs = <LcdRun>[];
      for (var j = 0; j < options.length; j++) {
        runs.add(LcdRun(options[j],
            inverse: j == sel || (i == row && j == col)));
        runs.add(const LcdRun(' '));
      }
      lines.add(LcdLine(runs));
    }
    return ScreenContent(lines: lines, pinBottom: false);
  }

  /// Table-only view used by the G-T split screen.
  static ScreenContent tableView(CalcState s) => _table(s);

  /// Home-only view used by the HORIZ split screen.
  static ScreenContent homeView(CalcState s) => _home(s);

  // ---- table ------------------------------------------------------------------------

  static ScreenContent _table(CalcState s) {
    final cols = s.tableColumns;
    final lines = <LcdLine>[
      LcdLine([
        for (final c in cols) LcdRun(' ${c.padRight(8)}', inverse: true),
      ]),
    ];
    final rows = s.visibleTableRows(9);
    for (final r in rows) {
      lines.add(LcdLine([
        for (var i = 0; i < r.length; i++)
          LcdRun(' ${r[i].padRight(8)}'),
      ]));
    }
    if (s.indpntAsk && s.tableEditingX) {
      final (text, cur) = s.cellLine.render();
      lines.add(LcdLine.text('X=$text'));
      return ScreenContent(
        lines: lines,
        pinBottom: false,
        cursor: LcdCursor(lines.length - 1, cur + 2),
      );
    }
    return ScreenContent(lines: lines, pinBottom: false);
  }

  // ---- stat plots ----------------------------------------------------------------------

  static ScreenContent _statPlots(CalcState s) {
    final lines = <LcdLine>[];
    for (var i = 0; i < 3; i++) {
      final p = s.plots[i];
      final label = '${i + 1}:Plot${i + 1}(${p.on ? 'On' : 'Off'})'
          ' ${p.xList},${p.yList}';
      lines.add(LcdLine.text(label, inverse: s.plotRow == i));
    }
    lines.add(LcdLine.text('4:PlotsOff', inverse: s.plotRow == 3));
    return ScreenContent(lines: lines, pinBottom: false);
  }

  static ScreenContent _statPlotEdit(CalcState s) {
    final p = s.plots[s.editingPlot];
    const types = ['Scatter', 'xyLine', 'Histogram', 'Box', 'ModBox'];
    const marks = ['□', '+', '•'];
    final lines = <LcdLine>[
      LcdLine.text('Plot${s.editingPlot + 1}', inverse: true),
      LcdLine([
        const LcdRun('  '),
        LcdRun('On', inverse: p.on && s.plotEditRow == 0),
        const LcdRun('  '),
        LcdRun('Off', inverse: !p.on && s.plotEditRow == 0),
      ]),
      LcdLine([
        const LcdRun('Type: '),
        for (var i = 0; i < types.length; i++)
          LcdRun(' ${types[i]} ',
              inverse: p.type.index == i && s.plotEditRow == 1),
      ]),
      LcdLine([
        const LcdRun('Xlist:'),
        LcdRun(' ${p.xList}', inverse: s.plotEditRow == 2),
      ]),
      LcdLine([
        const LcdRun('Ylist:'),
        LcdRun(' ${p.yList}', inverse: s.plotEditRow == 3),
      ]),
      LcdLine([
        const LcdRun('Mark: '),
        for (var i = 0; i < marks.length; i++)
          LcdRun(' ${marks[i]} ',
              inverse: p.mark == i && s.plotEditRow == 4),
      ]),
    ];
    return ScreenContent(lines: lines, pinBottom: false);
  }

  // ---- list editor ------------------------------------------------------------------------

  static ScreenContent _listEdit(CalcState s) {
    final names = s.listColumnNames();
    final lines = <LcdLine>[
      LcdLine([
        for (var c = 0; c < names.length; c++)
          LcdRun(' ${names[c].padRight(5)}', inverse: true),
      ]),
    ];
    for (var r = 0; r < 7; r++) {
      lines.add(LcdLine([
        for (var c = 0; c < names.length; c++)
          LcdRun(
            ' ${c == s.listCol && r == s.listRow ? '' : ''}'
            '${s.listCellText(c, r).padRight(5)}',
            inverse: c == s.listCol && r == s.listRow,
          ),
      ]));
    }
    final (text, cur) = s.cellLine.render();
    final col = s.listColumn(s.listCol);
    final cellText = s.listRow < col.length ? s.listCellText(s.listCol, s.listRow) : '';
    lines.add(LcdLine.text(
        '${names[s.listCol]}(${s.listRow + 1})=${cellEditing(s, cellText, text)}'));
    if (s.cellEditing) {
      return ScreenContent(
        lines: lines,
        pinBottom: false,
        cursor: LcdCursor(lines.length - 1,
            '${names[s.listCol]}(${s.listRow + 1})='.length + cur),
      );
    }
    return ScreenContent(lines: lines, pinBottom: false);
  }

  static String cellEditing(CalcState s, String cell, String edit) =>
      s.cellEditing ? edit : cell;

  // ---- matrix editor -------------------------------------------------------------------------

  static ScreenContent _matrixEdit(CalcState s) {
    final m = s.ctx.matrices[s.matrixName]!;
    final lines = <LcdLine>[
      LcdLine.text('MATRIX ${s.matrixName}   ${m.rows} x ${m.cols}',
          inverse: true),
    ];
    if (s.matRow == -1) {
      final (text, cur) = s.cellLine.render();
      lines.add(LcdLine([
        LcdRun('  ${m.rows}', inverse: s.matCol == 0),
        const LcdRun(' x '),
        LcdRun('${m.cols}', inverse: s.matCol == 1),
      ]));
      if (s.matCellEditing) {
        lines.add(LcdLine.text('${s.matCol == 0 ? "rows" : "cols"}=$text'));
        return ScreenContent(
            lines: lines,
            pinBottom: false,
            cursor: LcdCursor(lines.length - 1, 5 + cur));
      }
    }
    for (var r = 0; r < m.rows && r < 6; r++) {
      lines.add(LcdLine([
        const LcdRun('['),
        for (var c = 0; c < m.cols; c++)
          LcdRun(' ${_fmt(m.data[r][c])} ',
              inverse: r == s.matRow && c == s.matCol),
        const LcdRun(']'),
      ]));
    }
    if (s.matRow >= 0) {
      final (text, cur) = s.cellLine.render();
      final cell = s.matCellEditing
          ? text
          : _fmt(m.data[s.matRow][s.matCol.clamp(0, m.cols - 1)]);
      lines.add(LcdLine.text(
          '${s.matrixName}(${s.matRow + 1},${s.matCol + 1})=$cell'));
      if (s.matCellEditing) {
        return ScreenContent(
            lines: lines,
            pinBottom: false,
            cursor: LcdCursor(lines.length - 1, 8 + cur));
      }
    }
    return ScreenContent(lines: lines, pinBottom: false);
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() && v.abs() < 1e10 ? v.round().toString() : v.toStringAsPrecision(6);

  // ---- programs -------------------------------------------------------------------------------

  static ScreenContent _programList(CalcState s) {
    final lines = <LcdLine>[
      LcdLine([
        LcdRun(' EXEC ', inverse: s.prgmTab == 0),
        LcdRun(' EDIT ', inverse: s.prgmTab == 1),
        LcdRun(' NEW ', inverse: s.prgmTab == 2),
      ]),
    ];
    if (s.programs.isEmpty) {
      lines.add(LcdLine.text('  No programs'));
    }
    for (var i = 0; i < s.programs.length; i++) {
      lines.add(LcdLine.text('  ${s.programs[i].name}',
          inverse: s.prgmCursor == i));
    }
    return ScreenContent(lines: lines, pinBottom: false);
  }

  static ScreenContent _programName(CalcState s) {
    final (text, cur) = s.prgmNameLine.render();
    return ScreenContent(
      lines: [
        LcdLine.text('PROGRAM', inverse: true),
        LcdLine.text('  Name=$text'),
      ],
      pinBottom: false,
      cursor: LcdCursor(1, 7 + cur),
    );
  }

  static ScreenContent _programEdit(CalcState s) {
    final lines = <LcdLine>[
      LcdLine.text('PROGRAM:${s.prgmEditing ?? ''}', inverse: true),
    ];
    LcdCursor? cursor;
    for (var i = 0; i < s.prgmLines.length; i++) {
      final (text, cur) = s.prgmLines[i].render();
      lines.add(LcdLine.text(':$text'));
      if (i == s.prgmRow) {
        cursor = LcdCursor(lines.length - 1, cur + 1);
      }
    }
    return ScreenContent(lines: lines, pinBottom: false, cursor: cursor);
  }

  // ---- solver / tvm ---------------------------------------------------------------------------

  static ScreenContent _solver(CalcState s) {
    final lines = <LcdLine>[LcdLine.text('EQUATION SOLVER', inverse: true)];
    final fields = s.solverFields();
    LcdCursor? cursor;
    for (var i = 0; i < fields.length; i++) {
      final (text, cur) = fields[i].line.render();
      lines.add(LcdLine([LcdRun(fields[i].label), LcdRun(text)]));
      if (i == s.solverRow) {
        cursor = LcdCursor(i + 1, fields[i].label.length + cur);
      }
    }
    lines.add(LcdLine.text(''));
    lines.add(LcdLine.text('ALPHA+ENTER to solve'));
    return ScreenContent(lines: lines, pinBottom: false, cursor: cursor);
  }

  static ScreenContent _tvm(CalcState s) {
    final lines = <LcdLine>[LcdLine.text('TVM SOLVER', inverse: true)];
    LcdCursor? cursor;
    for (var i = 0; i < 7; i++) {
      final (text, cur) = s.tvmLines[i].render();
      lines.add(LcdLine(
          [LcdRun(CalcState.tvmLabels[i]), LcdRun(text)]));
      if (i == s.tvmRow) {
        cursor = LcdCursor(i + 1, CalcState.tvmLabels[i].length + cur);
      }
    }
    lines.add(LcdLine([
      const LcdRun('PMT:'),
      LcdRun(' END ', inverse: s.tvm.pmtEnd && s.tvmRow == 7),
      const LcdRun(' '),
      LcdRun(' BEGIN ', inverse: !s.tvm.pmtEnd && s.tvmRow == 7),
      if (s.tvm.pmtEnd && s.tvmRow != 7) const LcdRun(''),
    ]));
    lines.add(LcdLine.text('ALPHA+ENTER solves field'));
    return ScreenContent(lines: lines, pinBottom: false, cursor: cursor);
  }

  // ---- misc ------------------------------------------------------------------------------------

  static ScreenContent _memManage(CalcState s) {
    final items = s.memItems();
    final lines = <LcdLine>[
      LcdLine.text('MEM MANAGEMENT/DELETE', inverse: true),
    ];
    if (items.isEmpty) lines.add(LcdLine.text('  (empty)'));
    for (var i = 0; i < items.length && i < 10; i++) {
      lines.add(LcdLine.text(' ${items[i].$1.padRight(7)} ${items[i].$2}',
          inverse: s.memRow == i));
    }
    lines.add(LcdLine.text('DEL deletes item'));
    return ScreenContent(lines: lines, pinBottom: false);
  }

  static ScreenContent _about(CalcState s) {
    return ScreenContent(
      lines: [
        LcdLine.text('CALC-84', inverse: true),
        LcdLine.text(''),
        LcdLine.text('Open source graphing'),
        LcdLine.text('calculator'),
        LcdLine.text(''),
        LcdLine.text('OS 1.0.0'),
        LcdLine.text('AGPL-3.0'),
        LcdLine.text(''),
        LcdLine.text('RAM free: 1540323'),
      ],
      pinBottom: false,
    );
  }

  static ScreenContent _clock(CalcState s) {
    final now = DateTime.now();
    final t =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    final d =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return ScreenContent(
      lines: [
        LcdLine.text('CLOCK', inverse: true),
        LcdLine.text(''),
        LcdLine.text('  $t'),
        LcdLine.text('  $d'),
      ],
      pinBottom: false,
    );
  }

  static ScreenContent _error(CalcState s) {
    return ScreenContent(
      lines: [
        LcdLine.text('ERR:${s.errorCode}', inverse: true),
        LcdLine.text('1:Quit', inverse: s.errorItem == 0),
        LcdLine.text('2:Goto', inverse: s.errorItem == 1),
      ],
      pinBottom: false,
    );
  }

  // ---- menus ------------------------------------------------------------------------------------

  static ScreenContent menu(CalcState s, MenuModel m) {
    final lines = <LcdLine>[
      LcdLine([
        for (var i = 0; i < m.tabs.length; i++)
          LcdRun(' ${m.tabs[i]} ', inverse: i == m.tabIndex),
      ]),
    ];
    final items = m.tabItems;
    for (var i = 0; i < items.length && i < 9; i++) {
      final num = '${i + 1 == 10 ? 0 : i + 1}:';
      lines.add(LcdLine.text('$num${items[i].label}',
          inverse: i == m.selected));
    }
    if (items.length > 9) {
      lines.add(LcdLine.text('  ↓ more'));
    }
    return ScreenContent(lines: lines, pinBottom: false);
  }
}
