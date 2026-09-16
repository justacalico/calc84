import 'entry.dart';

/// Every screen the LCD can show.
enum ScreenId {
  home,
  yEquals,
  windowEdit,
  tblset,
  graph,
  table,
  mode,
  format,
  statPlots,
  statPlotEdit,
  listEdit,
  matrixNames,
  matrixEdit,
  programList,
  programEdit,
  programName,
  solver,
  tvm,
  memManage,
  about,
  clock,
  menu,
  error,
  off,
}

/// A full screen menu with optional tabs (MATH/NUM/CPX...).
class MenuModel {
  MenuModel({
    required this.title,
    required this.tabs,
    required this.items,
    this.onSelect,
  })  : assert(tabs.length == items.length),
        tabIndex = 0,
        cursor = List.filled(tabs.length, 0);

  final String title;
  final List<String> tabs;
  final List<List<MenuItem>> items;

  /// Optional hook fired on selection; returns false to keep menu open.
  final bool Function(MenuItem item)? onSelect;

  int tabIndex;
  final List<int> cursor;

  List<MenuItem> get tabItems => items[tabIndex];

  int get selected => cursor[tabIndex];
}

/// One menu row.
class MenuItem {
  const MenuItem(this.label, {this.insert, this.action, this.sub});

  final String label;

  /// Text pasted into the active entry line.
  final String? insert;

  /// Command executed instead of pasting.
  final void Function()? action;

  /// Nested menu.
  final MenuModel Function()? sub;
}

/// One home-screen history entry.
class HistoryEntry {
  HistoryEntry(this.input, this.outputLines, {this.matrixGrid});

  final String input;
  final List<String> outputLines;
  final List<List<String>>? matrixGrid;
}

/// Editable field bound to a numeric or text property.
class Field {
  Field(this.label, this.line, {this.onCommit});

  final String label;
  final EntryLine line;
  final void Function(String text)? onCommit;
}
