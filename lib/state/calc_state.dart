import 'package:flutter/foundation.dart';

import '../engine/context.dart';
import '../engine/evaluator.dart';
import '../engine/format.dart';
import '../engine/matrix.dart';
import '../engine/calculus.dart';
import '../engine/regressions.dart';
import '../engine/tibasic.dart';
import '../engine/tvm.dart';
import '../engine/value.dart';
import '../model/entry.dart';
import '../model/keymap.dart';
import '../model/screens.dart';
import '../model/settings.dart';
import 'graphing.dart';
import 'menus.dart';

enum Modifier { none, second, alpha, alphaLock }

/// Root calculator state. Owns memory, screens, and key dispatch.
class CalcState extends ChangeNotifier {
  CalcState() {
    registerInlineEval(evalSource);
    graph = GraphController(ctx, modes, window, format);
  }

  final CalcContext ctx = CalcContext();
  final ModeSettings modes = ModeSettings();
  final FormatSettings format = FormatSettings();
  final WindowSettings window = WindowSettings();
  final DisplaySettings display = DisplaySettings();
  final List<StatPlot> plots = [StatPlot(), StatPlot(), StatPlot()];
  final List<Program> programs = [];
  final List<Drawn> drawn = [];
  final Map<String, List<Drawn>> pics = {};
  late final GraphController graph;
  late final MenuFactory menus = MenuFactory(this);

  ScreenId screen = ScreenId.home;
  final List<ScreenId> _stack = [];
  Modifier mod = Modifier.none;

  // ---- home ---------------------------------------------------------------
  final EntryLine entry = EntryLine();
  final List<HistoryEntry> history = [];
  int historyCursor = -1;
  String pendingRcl = '';

  // ---- error --------------------------------------------------------------
  String errorCode = '';
  int errorItem = 0;

  // ---- menus ---------------------------------------------------------------
  MenuModel? menu;
  final List<MenuModel> _menuStack = [];

  // ---- y= editor -----------------------------------------------------------
  int eqRow = 0;
  bool eqGutter = false;
  final Map<String, EntryLine> eqLines = {};

  // ---- window / tblset ------------------------------------------------------
  int winRow = 0;
  int tblRow = 0;

  // ---- table -----------------------------------------------------------------
  int tblOffset = 0;
  int tblAskRow = -1;
  bool tblAskColX = true;
  final List<double> tblAskXs = [];
  bool indpntAsk = false;
  bool dependAsk = false;

  // ---- list editor -------------------------------------------------------------
  int listCol = 0;
  int listRow = 0;
  final EntryLine cellLine = EntryLine();
  bool cellEditing = false;

  // ---- matrix editor -------------------------------------------------------------
  String matrixName = '[A]';
  int matRow = -1; // -1 = dims row
  int matCol = 0;
  bool matCellEditing = false;

  // ---- programs ---------------------------------------------------------------------
  int prgmTab = 0; // 0 EXEC, 1 EDIT, 2 NEW
  int prgmCursor = 0;
  final EntryLine prgmNameLine = EntryLine();
  String? prgmEditing;
  int prgmRow = 0;
  List<EntryLine> prgmLines = [EntryLine()];
  ProgramRunner? running;

  // ---- solver -------------------------------------------------------------------------
  int solverRow = 0;
  final EntryLine solverEq = EntryLine();
  final EntryLine solverX = EntryLine();
  final EntryLine solverLo = EntryLine()..setText('-1ᴇ99');
  final EntryLine solverHi = EntryLine()..setText('1ᴇ99');

  // ---- tvm ------------------------------------------------------------------------------
  final tvm = TvmSolver();
  int tvmRow = 0;
  final tvmLines = <EntryLine>[
    for (var i = 0; i < 7; i++) EntryLine(),
  ];

  // ---- memory ---------------------------------------------------------------------------
  int memRow = 0;

  // ---- mode / format ----------------------------------------------------------------------
  int modeRow = 0;
  int fmtRow = 0;

  // ---- stat plots ---------------------------------------------------------------------------
  int plotRow = 0;
  int plotEditRow = 0;
  int editingPlot = 0;

  // ---- graph inline prompt (X= / bound entry) --------------------------------------------------
  String? graphPrompt;
  final EntryLine promptLine = EntryLine();
  void Function(double v)? promptApply;

  Formatter get formatter {
    display.notation = modes.notation;
    display.decimals = modes.decimals;
    return Formatter(display);
  }

  // ---------------------------------------------------------------------------

  void notify() => notifyListeners();

  void push(ScreenId id) {
    _stack.add(screen);
    screen = id;
    _fieldFresh = true;
    notify();
  }

  void show(ScreenId id) {
    screen = id;
    notify();
  }

  void pop() {
    screen = _stack.isNotEmpty ? _stack.removeLast() : ScreenId.home;
    notify();
  }

  void quit() {
    menu = null;
    _menuStack.clear();
    _stack.clear();
    running = null;
    screen = ScreenId.home;
    notify();
  }

  // =========================================================================
  // Key handling
  // =========================================================================

  void press(KeyId id) {
    ctx.lastKeyCode = _keyCode(id);
    if (screen == ScreenId.off) {
      if (id == KeyId.on) {
        screen = ScreenId.home;
        notify();
      }
      return;
    }
    if (screen == ScreenId.error) {
      _errorKey(id);
      return;
    }

    switch (id) {
      case KeyId.second:
        mod = mod == Modifier.second ? Modifier.none : Modifier.second;
        notify();
        return;
      case KeyId.alpha:
        mod = switch (mod) {
          Modifier.none || Modifier.second => Modifier.alpha,
          Modifier.alpha => Modifier.alphaLock,
          Modifier.alphaLock => Modifier.none,
        };
        notify();
        return;
      default:
        break;
    }

    final m = mod;
    if (m != Modifier.alphaLock) mod = Modifier.none;

    if (menu != null) {
      _menuKey(id, m);
      return;
    }

    final def = keyDefOf(id);
    final resolved = _resolve(def, m);
    if (resolved is _Insert) {
      _insert(resolved.text);
    } else if (resolved is _Cmd) {
      _command(resolved.cmd, id);
    }
    notify();
  }

  /// Physical key codes compatible with getKey.
  int _keyCode(KeyId id) => switch (id) {
        KeyId.yEqu => 11, KeyId.window => 12, KeyId.zoom => 13,
        KeyId.trace => 14, KeyId.graph => 15,
        KeyId.second => 21, KeyId.mode => 22, KeyId.del => 23,
        KeyId.right => 26, KeyId.left => 24, KeyId.up => 25,
        KeyId.down => 34,
        KeyId.alpha => 31, KeyId.xttn => 32, KeyId.stat => 33,
        KeyId.math => 41, KeyId.apps => 42, KeyId.prgm => 43,
        KeyId.vars => 44, KeyId.clear => 45,
        KeyId.xInv => 51, KeyId.sin => 52, KeyId.cos => 53,
        KeyId.tan => 54, KeyId.pow => 55,
        KeyId.xSq => 61, KeyId.comma => 62, KeyId.lParen => 63,
        KeyId.rParen => 64, KeyId.div => 65,
        KeyId.log => 71, KeyId.n7 => 72, KeyId.n8 => 73,
        KeyId.n9 => 74, KeyId.mul => 75,
        KeyId.ln => 81, KeyId.n4 => 82, KeyId.n5 => 83,
        KeyId.n6 => 84, KeyId.sub => 85,
        KeyId.sto => 91, KeyId.n1 => 92, KeyId.n2 => 93,
        KeyId.n3 => 94, KeyId.add => 95,
        KeyId.on => 101, KeyId.n0 => 102, KeyId.dot => 103,
        KeyId.neg => 104, KeyId.enter => 105,
      };

  Object? _resolve(KeyDef d, Modifier m) {
    switch (m) {
      case Modifier.second:
        if (d.secondInsert != null) return _Insert(d.secondInsert!);
        final c = _secondCmd(d.id);
        return c == null ? null : _Cmd(c);
      case Modifier.alpha:
      case Modifier.alphaLock:
        if (d.alphaInsert != null) return _Insert(d.alphaInsert!);
        final c = _alphaCmd(d.id);
        if (c != null) return _Cmd(c);
        if (d.alphaLabel != null) {
          final t = d.alphaLabel == ' ' ? ' ' : d.alphaLabel!;
          return _Insert(t);
        }
        return null;
      case Modifier.none:
        if (d.insert != null) return _Insert(d.insert!);
        final c = _primaryCmd(d.id);
        return c == null ? null : _Cmd(c);
    }
  }

  _C? _primaryCmd(KeyId id) => switch (id) {
        KeyId.yEqu => _C.yEquals,
        KeyId.window => _C.window,
        KeyId.zoom => _C.zoom,
        KeyId.trace => _C.trace,
        KeyId.graph => _C.graph,
        KeyId.mode => _C.mode,
        KeyId.del => _C.del,
        KeyId.up => _C.up,
        KeyId.down => _C.down,
        KeyId.left => _C.left,
        KeyId.right => _C.right,
        KeyId.xttn => _C.insertXttn,
        KeyId.stat => _C.stat,
        KeyId.math => _C.math,
        KeyId.apps => _C.apps,
        KeyId.prgm => _C.prgm,
        KeyId.vars => _C.vars,
        KeyId.clear => _C.clear,
        KeyId.on => _C.on,
        KeyId.enter => _C.enter,
        _ => null,
      };

  _C? _secondCmd(KeyId id) => switch (id) {
        KeyId.yEqu => _C.statPlot,
        KeyId.window => _C.tblset,
        KeyId.zoom => _C.format,
        KeyId.trace => _C.calc,
        KeyId.graph => _C.table,
        KeyId.mode => _C.quit,
        KeyId.del => _C.ins,
        KeyId.alpha => _C.aLock,
        KeyId.xttn => _C.link,
        KeyId.stat => _C.list,
        KeyId.math => _C.test,
        KeyId.apps => _C.angle,
        KeyId.prgm => _C.draw,
        KeyId.vars => _C.distr,
        KeyId.xInv => _C.matrix,
        KeyId.n0 => _C.catalog,
        KeyId.add => _C.mem,
        KeyId.sto => _C.rcl,
        KeyId.on => _C.off,
        KeyId.enter => _C.entry,
        _ => null,
      };

  _C? _alphaCmd(KeyId id) => switch (id) {
        KeyId.enter => _C.solve,
        _ => null,
      };

  // =========================================================================
  // Inserts
  // =========================================================================

  /// Operators that continue from Ans when pressed on an empty
  /// home entry line, like the real OS.
  static const _ansOps = {
    '+', '-', '*', '/', '^', '→', '²', '³', '°', '%', '!', '⁻¹', 'ᵀ',
    'and', 'or', 'xor', 'nPr', 'nCr',
  };

  void _insert(String text) {
    if (pendingRcl.isNotEmpty) {
      _finishRcl(text);
      return;
    }
    if (screen == ScreenId.home &&
        entry.isEmpty &&
        _ansOps.any(text.startsWith)) {
      entry.paste('Ans');
    }
    insertText(text);
  }

  /// Field rows replace their content on the first keystroke, like
  /// the WINDOW screen on real hardware.
  bool _fieldFresh = true;

  /// Paste text into whatever field is focused on the current screen.
  void insertText(String text) {
    if (screen == ScreenId.graph) {
      _graphTyping(text);
      return;
    }
    final e = _activeEntry();
    if (e == null) return;
    if (_fieldFresh &&
        switch (screen) {
          ScreenId.windowEdit ||
          ScreenId.tblset ||
          ScreenId.solver ||
          ScreenId.tvm =>
            true,
          _ => false,
        }) {
      e.clear();
    }
    _fieldFresh = false;
    e.paste(text);
    _afterEdit(e);
  }

  EntryLine? _activeEntry() => switch (screen) {
        ScreenId.home => entry,
        ScreenId.yEquals => _eqLines()[_safeEqRow()].line,
        ScreenId.windowEdit => _winFields()[winRow].line,
        ScreenId.tblset => _tblFields()[tblRow].line,
        ScreenId.solver => _solverFields()[solverRow].line,
        ScreenId.tvm => tvmRow < 7 ? tvmLines[tvmRow] : null,
        ScreenId.programName => prgmNameLine,
        ScreenId.programEdit => prgmLines[prgmRow.clamp(0, prgmLines.length - 1)],
        ScreenId.listEdit => cellLine,
        ScreenId.matrixEdit => cellLine,
        ScreenId.table => indpntAsk && tblAskColX ? cellLine : null,
        _ => null,
      };

  void _afterEdit(EntryLine e) {
    if (screen == ScreenId.yEquals) {
      final rows = _eqLines();
      final r = _safeEqRow();
      final name = rows[r].name;
      if (name.endsWith('(nMin)')) {
        final v = double.tryParse(e.text.trim()) ?? 0;
        ctx.sequences[name[0]]!.initial
          ..clear()
          ..add(v);
      } else if (modes.graph == GraphMode.sequence) {
        ctx.sequences[name]!.expression = e.text;
      } else {
        ctx.equation(name).expression = e.text;
      }
      ctx.clearSequenceCache();
    }
    if (screen == ScreenId.solver && solverRow == 0) {
      // equation text lives in solverEq
    }
    if (screen == ScreenId.programEdit) {
      _syncProgram();
    }
    if (screen == ScreenId.listEdit) cellEditing = true;
    if (screen == ScreenId.matrixEdit) matCellEditing = true;
  }

  void _finishRcl(String name) {
    final n = name.trim();
    pendingRcl = '';
    String text;
    if (ctx.lists.containsKey(n)) {
      text = '{${ctx.lists[n]!.map((v) => _numText(v)).join(' ')}}';
    } else if (ctx.matrices.containsKey(n)) {
      final m = ctx.matrices[n]!;
      text =
          '[${m.data.map((r) => r.map(_numText).join(' ')).join(' ; ')}]';
    } else if (ctx.strings.containsKey(n)) {
      text = '"${ctx.strings[n]}"';
    } else if (ctx.equations[n]?.isDefined ?? false) {
      text = ctx.equations[n]!.expression;
    } else {
      text = _numText(ctx.getVar(n));
    }
    insertText(text);
  }

  String _numText(double v) =>
      v == v.roundToDouble() && v.abs() < 1e15 ? v.round().toString() : '$v';

  // =========================================================================
  // Commands
  // =========================================================================

  void _command(_C c, KeyId id) {
    pendingRcl = '';
    switch (c) {
      case _C.yEquals:
        menu = null;
        push(ScreenId.yEquals);
      case _C.window:
        menu = null;
        _fieldCache.removeWhere((k, v) => k.startsWith('win'));
        push(ScreenId.windowEdit);
      case _C.zoom:
        _openMenu(menus.zoom());
      case _C.trace:
        if (screen == ScreenId.graph) {
          graph.tracing ? graph.stopTrace() : graph.startTrace();
        } else {
          push(ScreenId.graph);
          graph.startTrace();
        }
      case _C.graph:
        menu = null;
        push(ScreenId.graph);
      case _C.table:
        menu = null;
        push(ScreenId.table);
      case _C.tblset:
        menu = null;
        _fieldCache.remove('tbl');
        push(ScreenId.tblset);
      case _C.statPlot:
        menu = null;
        push(ScreenId.statPlots);
      case _C.format:
        menu = null;
        push(ScreenId.format);
      case _C.calc:
        _openMenu(menus.calc());
      case _C.mode:
        push(ScreenId.mode);
      case _C.quit:
        menu = null;
        _menuStack.clear();
        if (screen != ScreenId.home) {
          pop();
        }
      case _C.ins:
        final e = _activeEntry();
        if (e != null) e.insertMode = !e.insertMode;
      case _C.aLock:
        mod = Modifier.alphaLock;
      case _C.link:
        _openMenu(menus.link());
      case _C.list:
        _openMenu(menus.list());
      case _C.test:
        _openMenu(menus.test());
      case _C.angle:
        _openMenu(menus.angle());
      case _C.draw:
        _openMenu(menus.draw());
      case _C.distr:
        _openMenu(menus.distr());
      case _C.matrix:
        _openMenu(menus.matrix());
      case _C.catalog:
        _openMenu(menus.catalog());
      case _C.mem:
        _openMenu(menus.mem());
      case _C.rcl:
        pendingRcl = 'Rcl';
      case _C.off:
        screen = ScreenId.off;
      case _C.entry:
        if (screen == ScreenId.home && history.isNotEmpty) {
          entry.setText(history.last.input);
        }
      case _C.solve:
        if (screen == ScreenId.solver) {
          _runSolver();
        } else if (screen == ScreenId.tvm) {
          _runTvm();
        } else {
          openSolver();
        }
      case _C.insertXttn:
        insertText(switch (modes.graph) {
          GraphMode.func => 'X',
          GraphMode.parametric => 'T',
          GraphMode.polar => 'θ',
          GraphMode.sequence => 'n',
        });
      case _C.stat:
        _openMenu(menus.stat());
      case _C.math:
        _openMenu(menus.math());
      case _C.apps:
        _openMenu(menus.apps());
      case _C.prgm:
        menu = null;
        prgmCursor = 0;
        prgmTab = 0;
        push(ScreenId.programList);
      case _C.vars:
        _openMenu(menus.vars());
      case _C.clear:
        _clearKey();
      case _C.del:
        _delKey();
      case _C.up:
        _arrow(0, -1);
      case _C.down:
        _arrow(0, 1);
      case _C.left:
        _arrow(-1, 0);
      case _C.right:
        _arrow(1, 0);
      case _C.on:
        break; // cancel: modifier already cleared
      case _C.enter:
        _enterKey();
    }
  }

  void _openMenu(MenuModel m) {
    menu = m;
    _menuStack.clear();
    notify();
  }

  void _menuKey(KeyId id, Modifier m) {
    final mm = menu!;
    switch (id) {
      case KeyId.clear:
        menu = _menuStack.isNotEmpty ? _menuStack.removeLast() : null;
        notify();
        return;
      case KeyId.mode:
        if (m == Modifier.second) {
          quit();
          return;
        }
      case KeyId.up:
        final len = mm.tabItems.length;
        mm.cursor[mm.tabIndex] = (mm.selected - 1 + len) % len;
        notify();
        return;
      case KeyId.left:
        if (mm.tabs.length > 1) {
          mm.tabIndex = (mm.tabIndex - 1) % mm.tabs.length;
        }
        notify();
        return;
      case KeyId.right:
        if (mm.tabs.length > 1) {
          mm.tabIndex = (mm.tabIndex + 1) % mm.tabs.length;
        }
        notify();
        return;

      case KeyId.down:
        mm.cursor[mm.tabIndex] = (mm.selected + 1) % mm.tabItems.length;
        notify();
        return;
      case KeyId.enter:
        _menuSelect(mm.tabItems[mm.selected]);
        return;
      default:
        break;
    }
    // Digit shortcut: 1-9 select items, 0 selects item 10.
    final d = keyDefOf(id).insert;
    if (d != null && RegExp('^[0-9]\$').hasMatch(d) && m == Modifier.none) {
      var idx = d == '0' ? 9 : int.parse(d) - 1;
      if (idx < mm.tabItems.length) {
        _menuSelect(mm.tabItems[idx]);
        return;
      }
    }
    // Alpha shortcut for items past 9.
    if ((m == Modifier.alpha || m == Modifier.alphaLock) &&
        keyDefOf(id).alphaLabel != null &&
        keyDefOf(id).alphaLabel!.length == 1) {
      final letter = keyDefOf(id).alphaLabel!;
      final idx = 10 + (letter.codeUnitAt(0) - 65);
      if (idx >= 0 && idx < mm.tabItems.length) {
        _menuSelect(mm.tabItems[idx]);
      }
      return;
    }
    mod = Modifier.none;
    notify();
  }

  void _menuSelect(MenuItem item) {
    if (item.sub != null) {
      _menuStack.add(menu!);
      menu = item.sub!();
      notify();
      return;
    }
    menu = _menuStack.isNotEmpty ? _menuStack.removeLast() : null;
    if (item.insert != null) {
      insertText(item.insert!);
    }
    item.action?.call();
    notify();
  }

  // =========================================================================
  // CLEAR / DEL
  // =========================================================================

  void _clearKey() {
    switch (screen) {
      case ScreenId.home:
        if (running != null) {
          running = null;
        } else if (entry.isEmpty) {
          history.clear();
        } else {
          entry.clear();
        }
      case ScreenId.yEquals:
        _eqLines()[_safeEqRow()].line.clear();
        ctx.equation(_eqLines()[_safeEqRow()].name).expression = '';
      case ScreenId.windowEdit || ScreenId.tblset:
        _activeEntry()?.clear();
      case ScreenId.listEdit:
        final l = ctx.list(_listNames()[listCol]);
        if (listRow < l.length) l.removeAt(listRow);
        if (listRow >= l.length) listRow = l.length;
        cellLine.clear();
        cellEditing = false;
      case ScreenId.programEdit:
        if (prgmLines.length > 1) {
          prgmLines.removeAt(prgmRow.clamp(0, prgmLines.length - 1));
          prgmRow = prgmRow.clamp(0, prgmLines.length - 1);
          _syncProgram();
        } else {
          prgmLines[0].clear();
          _syncProgram();
        }
      case ScreenId.memManage:
        _memDelete();
      case ScreenId.graph:
        graph.reset();
      default:
        pop();
    }
  }

  void _delKey() {
    final e = _activeEntry();
    if (e == null) return;
    if (!e.delete()) e.backspace();
    _afterEdit(e);
  }

  // =========================================================================
  // Arrows
  // =========================================================================

  void _arrow(int dx, int dy) {
    switch (screen) {
      case ScreenId.home:
        if (dy != 0 && entry.isEmpty) {
          _scrollHistory(dy);
        } else if (dx != 0) {
          dx < 0 ? entry.left() : entry.right();
        }
      case ScreenId.yEquals:
        _eqArrow(dx, dy);
      case ScreenId.windowEdit:
        _fieldArrow(_winFields(), dx, dy, (r) => winRow = r, () => winRow);
      case ScreenId.tblset:
        _fieldArrow(_tblFields(), dx, dy, (r) => tblRow = r, () => tblRow);
      case ScreenId.solver:
        _fieldArrow(_solverFields(), dx, dy, (r) => solverRow = r,
            () => solverRow);
      case ScreenId.tvm:
        _tvmArrow(dx, dy);
      case ScreenId.table:
        _tableArrow(dx, dy);
      case ScreenId.listEdit:
        _listArrow(dx, dy);
      case ScreenId.matrixEdit:
        _matArrow(dx, dy);
      case ScreenId.programEdit:
        _prgmArrow(dx, dy);
      case ScreenId.programList:
        if (dx != 0) {
          prgmTab = (prgmTab + dx + 3) % 3;
        } else if (dy != 0) {
          final len = programs.isEmpty ? 1 : programs.length;
          prgmCursor = (prgmCursor + dy + len) % len;
        }
      case ScreenId.mode:
        if (dy != 0) {
          modeRow = (modeRow + dy).clamp(0, 7);
          modeCol = 0;
        } else if (dx != 0) {
          modeCol =
              (modeCol + dx).clamp(0, modeRows()[modeRow].$1.length - 1);
        }
      case ScreenId.format:
        if (dy != 0) {
          fmtRow = (fmtRow + dy).clamp(0, 5);
          fmtCol = 0;
        } else if (dx != 0) {
          fmtCol =
              (fmtCol + dx).clamp(0, formatRows()[fmtRow].$1.length - 1);
        }
      case ScreenId.statPlots:
        plotRow = (plotRow + dy).clamp(0, 3);
      case ScreenId.statPlotEdit:
        plotEditRow = (plotEditRow + dy).clamp(0, 4);
        if (dx != 0) _statPlotHArrow(dx);
      case ScreenId.memManage:
        memRow = (memRow + dy).clamp(0, _memItems().length - 1);
      case ScreenId.graph:
        _graphArrow(dx, dy);
      case ScreenId.matrixNames:
        break;
      default:
        final e = _activeEntry();
        if (e != null && dx != 0) {
          dx < 0 ? e.left() : e.right();
        }
    }
  }

  void _scrollHistory(int dy) {
    if (history.isEmpty) return;
    if (dy < 0) {
      historyCursor = historyCursor < 0
          ? history.length - 1
          : (historyCursor - 1).clamp(-1, history.length - 1);
    } else {
      if (historyCursor < 0) return;
      historyCursor++;
      if (historyCursor >= history.length) historyCursor = -1;
    }
  }

  void _fieldArrow(List<Field> fields, int dx, int dy,
      void Function(int) setRow, int Function() getRow) {
    final row = getRow();
    if (dy != 0) {
      _commitField(fields[row]);
      setRow((row + dy).clamp(0, fields.length - 1));
      _fieldFresh = true;
      return;
    }
    final e = fields[row].line;
    dx < 0 ? e.left() : e.right();
  }

  // =========================================================================
  // ENTER
  // =========================================================================

  void _enterKey() {
    switch (screen) {
      case ScreenId.home:
        _homeEnter();
      case ScreenId.yEquals:
        _eqEnter();
      case ScreenId.windowEdit:
        _fieldArrow(_winFields(), 0, 1, (r) => winRow = r, () => winRow);
      case ScreenId.tblset:
        _tblEnter();
      case ScreenId.solver:
        _fieldArrow(_solverFields(), 0, 1, (r) => solverRow = r,
            () => solverRow);
      case ScreenId.tvm:
        _tvmEnter();
      case ScreenId.table:
        _tableEnter();
      case ScreenId.listEdit:
        _listEnter();
      case ScreenId.matrixEdit:
        _matEnter();
      case ScreenId.programEdit:
        prgmLines.insert(prgmRow + 1, EntryLine());
        prgmRow++;
        _syncProgram();
      case ScreenId.programList:
        _prgmSelect();
      case ScreenId.programName:
        _prgmNameConfirm();
      case ScreenId.mode:
        modeSelect(modeRow, modeCol);
      case ScreenId.format:
        formatSelect(fmtRow, fmtCol);
      case ScreenId.statPlots:
        _statPlotsEnter();
      case ScreenId.statPlotEdit:
        _statPlotEditEnter();
      case ScreenId.memManage:
        _memDelete();
      case ScreenId.graph:
        _graphEnter();
      case ScreenId.matrixNames:
        break;
      default:
        break;
    }
  }

  // =========================================================================
  // Home evaluation
  // =========================================================================

  void _homeEnter() {
    if (historyCursor >= 0 && entry.isEmpty) {
      entry.setText(history[historyCursor].input);
      historyCursor = -1;
      return;
    }
    if (running != null && running!.io.paused) {
      _resumeProgram();
      return;
    }
    if (graphPrompt != null) return;
    final src = entry.text.trim();
    if (src.isEmpty) return;
    lastRegression = null;
    try {
      final out = _execute(src);
      ctx.ans = out;
      final reg = lastRegression;
      if (reg != null) {
        history.add(HistoryEntry(src, [
          reg.name,
          for (final f in reg.fields) '${f.$1}=${formatter.num(f.$2)}',
        ]));
        lastRegression = null;
        entry.clear();
        historyCursor = -1;
        _refreshEqLines();
        return;
      }
      final hint = _hintOf(src);
      final formatted = formatter.format(out, hint: hint);
      history.add(HistoryEntry(src, formatted.lines,
          matrixGrid: formatted.matrixGrid));
      entry.clear();
      historyCursor = -1;
      _refreshEqLines();
      if (history.length > 200) history.removeAt(0);
    } on CalcException catch (e) {
      _showError(e.code);
    } catch (e) {
      _showError('SYNTAX');
    }
  }

  String? _hintOf(String src) {
    for (final h in const ['▸Frac', '▸Dec', '▸DMS', '▸Rect', '▸Polar', '▸n/d', '▸Un/d']) {
      if (src.contains(h)) return h == '▸Dec' ? null : h;
    }
    return null;
  }

  /// Run one home-screen command or expression.
  Value _execute(String src) {
    // Multi-statement lines.
    final stmts = _splitTop(src);
    Value last = const RealValue(0);
    for (final s in stmts) {
      last = _executeOne(s.trim());
      ctx.ans = last;
    }
    return last;
  }

  List<String> _splitTop(String src) {
    final out = <String>[];
    final cur = StringBuffer();
    var inStr = false;
    var depth = 0;
    for (var i = 0; i < src.length; i++) {
      final c = src[i];
      if (c == '"') inStr = !inStr;
      if (!inStr) {
        if (c == '(' || c == '{') depth++;
        if (c == ')' || c == '}') depth--;
        if (c == ':' && depth == 0) {
          out.add(cur.toString());
          cur.clear();
          continue;
        }
      }
      cur.write(c);
    }
    out.add(cur.toString());
    return out;
  }

  Value _executeOne(String s) {
    if (s.isEmpty) return ctx.ans;
    // Command statements handled outside the expression parser.
    for (final cmd in _homeCommands.keys) {
      final key = cmd.trimRight();
      if (s.startsWith(key)) {
        return _homeCommands[cmd]!(s.substring(key.length).trimLeft());
      }
    }
    return evalSource(s, ctx);
  }

  late final Map<String, Value Function(String)> _homeCommands = {
    'ClrHome': (_) {
      history.clear();
      return const StringValue('Done');
    },
    'ClrDraw': (_) {
      drawn.clear();
      return const StringValue('Done');
    },
    'ClrAllLists': (_) {
      clearAllLists();
      return const StringValue('Done');
    },
    'ClrList ': (rest) {
      for (final n in rest.split(',')) {
        final name = n.trim();
        if (ctx.lists.containsKey(name)) ctx.lists[name]!.clear();
      }
      return const StringValue('Done');
    },
    'SetUpEditor': (_) {
      setupEditor();
      return const StringValue('Done');
    },
    'DelVar ': (rest) {
      ctx.vars.remove(rest.trim());
      return const StringValue('Done');
    },
    'Disp ': (rest) {
      final v = evalSource(rest, ctx);
      return v;
    },
    'Line(': (rest) => _drawCmd(rest, (r, a) {
          if (a.length < 4) throw const CalcException('ARGUMENT');
          drawn.add(DrawnLine(a[0], a[1], a[2], a[3]));
        }),
    'Horizontal ': (rest) => _drawCmd(rest, (r, a) {
          drawn.add(DrawnHorizontal(a[0]));
        }),
    'Vertical ': (rest) => _drawCmd(rest, (r, a) {
          drawn.add(DrawnVertical(a[0]));
        }),
    'DrawF ': (rest) => _drawCmd(rest, (r, a) {
          drawn.add(DrawnFunction(r.trim()));
        }, raw: true),
    'DrawInv ': (rest) => _drawCmd(rest, (r, a) {
          drawn.add(DrawnFunction('1/(${r.trim()})'));
        }, raw: true),
    'Tangent(': (rest) => _drawCmd(rest, (r, a) {
          final parts = _splitCmdArgs(r);
          if (parts.isEmpty) throw const CalcException('ARGUMENT');
          drawn.add(DrawnTangent(parts[0], a.isEmpty ? 0 : a.first));
        }, rawFirst: true),
    'Shade(': (rest) => _drawCmd(rest, (r, a) {
          final parts = _splitCmdArgs(r);
          if (parts.length < 2) throw const CalcException('ARGUMENT');
          drawn.add(DrawnShade(
            parts[0],
            parts[1],
            parts.length > 2 ? double.tryParse(parts[2]) : null,
            parts.length > 3 ? double.tryParse(parts[3]) : null,
          ));
        }, raw: true),
    'Pt-On(': (rest) => _drawCmd(rest, (r, a) {
          drawn.add(DrawnPt(a[0], a[1], true));
        }),
    'Pt-Off(': (rest) => _drawCmd(rest, (r, a) {
          drawn.add(DrawnPt(a[0], a[1], false));
        }),
    'Pt-Change(': (rest) => _drawCmd(rest, (r, a) {
          drawn.add(DrawnPt(a[0], a[1], null));
        }),
    'StorePic ': (rest) {
      pics[rest.trim()] = List.of(drawn);
      return const StringValue('Done');
    },
    'RecallPic ': (rest) {
      drawn
        ..clear()
        ..addAll(pics[rest.trim()] ?? const []);
      return const StringValue('Done');
    },
    '1-Var Stats ': (rest) => _regression(
        rest, (x, y, f) => Regressions.oneVar(x, f), oneVar: true),
    '2-Var Stats ': (rest) =>
        _regression(rest, (x, y, f) => Regressions.twoVar(x, y)),
    'Med-Med ': (rest) =>
        _regression(rest, (x, y, f) => Regressions.medMed(x, y)),
    'LinReg(ax+b) ': (rest) =>
        _regression(rest, (x, y, f) => Regressions.poly(x, y, 1)),
    'LinReg(a+bx) ': (rest) => _regression(
        rest, (x, y, f) => Regressions.poly(x, y, 1, name: 'LinReg')),
    'QuadReg ': (rest) =>
        _regression(rest, (x, y, f) => Regressions.poly(x, y, 2, name: 'QuadReg')),
    'CubicReg ': (rest) =>
        _regression(rest, (x, y, f) => Regressions.poly(x, y, 3, name: 'CubicReg')),
    'QuartReg ': (rest) =>
        _regression(rest, (x, y, f) => Regressions.poly(x, y, 4, name: 'QuartReg')),
    'LnReg ': (rest) =>
        _regression(rest, (x, y, f) => Regressions.lnReg(x, y)),
    'ExpReg ': (rest) =>
        _regression(rest, (x, y, f) => Regressions.expReg(x, y)),
    'PwrReg ': (rest) =>
        _regression(rest, (x, y, f) => Regressions.pwrReg(x, y)),
    'prgm': (rest) => _runProgramNamed(rest.trim()),
  };

  Value _drawCmd(String rest, void Function(String, List<double>) f,
      {bool raw = false, bool rawFirst = false}) {
    if (raw) {
      f(rest, const []);
      return const StringValue('Done');
    }
    if (rawFirst) {
      final parts = _splitCmdArgs(rest);
      final x = parts.length > 1 ? evalSource(parts[1], ctx).asReal : 0.0;
      f(rest, [x]);
      return const StringValue('Done');
    }
    final inner = rest.endsWith(')') ? rest.substring(0, rest.length - 1) : rest;
    final args = [
      for (final p in _splitCmdArgs(inner)) evalSource(p, ctx).asReal
    ];
    f(rest, args);
    return const StringValue('Done');
  }

  List<String> _splitCmdArgs(String s) {
    var t = s.trim();
    if (t.endsWith(')')) t = t.substring(0, t.length - 1);
    final out = <String>[];
    final cur = StringBuffer();
    var depth = 0;
    for (var i = 0; i < t.length; i++) {
      final c = t[i];
      if (c == '(' || c == '{' || c == '[') depth++;
      if (c == ')' || c == '}' || c == ']') depth--;
      if (c == ',' && depth == 0) {
        out.add(cur.toString().trim());
        cur.clear();
        continue;
      }
      cur.write(c);
    }
    if (cur.isNotEmpty) out.add(cur.toString().trim());
    return out;
  }

  Value _regression(
      String rest,
      RegressionResult Function(List<double> x, List<double> y,
              List<double>? freq)
          f,
      {bool oneVar = false}) {
    final args = _splitCmdArgs(rest);
    String? storeEq;
    var names = <String>['L1', 'L2'];
    var freqName = '';
    final positional = <String>[];
    for (final a in args) {
      if (a.startsWith('Y') && a.length == 2) {
        storeEq = a;
      } else {
        positional.add(a);
      }
    }
    if (positional.isNotEmpty) names[0] = positional[0];
    if (oneVar) {
      if (positional.length > 1) freqName = positional[1];
    } else {
      if (positional.length > 1) names[1] = positional[1];
      if (positional.length > 2) freqName = positional[2];
    }
    final x = _listFromArg(names[0]);
    final y = oneVar ? <double>[] : _listFromArg(names[1]);
    final freq = freqName.isNotEmpty ? _listFromArg(freqName) : null;
    final r = f(x, y, freq);
    if (storeEq != null && r.equationBuilder != null) {
      ctx.equation(storeEq).expression =
          r.equationBuilder!(r.coefficients);
    } else if (storeEq != null) {
      ctx.equation(storeEq).expression = _defaultEq(r);
    }
    lastRegression = r;
    return StringValue(r.name);
  }

  RegressionResult? lastRegression;

  String _defaultEq(RegressionResult r) {
    final c = r.coefficients;
    switch (r.name) {
      case 'ExpReg':
        return '${c['a']}*${c['b']}^X';
      case 'PwrReg':
        return '${c['a']}*X^${c['b']}';
      case 'LnReg':
        return '${c['a']}+${c['b']}ln(X)';
      default:
        var terms = <String>[];
        final names = ['a', 'b', 'c', 'd', 'e'];
        final degree = r.fields.length - (r.fields.any((f) => f.$1 == 'r²') ? 2 : 0);
        for (var i = 0; i < degree && i < names.length; i++) {
          final coeff = c[names[i]];
          if (coeff == null) continue;
          final p = degree - 1 - i;
          terms.add(p == 0
              ? '$coeff'
              : p == 1
                  ? '${coeff}X'
                  : '${coeff}X^$p');
        }
        return terms.join('+').replaceAll('+-', '-');
    }
  }

  List<double> _listFromArg(String name) {
    if (ctx.lists.containsKey(name)) return ctx.lists[name]!;
    final v = evalSource(name, ctx);
    if (v is ListValue) {
      return [for (final i in v.items) i.asReal];
    }
    throw const CalcException('DATA TYPE');
  }

  int _flushedIoLines = 0;

  Value _runProgramNamed(String name) {
    final p = programs.where((p) => p.name == name).firstOrNull;
    if (p == null) throw const CalcException('UNDEFINED');
    running = ProgramRunner(p.source, ctx);
    _flushedIoLines = 0;
    try {
      running!.run();
    } on CalcException {
      running = null;
      rethrow;
    }
    _flushProgramOutput();
    return const StringValue('Done');
  }

  void _flushProgramOutput() {
    final r = running!;
    for (var i = _flushedIoLines; i < r.io.lines.length; i++) {
      history.add(HistoryEntry('', [r.io.lines[i]]));
    }
    _flushedIoLines = r.io.lines.length;
    if (r.io.paused) {
      history.add(HistoryEntry('', [r.io.promptLabel ?? '?']));
    } else if (r.io.done) {
      history.add(HistoryEntry('', ['Done']));
      running = null;
    }
  }

  void _resumeProgram() {
    final r = running!;
    final src = entry.text.trim();
    try {
      r.resume(src);
    } on CalcException catch (e) {
      running = null;
      _showError(e.code);
      return;
    }
    entry.clear();
    _flushProgramOutput();
  }

  void _refreshEqLines() {
    for (final e in eqLines.entries) {
      final name = e.key;
      if (name.endsWith('(nMin)')) continue;
      final cur = ctx.equations[name]?.expression ??
          ctx.sequences[name]?.expression ??
          '';
      if (e.value.text != cur) e.value.setText(cur);
    }
  }

  void _showError(String code) {
    errorCode = code;
    errorItem = 0;
    push(ScreenId.error);
  }

  void _errorKey(KeyId id) {
    if (id == KeyId.up) {
      errorItem = (errorItem - 1).clamp(0, 1);
    } else if (id == KeyId.down) {
      errorItem = (errorItem + 1).clamp(0, 1);
    } else if (id == KeyId.enter || id == KeyId.clear || id == KeyId.on) {
      pop();
    } else if (id == KeyId.n1 || id == KeyId.n2) {
      pop();
    }
    notify();
  }

  // =========================================================================
  // y= editor
  // =========================================================================

  List<EqRow> _eqLines() {
    final names = switch (modes.graph) {
      GraphMode.func =>
        ['Y1', 'Y2', 'Y3', 'Y4', 'Y5', 'Y6', 'Y7', 'Y8', 'Y9', 'Y0'],
      GraphMode.parametric => [
          for (var i = 1; i <= 6; i++) ...['X${i}T', 'Y${i}T']
        ],
      GraphMode.polar => ['r1', 'r2', 'r3', 'r4', 'r5', 'r6'],
      GraphMode.sequence => [
          'u', 'v', 'w', 'u(nMin)', 'v(nMin)', 'w(nMin)'
        ],
    };
    return [
      for (final n in names)
        EqRow(n, eqLines.putIfAbsent(n, () {
          final l = EntryLine();
          if (n.endsWith('(nMin)')) {
            final seq = ctx.sequences[n[0]];
            l.setText(seq?.initial.isEmpty ?? true
                ? ''
                : _numText(seq!.initial.first));
          } else {
            l.setText(ctx.equations[n]?.expression ??
                ctx.sequences[n]?.expression ??
                '');
          }
          return l;
        })),
    ];
  }

  int _safeEqRow() => eqRow.clamp(0, _eqLines().length - 1);

  void _eqArrow(int dx, int dy) {
    final rows = _eqLines();
    if (dy != 0) {
      eqGutter = false;
      eqRow = (eqRow + dy).clamp(0, rows.length - 1);
      return;
    }
    if (eqGutter) {
      if (dx > 0) eqGutter = false;
      return;
    }
    final e = rows[_safeEqRow()].line;
    if (dx < 0) {
      if (e.cursor == 0) {
        eqGutter = true;
      } else {
        e.left();
      }
    } else {
      e.right();
    }
  }

  void _eqEnter() {
    final rows = _eqLines();
    final r = _safeEqRow();
    if (eqGutter) {
      final name = rows[r].name;
      if (name.endsWith('(nMin)')) return;
      if (modes.graph == GraphMode.sequence) {
        ctx.sequences[name]!.enabled = !ctx.sequences[name]!.enabled;
      } else {
        final eq = ctx.equation(name);
        eq.enabled = !eq.enabled;
        if (modes.graph == GraphMode.parametric) {
          final partner =
              name.startsWith('X') ? 'Y${name[1]}T' : 'X${name[1]}T';
          ctx.equation(partner).enabled = eq.enabled;
        }
      }
      return;
    }
    // Enter on a row commits and moves down.
    eqRow = (eqRow + 1).clamp(0, rows.length - 1);
  }

  // =========================================================================
  // Window / table settings
  // =========================================================================

  List<Field> _winFields() {
    Field f(String label, double Function() get, void Function(double) set) =>
        Field(label, EntryLine(), onCommit: (t) {
          final v = evalSource(t.isEmpty ? '0' : t, ctx).asReal;
          set(v);
        });
    switch (modes.graph) {
      case GraphMode.func:
        return _cachedFields('win', [
          () => f('Xmin=', () => window.xMin, (v) => window.xMin = v),
          () => f('Xmax=', () => window.xMax, (v) => window.xMax = v),
          () => f('Xscl=', () => window.xScl, (v) => window.xScl = v),
          () => f('Ymin=', () => window.yMin, (v) => window.yMin = v),
          () => f('Ymax=', () => window.yMax, (v) => window.yMax = v),
          () => f('Yscl=', () => window.yScl, (v) => window.yScl = v),
          () => f('Xres=', () => window.xRes, (v) => window.xRes = v),
        ]);
      case GraphMode.parametric:
        return _cachedFields('winP', [
          () => f('Tmin=', () => window.tMin, (v) => window.tMin = v),
          () => f('Tmax=', () => window.tMax, (v) => window.tMax = v),
          () => f('Tstep=', () => window.tStep, (v) => window.tStep = v),
          () => f('Xmin=', () => window.xMin, (v) => window.xMin = v),
          () => f('Xmax=', () => window.xMax, (v) => window.xMax = v),
          () => f('Xscl=', () => window.xScl, (v) => window.xScl = v),
          () => f('Ymin=', () => window.yMin, (v) => window.yMin = v),
          () => f('Ymax=', () => window.yMax, (v) => window.yMax = v),
          () => f('Yscl=', () => window.yScl, (v) => window.yScl = v),
        ]);
      case GraphMode.polar:
        return _cachedFields('winPol', [
          () => f('θmin=', () => window.thetaMin, (v) => window.thetaMin = v),
          () => f('θmax=', () => window.thetaMax, (v) => window.thetaMax = v),
          () => f('θstep=', () => window.thetaStep, (v) => window.thetaStep = v),
          () => f('Xmin=', () => window.xMin, (v) => window.xMin = v),
          () => f('Xmax=', () => window.xMax, (v) => window.xMax = v),
          () => f('Xscl=', () => window.xScl, (v) => window.xScl = v),
          () => f('Ymin=', () => window.yMin, (v) => window.yMin = v),
          () => f('Ymax=', () => window.yMax, (v) => window.yMax = v),
          () => f('Yscl=', () => window.yScl, (v) => window.yScl = v),
        ]);
      case GraphMode.sequence:
        return _cachedFields('winS', [
          () => f('nMin=', () => window.nMin.toDouble(),
              (v) => window.nMin = v.round()),
          () => f('nMax=', () => window.nMax.toDouble(),
              (v) => window.nMax = v.round()),
          () => f('PlotStart=', () => window.plotStart.toDouble(),
              (v) => window.plotStart = v.round()),
          () => f('PlotStep=', () => window.plotStep.toDouble(),
              (v) => window.plotStep = v.round()),
          () => f('Xmin=', () => window.xMin, (v) => window.xMin = v),
          () => f('Xmax=', () => window.xMax, (v) => window.xMax = v),
          () => f('Xscl=', () => window.xScl, (v) => window.xScl = v),
          () => f('Ymin=', () => window.yMin, (v) => window.yMin = v),
          () => f('Ymax=', () => window.yMax, (v) => window.yMax = v),
          () => f('Yscl=', () => window.yScl, (v) => window.yScl = v),
        ]);
    }
  }

  final Map<String, List<Field>> _fieldCache = {};

  List<Field> _cachedFields(String key, List<Field Function()> builders) {
    return _fieldCache.putIfAbsent(key, () {
      final fields = [for (final b in builders) b()];
      for (final f in fields) {
        final initial = _fieldInitial(f.label);
        f.line.setText(initial);
      }
      return fields;
    });
  }

  String _fieldInitial(String label) {
    final w = window;
    final v = switch (label) {
      'Xmin=' => w.xMin, 'Xmax=' => w.xMax, 'Xscl=' => w.xScl,
      'Ymin=' => w.yMin, 'Ymax=' => w.yMax, 'Yscl=' => w.yScl,
      'Xres=' => w.xRes,
      'Tmin=' => w.tMin, 'Tmax=' => w.tMax, 'Tstep=' => w.tStep,
      'θmin=' => w.thetaMin, 'θmax=' => w.thetaMax, 'θstep=' => w.thetaStep,
      'nMin=' => w.nMin.toDouble(), 'nMax=' => w.nMax.toDouble(),
      'PlotStart=' => w.plotStart.toDouble(),
      'PlotStep=' => w.plotStep.toDouble(),
      'TblStart=' => w.tblStart, 'ΔTbl=' => w.tblStep,
      _ => 0.0,
    };
    return _numText(v);
  }

  void _commitField(Field f) {
    try {
      f.onCommit?.call(f.line.text);
    } on CalcException catch (e) {
      _showError(e.code);
    }
  }

  List<Field> _tblFields() => _cachedFields('tbl', [
        () => Field('TblStart=', EntryLine(), onCommit: (t) {
              window.tblStart = evalSource(t.isEmpty ? '0' : t, ctx).asReal;
            }),
        () => Field('ΔTbl=', EntryLine(), onCommit: (t) {
              window.tblStep = evalSource(t.isEmpty ? '0' : t, ctx).asReal;
            }),
      ]);

  void _tblEnter() {
    if (tblRow == 2) {
      indpntAsk = !indpntAsk;
    } else if (tblRow == 3) {
      dependAsk = !dependAsk;
    } else {
      _fieldArrow(_tblFields(), 0, 1, (r) => tblRow = r, () => tblRow);
    }
  }

  // =========================================================================
  // Table
  // =========================================================================

  List<String> get tableColumns => [
        'X',
        for (final n in graph.activeEquations) n,
      ];

  List<List<String>> tableRows(int count) {
    final cols = tableColumns;
    final rows = <List<String>>[];
    if (indpntAsk) {
      for (var i = 0; i < tblAskXs.length && i < count; i++) {
        rows.add(_tableRow(tblAskXs[i], cols));
      }
      return rows;
    }
    for (var i = 0; i < count; i++) {
      final x = window.tblStart + (tblOffset + i) * window.tblStep;
      rows.add(_tableRow(x, cols));
    }
    return rows;
  }

  List<String> _tableRow(double x, List<String> cols) {
    return [
      _numText(x),
      for (var c = 1; c < cols.length; c++)
        (() {
          final v = graph.evalAt(cols[c], x);
          return v == null ? 'ERROR' : _numText(v);
        })(),
    ];
  }

  void _tableArrow(int dx, int dy) {
    if (indpntAsk) {
      if (dx != 0) tblAskColX = dx < 0;
      if (dy != 0) {
        tblAskRow = (tblAskRow + dy).clamp(0, tblAskXs.length);
        if (tblAskRow == tblAskXs.length) {
          cellLine.clear();
        } else if (tblAskRow >= 0) {
          cellLine.setText(_numText(tblAskXs[tblAskRow]));
        }
      }
      return;
    }
    tblOffset += dy;
    if (tblOffset < 0) tblOffset = 0;
  }

  void _tableEnter() {
    if (!indpntAsk) return;
    try {
      final v = evalSource(cellLine.text.isEmpty ? '0' : cellLine.text, ctx)
          .asReal;
      if (tblAskRow >= 0 && tblAskRow < tblAskXs.length) {
        tblAskXs[tblAskRow] = v;
      } else {
        tblAskXs.add(v);
      }
      tblAskRow = tblAskXs.length;
      cellLine.clear();
    } on CalcException catch (e) {
      _showError(e.code);
    }
  }

  // =========================================================================
  // List editor
  // =========================================================================

  List<String> _listNames() => ['L1', 'L2', 'L3', 'L4', 'L5', 'L6'];

  void openListEditor() {
    listCol = 0;
    listRow = 0;
    cellEditing = false;
    cellLine.clear();
    push(ScreenId.listEdit);
  }

  void setupEditor() {
    ctx.lists
      ..clear()
      ..addAll({for (var i = 1; i <= 6; i++) 'L$i': <double>[]});
  }

  void clearAllLists() {
    for (final l in ctx.lists.values) {
      l.clear();
    }
  }

  void _listArrow(int dx, int dy) {
    if (cellEditing) {
      _commitCell();
      cellEditing = false;
    }
    final l = ctx.list(_listNames()[listCol]);
    if (dx != 0) {
      listCol = (listCol + dx).clamp(0, _listNames().length - 1);
      listRow = listRow.clamp(0, ctx.list(_listNames()[listCol]).length);
    }
    if (dy != 0) {
      listRow = (listRow + dy).clamp(0, l.length);
    }
    cellLine.clear();
  }

  void _commitCell() {
    if (cellLine.isEmpty) return;
    try {
      final v = evalSource(cellLine.text, ctx).asReal;
      final l = ctx.list(_listNames()[listCol]);
      if (listRow < l.length) {
        l[listRow] = v;
      } else {
        l.add(v);
      }
    } on CalcException catch (e) {
      _showError(e.code);
    }
    cellLine.clear();
  }

  void _listEnter() {
    _commitCell();
    _listArrow(0, 1);
  }

  // =========================================================================
  // Matrix editor
  // =========================================================================

  void openMatrixEditor(String name) {
    matrixName = name;
    ctx.matrices.putIfAbsent(name, () => Matrix(2, 2));
    matRow = -1;
    matCol = 0;
    matCellEditing = false;
    cellLine.clear();
    push(ScreenId.matrixEdit);
  }

  void _matArrow(int dx, int dy) {
    if (matCellEditing) {
      _commitMatCell();
      matCellEditing = false;
    }
    final m = ctx.matrices[matrixName]!;
    final cols = matRow == -1 ? 2 : m.cols;
    if (dx != 0) {
      matCol = (matCol + dx).clamp(0, cols - 1);
    }
    if (dy != 0) {
      matRow += dy;
      if (matRow < -1) matRow = -1;
      if (matRow > m.rows - 1) matRow = m.rows - 1;
      matCol = matCol.clamp(0, (matRow == -1 ? 2 : m.cols) - 1);
    }
    cellLine.clear();
  }

  void _commitMatCell() {
    if (cellLine.isEmpty) return;
    try {
      final v = evalSource(cellLine.text, ctx).asReal;
      final m = ctx.matrices[matrixName]!;
      if (matRow == -1) {
        _resizeMatrix(matCol == 0 ? v.round() : null,
            matCol == 1 ? v.round() : null);
      } else {
        m.set(matRow, matCol, v);
      }
    } on CalcException catch (e) {
      _showError(e.code);
    }
    cellLine.clear();
  }

  void _resizeMatrix(int? rows, int? cols) {
    final old = ctx.matrices[matrixName]!;
    final r = (rows ?? old.rows).clamp(1, 99);
    final c = (cols ?? old.cols).clamp(1, 99);
    final m = Matrix(r, c);
    for (var i = 0; i < r && i < old.rows; i++) {
      for (var j = 0; j < c && j < old.cols; j++) {
        m.data[i][j] = old.data[i][j];
      }
    }
    ctx.matrices[matrixName] = m;
  }

  void _matEnter() {
    if (matCellEditing) {
      _commitMatCell();
      matCellEditing = false;
    }
    final m = ctx.matrices[matrixName]!;
    final cols = matRow == -1 ? 2 : m.cols;
    if (matCol < cols - 1) {
      matCol++;
    } else if (matRow < m.rows - 1) {
      matCol = 0;
      matRow++;
    }
    cellLine.clear();
  }

  // =========================================================================
  // Programs
  // =========================================================================

  void _prgmArrow(int dx, int dy) {
    if (dy != 0) {
      prgmRow = (prgmRow + dy).clamp(0, prgmLines.length - 1);
      return;
    }
    final e = prgmLines[prgmRow];
    dx < 0 ? e.left() : e.right();
  }

  void _syncProgram() {
    final p = programs.where((p) => p.name == prgmEditing).firstOrNull;
    if (p != null) {
      p.source = prgmLines.map((l) => l.text).join('\n');
    }
  }

  void _prgmSelect() {
    if (programs.isEmpty) {
      if (prgmTab == 2) show(ScreenId.programName);
      return;
    }
    final p = programs[prgmCursor.clamp(0, programs.length - 1)];
    switch (prgmTab) {
      case 0: // EXEC
        menu = null;
        screen = ScreenId.home;
        entry.setText('prgm${p.name}');
        _homeEnter();
      case 1: // EDIT
        prgmEditing = p.name;
        prgmLines = [
          for (final l in p.source.split('\n')) EntryLine(l)
        ];
        if (prgmLines.isEmpty) prgmLines = [EntryLine()];
        prgmRow = 0;
        menu = null;
        push(ScreenId.programEdit);
      case 2: // NEW
        show(ScreenId.programName);
    }
  }

  void _prgmNameConfirm() {
    final name = prgmNameLine.text.trim();
    if (name.isEmpty) return;
    final p = Program(name, '');
    programs.add(p);
    prgmNameLine.clear();
    prgmEditing = name;
    prgmLines = [EntryLine()];
    prgmRow = 0;
    show(ScreenId.programEdit);
  }

  // =========================================================================
  // Solver
  // =========================================================================

  void openSolver() {
    solverRow = 0;
    menu = null;
    push(ScreenId.solver);
  }

  List<Field> _solverFields() => [
        Field('eqn: 0=', solverEq),
        Field('X=', solverX),
        Field('bound={', solverLo),
        Field('     ,', solverHi),
      ];

  void _runSolver() {
    try {
      final eqText = solverEq.text;
      final guess =
          solverX.text.isEmpty ? 1.0 : evalSource(solverX.text, ctx).asReal;
      double f(double x) {
        final saved = ctx.vars['X'];
        ctx.vars['X'] = x;
        try {
          return evalSource(eqText, ctx).asReal;
        } finally {
          if (saved == null) {
            ctx.vars.remove('X');
          } else {
            ctx.vars['X'] = saved;
          }
        }
      }
      final g = guess.abs() < 1 ? 1.0 : guess.abs();
      final root = Calculus.solve(f, guess - g, guess + g);
      solverX.setText(_numText(root));
      history.add(HistoryEntry('Solver', ['X=${_numText(root)}']));
    } on CalcException catch (e) {
      _showError(e.code);
    }
  }

  // =========================================================================
  // TVM
  // =========================================================================

  void openTvm() {
    tvmRow = 0;
    final vals = [tvm.n, tvm.i, tvm.pv, tvm.pmt, tvm.fv, tvm.py, tvm.cy];
    for (var i = 0; i < 7; i++) {
      tvmLines[i].setText(_numText(vals[i]));
    }
    menu = null;
    push(ScreenId.tvm);
  }

  static const tvmLabels = ['N=', 'I%=', 'PV=', 'PMT=', 'FV=', 'P/Y=', 'C/Y='];

  void _tvmArrow(int dx, int dy) {
    if (dy != 0) {
      if (tvmRow < 7) _commitTvmRow(tvmRow);
      tvmRow = (tvmRow + dy).clamp(0, 7);
      _fieldFresh = true;
    } else if (tvmRow < 7) {
      final e = tvmLines[tvmRow];
      dx < 0 ? e.left() : e.right();
    } else {
      tvm.pmtEnd = !tvm.pmtEnd;
    }
  }

  void _tvmEnter() {
    if (tvmRow == 7) {
      tvm.pmtEnd = !tvm.pmtEnd;
      return;
    }
    _commitTvmRow(tvmRow);
    tvmRow = (tvmRow + 1).clamp(0, 7);
    _fieldFresh = true;
  }

  void _commitTvmRow(int r) {
    try {
      final v = evalSource(
          tvmLines[r].text.isEmpty ? '0' : tvmLines[r].text, ctx).asReal;
      switch (r) {
        case 0:
          tvm.n = v;
        case 1:
          tvm.i = v;
        case 2:
          tvm.pv = v;
        case 3:
          tvm.pmt = v;
        case 4:
          tvm.fv = v;
        case 5:
          tvm.py = v;
        case 6:
          tvm.cy = v;
      }
    } on CalcException catch (e) {
      _showError(e.code);
    }
  }

  void _runTvm() {
    for (var i = 0; i < 7; i++) {
      _commitTvmRow(i);
    }
    const fields = ['N', 'I%', 'PV', 'PMT', 'FV'];
    if (tvmRow >= fields.length) return;
    try {
      final v = tvm.solve(fields[tvmRow]);
      tvmLines[tvmRow].setText(_numText(v));
    } catch (_) {
      _showError('NO SOLUTION');
    }
  }

  // =========================================================================
  // Mode / Format
  // =========================================================================

  // =========================================================================
  // Stat plots
  // =========================================================================

  void _statPlotsEnter() {
    if (plotRow == 3) {
      for (final p in plots) {
        p.on = false;
      }
      return;
    }
    editingPlot = plotRow;
    plotEditRow = 0;
    push(ScreenId.statPlotEdit);
  }

  void _statPlotHArrow(int dx) {
    final p = plots[editingPlot];
    switch (plotEditRow) {
      case 0:
        p.on = !p.on;
      case 1:
        final n = StatPlotType.values.length;
        p.type = StatPlotType
            .values[(p.type.index + dx + n) % n];
      case 2:
        p.xList = _cycleList(p.xList, dx);
      case 3:
        p.yList = _cycleList(p.yList, dx);
      case 4:
        p.mark = (p.mark + dx + 3) % 3;
    }
  }

  String _cycleList(String cur, int dx) {
    final names = ['L1', 'L2', 'L3', 'L4', 'L5', 'L6'];
    final i = names.indexOf(cur);
    return names[(i + dx + names.length) % names.length];
  }

  void _statPlotEditEnter() {
    _statPlotHArrow(1);
  }

  // =========================================================================
  // Memory management
  // =========================================================================

  List<(String, String)> _memItems() {
    final items = <(String, String)>[
      for (final e in ctx.vars.entries)
        ('REAL', '${e.key} = ${_numText(e.value)}'),
      for (final e in ctx.lists.entries)
        if (e.value.isNotEmpty)
          ('LIST', '${e.key}(${e.value.length})'),
      for (final e in ctx.matrices.entries)
        ('MATRIX', '${e.key} ${e.value.rows}x${e.value.cols}'),
      for (final p in programs) ('PRGM', p.name),
      for (final e in ctx.strings.entries) ('STRING', e.key),
    ];
    return items;
  }

  void _memDelete() {
    final items = _memItems();
    if (items.isEmpty) return;
    final item = items[memRow.clamp(0, items.length - 1)];
    final name = item.$2.split(' ').first.split('=').first.split('(').first;
    switch (item.$1) {
      case 'REAL':
        ctx.vars.remove(name);
      case 'LIST':
        ctx.lists[name]?.clear();
      case 'MATRIX':
        ctx.matrices.remove(name);
      case 'PRGM':
        programs.removeWhere((p) => p.name == name);
      case 'STRING':
        ctx.strings.remove(name);
    }
    memRow = memRow.clamp(0, _memItems().length - 1);
  }

  void openMemManage() {
    memRow = 0;
    menu = null;
    push(ScreenId.memManage);
  }

  void openAbout() {
    menu = null;
    push(ScreenId.about);
  }

  void openClock() {
    menu = null;
    push(ScreenId.clock);
  }

  void clearEntries() => history.clear();

  void resetAll() {
    ctx.reset();
    history.clear();
    drawn.clear();
    programs.clear();
    for (final p in plots) {
      p.on = false;
    }
    eqLines.clear();
    _fieldCache.clear();
    graph.reset();
  }

  void linkFail() {
    _showError('LINK');
  }

  // =========================================================================
  // Graph input
  // =========================================================================

  void zoomAction(String what) {
    menu = null;
    screen = ScreenId.graph;
    switch (what) {
      case 'box':
        graph.boxing = true;
        graph.boxX1 = null;
        graph.cursorVisible = true;
        graph.cursorX = (window.xMin + window.xMax) / 2;
        graph.cursorY = (window.yMin + window.yMax) / 2;
      case 'in':
        graph.zoomIn();
      case 'out':
        graph.zoomOut();
      case 'decimal':
        graph.zoomDecimal();
      case 'square':
        graph.zoomSquare();
      case 'standard':
        graph.zoomStandard();
      case 'trig':
        graph.zoomTrig();
      case 'integer':
        graph.zoomInteger();
      case 'stat':
        graph.zoomStat(_allStatPoints());
      case 'fit':
        graph.zoomFit();
      case 'previous':
        graph.zoomPrevious();
      case 'store':
        graph.zoomStore();
      case 'recall':
        graph.zoomRecall();
    }
    notify();
  }

  List<(double, double)> _allStatPoints() {
    final pts = <(double, double)>[];
    for (final p in plots) {
      if (!p.on) continue;
      final xs = ctx.list(p.xList);
      final ys = ctx.list(p.yList);
      for (var i = 0; i < xs.length && i < ys.length; i++) {
        pts.add((xs[i], ys[i]));
      }
    }
    return pts;
  }

  void calcAction(String op) {
    menu = null;
    screen = ScreenId.graph;
    graph.clearCalc();
    graph.calcOp = op;
    graph.calcStep = 0;
    if (!graph.tracing) graph.startTrace();
    switch (op) {
      case 'value' || 'dydx':
        graphPrompt = 'X=';
        promptLine.clear();
        promptApply = (v) {
          graph.calcGuess = v;
          final m = graph.finishCalc();
          if (m != null) {
            graph.markers.add(m);
            graph.traceParam = m.x;
            graph.cursorX = m.x;
            graph.cursorY = m.y;
          }
          graph.clearCalc();
        };
      case 'zero' || 'min' || 'max' || 'int':
        // bounds gathered on graph via cursor + enter
        break;
      case 'intersect':
        graph.calcStep = 0;
    }
    notify();
  }

  void _graphArrow(int dx, int dy) {
    final g = graph;
    if (graphPrompt != null) {
      if (dx < 0) {
        promptLine.left();
      } else {
        promptLine.right();
      }
      return;
    }
    if (g.boxing || g.cursorVisible && !g.tracing) {
      g.moveCursor(dx.toDouble(), dy.toDouble(), 95, 63);
      return;
    }
    if (g.tracing) {
      if (dx < 0) {
        g.traceLeft();
      } else if (dx > 0) {
        g.traceRight();
      } else if (dy < 0) {
        g.traceUp();
      } else {
        g.traceDown();
      }
      return;
    }
    g.cursorVisible = true;
    g.moveCursor(dx.toDouble(), dy.toDouble(), 95, 63);
  }

  void _graphEnter() {
    final g = graph;
    if (graphPrompt != null) {
      _applyPrompt();
      return;
    }
    if (g.boxing) {
      if (g.boxX1 == null) {
        g.boxX1 = g.cursorX;
        g.boxY1 = g.cursorY;
      } else {
        g.applyBox();
      }
      return;
    }
    if (g.calcOp != null) {
      _calcEnter();
      return;
    }
  }

  void _calcEnter() {
    final g = graph;
    switch (g.calcOp) {
      case 'zero' || 'min' || 'max' || 'int':
        if (g.calcStep < 2) {
          g.calcBounds.add(g.tracing ? g.traceParam : g.cursorX);
          g.calcStep++;
        } else {
          g.calcGuess = g.tracing ? g.traceParam : g.cursorX;
          final m = g.finishCalc();
          if (m != null) {
            g.markers.add(m);
            g.traceParam = m.x;
            g.cursorX = m.x;
            g.cursorY = m.y;
          }
          g.clearCalc();
        }
      case 'intersect':
        if (g.calcStep < 2) {
          g.calcStep++;
        } else {
          g.calcGuess = g.tracing ? g.traceParam : g.cursorX;
          final m = g.finishCalc();
          if (m != null) {
            g.markers.add(m);
            g.traceParam = m.x;
            g.cursorX = m.x;
            g.cursorY = m.y;
          }
          g.clearCalc();
        }
    }
  }

  void _graphTyping(String text) {
    final g = graph;
    // Typing during trace/calc opens the value prompt.
    if (g.tracing || g.calcOp != null) {
      if (graphPrompt == null) {
        graphPrompt = g.calcPrompt.isEmpty ? 'X=' : g.calcPrompt;
        promptLine.clear();
        promptApply = (v) {
          if (g.calcOp != null) {
            _calcTypedValue(v);
          } else {
            g.traceTo(v);
          }
        };
      }
      promptLine.paste(text);
    }
  }

  void _calcTypedValue(double v) {
    final g = graph;
    switch (g.calcOp) {
      case 'zero' || 'min' || 'max' || 'int':
        if (g.calcStep < 2) {
          g.calcBounds.add(v);
          g.calcStep++;
          graphPrompt = g.calcPrompt;
          promptLine.clear();
        } else {
          g.calcGuess = v;
          final m = g.finishCalc();
          if (m != null) g.markers.add(m);
          g.clearCalc();
        }
      case 'intersect':
        if (g.calcStep < 2) {
          g.calcStep++;
          graphPrompt = g.calcPrompt;
          promptLine.clear();
        } else {
          g.calcGuess = v;
          final m = g.finishCalc();
          if (m != null) g.markers.add(m);
          g.clearCalc();
        }
      default:
        g.calcGuess = v;
        final m = g.finishCalc();
        if (m != null) g.markers.add(m);
        g.clearCalc();
    }
  }

  void _applyPrompt() {
    try {
      final v =
          evalSource(promptLine.text.isEmpty ? '0' : promptLine.text, ctx)
              .asReal;
      final apply = promptApply;
      graphPrompt = null;
      promptApply = null;
      apply?.call(v);
    } on CalcException catch (e) {
      graphPrompt = null;
      promptApply = null;
      _showError(e.code);
    }
  }

  // =========================================================================

  // =========================================================================
  // View API used by the LCD painters
  // =========================================================================

  List<EqRow> eqRows() => _eqLines();
  bool get eqGutterActive => eqGutter;
  List<Field> winFields() => _winFields();
  List<Field> tblFields() => _tblFields();
  List<Field> solverFields() => _solverFields();
  List<String> listColumnNames() => _listNames();
  List<double> listColumn(int i) => ctx.list(_listNames()[i]);
  List<(String, String)> memItems() => _memItems();
  int get activeEqRow => _safeEqRow();
  Field fieldAt(List<Field> f, int row) => f[row.clamp(0, f.length - 1)];

  /// Table data for the current scroll position.
  List<List<String>> visibleTableRows(int count) => tableRows(count);

  /// Whether the focused table cell can be typed into.
  bool get tableEditingX => indpntAsk && tblAskColX;

  /// Mode rows: each entry is (options, selectedIndex).
  List<(List<String>, int)> modeRows() => [
        (['NORMAL', 'SCI', 'ENG'], modes.notation.index),
        (['FLOAT', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9'],
            modes.decimals + 1),
        (['RADIAN', 'DEGREE'], modes.angle.index),
        (['FUNC', 'PAR', 'POL', 'SEQ'], modes.graph.index),
        (['CONNECTED', 'DOT'], modes.connected.index),
        (['SEQUENTIAL', 'SIMUL'], modes.sequential.index),
        (['REAL', 'a+bi'], modes.complex.index),
        (['FULL', 'HORIZ', 'G-T'], modes.split.index),
      ];

  List<(List<String>, int)> formatRows() => [
        (['RectGC', 'PolarGC'], format.coord.index),
        (['CoordOff', 'CoordOn'], format.coordOn ? 1 : 0),
        (['GridOff', 'GridDot', 'GridLine'], format.grid.index),
        (['AxesOff', 'AxesOn'], format.axesOn ? 1 : 0),
        (['LabelOff', 'LabelOn'], format.labelOn ? 1 : 0),
        (['ExprOff', 'ExprOn'], format.exprOn ? 1 : 0),
      ];

  /// Enter on a mode row selects the column under the cursor.
  void modeSelect(int row, int col) {
    switch (row) {
      case 0:
        modes.notation = Notation.values[col.clamp(0, 2)];
      case 1:
        modes.decimals = col - 1;
      case 2:
        modes.angle = AngleMode.values[col.clamp(0, 1)];
        ctx.angleMode = modes.angle;
      case 3:
        modes.graph = GraphMode.values[col.clamp(0, 3)];
      case 4:
        modes.connected = ConnectedMode.values[col.clamp(0, 1)];
      case 5:
        modes.sequential = SequentialMode.values[col.clamp(0, 1)];
      case 6:
        modes.complex = ComplexMode.values[col.clamp(0, 1)];
        ctx.complexMode = modes.complex;
      case 7:
        modes.split = SplitMode.values[col.clamp(0, 2)];
    }
    notify();
  }

  int modeCol = 0;

  void formatSelect(int row, int col) {
    switch (row) {
      case 0:
        format.coord = CoordMode.values[col.clamp(0, 1)];
      case 1:
        format.coordOn = col == 1;
      case 2:
        format.grid = GridStyle.values[col.clamp(0, 2)];
      case 3:
        format.axesOn = col == 1;
      case 4:
        format.labelOn = col == 1;
      case 5:
        format.exprOn = col == 1;
    }
    notify();
  }

  int fmtCol = 0;

  /// Current cell text shown on a list editor row.
  String listCellText(int col, int row) {
    final l = ctx.list(_listNames()[col]);
    if (row < l.length) return _numText(l[row]);
    return '';
  }

  /// The home entry's render data plus modifier indicator.
  String get modifierIndicator => switch (mod) {
        Modifier.second => '2ND',
        Modifier.alpha => 'A',
        Modifier.alphaLock => 'ALOCK',
        Modifier.none => '',
      };

  /// Status flags shown in the LCD header, matching the OS.
  String get statusLine {
    final notation = switch (modes.notation) {
      Notation.normal => 'NORMAL',
      Notation.sci => 'SCI',
      Notation.eng => 'ENG',
    };
    final dec = modes.decimals < 0 ? 'FLOAT' : '${modes.decimals}';
    final cmp = modes.complex == ComplexMode.real ? 'REAL' : 'a+bi';
    final ang = modes.angle == AngleMode.radian ? 'RADIAN' : 'DEGREE';
    final gm = switch (modes.graph) {
      GraphMode.func => 'FUNC',
      GraphMode.parametric => 'PAR',
      GraphMode.polar => 'POL',
      GraphMode.sequence => 'SEQ',
    };
    return '$notation $dec AUTO $cmp $ang $gm';
  }
}

class _Insert {
  const _Insert(this.text);
  final String text;
}

class _Cmd {
  const _Cmd(this.cmd);
  final _C cmd;
}

enum _C {
  yEquals, window, zoom, trace, graph, table, tblset, statPlot, format,
  calc, mode, quit, ins, aLock, link, list, test, angle, draw, distr,
  matrix, catalog, mem, rcl, off, entry, solve, insertXttn, stat, math,
  apps, prgm, vars, clear, del, up, down, left, right, on, enter,
}

class EqRow {
  EqRow(this.name, this.line);
  final String name;
  final EntryLine line;
}
