import 'evaluator.dart';
import 'context.dart';
import 'value.dart';

/// Output sink for a running program.
class ProgramIO {
  /// Lines printed by Disp/Output.
  final List<String> lines = [];

  /// When a program pauses for input, the variables it waits for.
  final List<String> promptQueue = [];
  String? promptLabel;

  bool paused = false;
  bool done = false;
}

sealed class _Block {}

class _IfBlock extends _Block {}

class _ForBlock extends _Block {
  _ForBlock(this.varName, this.end, this.step, this.startPc, this.startStmt);
  final String varName;
  final double end;
  final double step;
  final int startPc;
  final int startStmt;
}

class _WhileBlock extends _Block {
  _WhileBlock(this.cond, this.startPc, this.startStmt);
  final String cond;
  final int startPc;
  final int startStmt;
}

class _RepeatBlock extends _Block {
  _RepeatBlock(this.cond, this.startPc, this.startStmt);
  final String cond;
  final int startPc;
  final int startStmt;
}

/// Mini interpreter for the classic BASIC dialect.
class ProgramRunner {
  ProgramRunner(this.source, this.ctx);

  final String source;
  final CalcContext ctx;
  final io = ProgramIO();

  late final List<List<_Stmt>> _lines = _compile();
  final _labels = <String, int>{};
  final _blocks = <_Block>[];
  int _pc = 0;
  int _stmtIdx = 0;

  List<List<_Stmt>> _compile() {
    final lines = <List<_Stmt>>[];
    for (final raw in source.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final stmts = <_Stmt>[
        for (final piece in _split(line)) _compileStmt(piece),
      ];
      for (var i = 0; i < stmts.length; i++) {
        final s = stmts[i];
        if (s is _Lbl) _labels[s.name] = lines.length;
      }
      lines.add(stmts);
    }
    return lines;
  }

  List<String> _split(String line) {
    final out = <String>[];
    final cur = StringBuffer();
    var inStr = false;
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') inStr = !inStr;
      if (c == ':' && !inStr) {
        out.add(cur.toString());
        cur.clear();
      } else {
        cur.write(c);
      }
    }
    out.add(cur.toString());
    return out;
  }

  _Stmt _compileStmt(String s) {
    s = s.trim();
    if (s.startsWith('Disp ')) return _Disp(s.substring(5));
    if (s == 'ClrHome') return const _Clr();
    if (s.startsWith('Prompt ')) return _Prompt(s.substring(7));
    if (s.startsWith('Input')) {
      return _Input(s.length > 5 ? s.substring(6) : null);
    }
    if (s.startsWith('Lbl ')) return _Lbl(s.substring(4).trim());
    if (s.startsWith('Goto ')) return _Goto(s.substring(5).trim());
    if (s.startsWith('If ')) return _If(s.substring(3));
    if (s == 'Then') return const _Then();
    if (s == 'Else') return const _Else();
    if (s == 'End') return const _End();
    if (s.startsWith('For(') && s.endsWith(')')) {
      return _For(s.substring(4, s.length - 1));
    }
    if (s.startsWith('While ')) return _While(s.substring(6));
    if (s.startsWith('Repeat ')) return _Repeat(s.substring(7));
    if (s.startsWith('Pause')) {
      return _Pause(s.length > 5 ? s.substring(6) : null);
    }
    if (s == 'Stop') return const _Stop();
    if (s.startsWith('Output(') && s.endsWith(')')) {
      return _Output(s.substring(7, s.length - 1));
    }
    if (s.startsWith('Menu(') && s.endsWith(')')) {
      return _Menu(s.substring(5, s.length - 1));
    }
    return _Eval(s);
  }

  /// Run until the program pauses for input, finishes, or hits the
  /// step limit.
  void run() {
    var steps = 0;
    while (!io.done && !io.paused && _pc < _lines.length) {
      if (++steps > 500000) {
        throw const CalcException('MEMORY', 'program too long');
      }
      _stepLine();
    }
    if (_pc >= _lines.length) io.done = true;
  }

  /// Continue after an input pause.
  void resume(String input) {
    final varName =
        io.promptQueue.isNotEmpty ? io.promptQueue.removeAt(0) : 'X';
    if (varName.isNotEmpty) {
      ctx.setVar(
          varName, evalSource(input.isEmpty ? '0' : input, ctx).asReal);
    }
    io.paused = false;
    _queuePromptOrRun();
  }

  void _queuePromptOrRun() {
    if (io.promptQueue.isNotEmpty) {
      io.promptLabel = '${io.promptQueue.first}=?';
      io.paused = true;
      return;
    }
    run();
  }

  void _stepLine() {
    final stmts = _lines[_pc];
    while (_stmtIdx < stmts.length) {
      final s = stmts[_stmtIdx];
      _stmtIdx++;
      if (_exec(s)) return;
    }
    _pc++;
    _stmtIdx = 0;
  }

  /// Execute one statement. Returns true when execution should stop
  /// (pause, jump, or done handles _pc itself).
  bool _exec(_Stmt s) {
    switch (s) {
      case _Eval():
        ctx.ans = evalSource(s.text, ctx);
      case _Disp():
        for (final part in _splitArgs(s.text)) {
          io.lines.add(_display(evalSource(part, ctx)));
        }
      case _Clr():
        io.lines.clear();
      case _Prompt():
        io.promptQueue.addAll(s.vars);
        io.promptLabel = '${io.promptQueue.first}=?';
        io.paused = true;
        return true;
      case _Input():
        final rest = s.text;
        if (rest == null || rest.isEmpty) {
          io.promptQueue.add('X');
          io.promptLabel = '?';
        } else if (rest.contains(',')) {
          final i = rest.indexOf(',');
          io.promptLabel = _display(evalSource(rest.substring(0, i), ctx));
          io.promptQueue.add(rest.substring(i + 1).trim());
        } else {
          io.promptQueue.add(rest);
          io.promptLabel = '?';
        }
        io.paused = true;
        return true;
      case _Lbl():
        break;
      case _Goto():
        final line = _labels[s.name];
        if (line == null) throw const CalcException('LABEL');
        _pc = line;
        _stmtIdx = 0;
        return true;
      case _If():
        final cond = evalSource(s.cond, ctx).asReal != 0;
        final stmts = _lines[_pc];
        final thenInline =
            _stmtIdx < stmts.length && stmts[_stmtIdx] is _Then;
        // `Then` on the following line is the usual layout.
        final thenNextLine = !thenInline &&
            _pc + 1 < _lines.length &&
            _lines[_pc + 1].isNotEmpty &&
            _lines[_pc + 1].first is _Then;
        if (thenInline || thenNextLine) {
          if (thenInline) {
            _stmtIdx++;
          } else {
            _pc++;
            _stmtIdx = 1;
          }
          if (cond) {
            _blocks.add(_IfBlock());
            if (thenNextLine) return true;
          } else {
            _skipToElseOrEnd();
            return true;
          }
        } else if (!cond) {
          _stmtIdx = stmts.length;
        }
      case _Then():
        break;
      case _Else():
        // Reached only when the If branch ran: skip the else branch.
        _skipToEnd();
        if (_blocks.isNotEmpty && _blocks.last is _IfBlock) {
          _blocks.removeLast();
        }
        return true;
      case _End():
        final top = _blocks.isNotEmpty ? _blocks.last : null;
        switch (top) {
          case _ForBlock():
            ctx.setVar(top.varName, ctx.getVar(top.varName) + top.step);
            final cur = ctx.getVar(top.varName);
            final cont = top.step > 0 ? cur <= top.end : cur >= top.end;
            if (cont) {
              _pc = top.startPc;
              _stmtIdx = top.startStmt;
              return true;
            }
            _blocks.removeLast();
          case _WhileBlock():
            if (evalSource(top.cond, ctx).asReal != 0) {
              _pc = top.startPc;
              _stmtIdx = top.startStmt;
              return true;
            }
            _blocks.removeLast();
          case _RepeatBlock():
            if (evalSource(top.cond, ctx).asReal == 0) {
              _pc = top.startPc;
              _stmtIdx = top.startStmt;
              return true;
            }
            _blocks.removeLast();
          case _IfBlock():
            _blocks.removeLast();
          case null:
            break;
        }
      case _For():
        final parts = _splitArgs(s.args);
        if (parts.length < 3) throw const CalcException('SYNTAX');
        final varName = parts[0].trim();
        final lo = evalSource(parts[1], ctx).asReal;
        final hi = evalSource(parts[2], ctx).asReal;
        final step =
            parts.length > 3 ? evalSource(parts[3], ctx).asReal : 1.0;
        ctx.setVar(varName, lo);
        if (step > 0 ? lo > hi : lo < hi) {
          _skipToEnd();
          return true;
        }
        _blocks.add(_ForBlock(varName, hi, step, _pc, _stmtIdx));
      case _While():
        if (evalSource(s.cond, ctx).asReal == 0) {
          _skipToEnd();
          return true;
        }
        _blocks.add(_WhileBlock(s.cond, _pc, _stmtIdx));
      case _Repeat():
        _blocks.add(_RepeatBlock(s.cond, _pc, _stmtIdx));
      case _Pause():
        if (s.text != null) {
          io.lines.add(_display(evalSource(s.text!, ctx)));
        }
        io.paused = true;
        io.promptLabel = '';
        return true;
      case _Stop():
        io.done = true;
        return true;
      case _Output():
        final parts = _splitArgs(s.args);
        if (parts.length == 3) {
          io.lines.add(_display(evalSource(parts[2], ctx)));
        }
      case _Menu():
        io.lines.add(s.args);
        io.paused = true;
        io.promptQueue.add('');
        io.promptLabel = '';
        return true;
    }
    return false;
  }

  /// For/While/Repeat when the body must be skipped: land just past
  /// the matching End.
  void _skipToEnd() {
    var depth = 1;
    while (_pc < _lines.length) {
      final stmts = _lines[_pc];
      while (_stmtIdx < stmts.length) {
        final s = stmts[_stmtIdx++];
        if (_opensBlock(s, stmts)) depth++;
        if (s is _End) {
          depth--;
          if (depth == 0) {
            return; // _stmtIdx sits just past End
          }
        }
      }
      _pc++;
      _stmtIdx = 0;
    }
  }

  /// If-condition false: land just past the matching Else or End.
  void _skipToElseOrEnd() {
    var depth = 1;
    while (_pc < _lines.length) {
      final stmts = _lines[_pc];
      while (_stmtIdx < stmts.length) {
        final s = stmts[_stmtIdx];
        if (_opensBlock(s, stmts)) depth++;
        if (s is _Else && depth == 1) {
          _stmtIdx++;
          _blocks.add(_IfBlock());
          return;
        }
        _stmtIdx++;
        if (s is _End) {
          depth--;
          if (depth == 0) return;
        }
      }
      _pc++;
      _stmtIdx = 0;
    }
  }

  /// Does statement at index _stmtIdx-1 open a block? If only opens
  /// a block when immediately followed by Then on the same line.
  bool _opensBlock(_Stmt s, List<_Stmt> stmts) {
    if (s is _For || s is _While || s is _Repeat) return true;
    if (s is _If) {
      final i = _stmtIdx - 1;
      return i + 1 < stmts.length && stmts[i + 1] is _Then;
    }
    return false;
  }

  List<String> _splitArgs(String s) {
    final out = <String>[];
    final cur = StringBuffer();
    var depth = 0;
    var inStr = false;
    for (var i = 0; i < s.length; i++) {
      final c = s[i];
      if (c == '"') inStr = !inStr;
      if (!inStr) {
        if (c == '(' || c == '{') depth++;
        if (c == ')' || c == '}') depth--;
        if (c == ',' && depth == 0) {
          out.add(cur.toString().trim());
          cur.clear();
          continue;
        }
      }
      cur.write(c);
    }
    if (cur.isNotEmpty) out.add(cur.toString().trim());
    return out;
  }

  String _display(Value v) => switch (v) {
        RealValue() =>
          v.v == v.v.roundToDouble() && v.v.abs() < 1e15
              ? v.v.round().toString()
              : '${v.v}',
        StringValue() => v.v,
        ComplexValue() => v.v.toString(),
        ListValue() => '{${v.items.map(_display).join(' ')}}',
        MatrixValue() => v.m.toString(),
      };
}

// ---- compiled statements -----------------------------------------------------

sealed class _Stmt {
  const _Stmt();
}

class _Eval extends _Stmt {
  const _Eval(this.text);
  final String text;
}

class _Disp extends _Stmt {
  const _Disp(this.text);
  final String text;
}

class _Clr extends _Stmt {
  const _Clr();
}

class _Prompt extends _Stmt {
  _Prompt(String vars)
      : vars = [for (final v in vars.split(',')) v.trim()];
  final List<String> vars;
}

class _Input extends _Stmt {
  const _Input(this.text);
  final String? text;
}

class _Lbl extends _Stmt {
  const _Lbl(this.name);
  final String name;
}

class _Goto extends _Stmt {
  const _Goto(this.name);
  final String name;
}

class _If extends _Stmt {
  const _If(this.cond);
  final String cond;
}

class _Then extends _Stmt {
  const _Then();
}

class _Else extends _Stmt {
  const _Else();
}

class _End extends _Stmt {
  const _End();
}

class _For extends _Stmt {
  const _For(this.args);
  final String args;
}

class _While extends _Stmt {
  const _While(this.cond);
  final String cond;
}

class _Repeat extends _Stmt {
  const _Repeat(this.cond);
  final String cond;
}

class _Pause extends _Stmt {
  const _Pause(this.text);
  final String? text;
}

class _Stop extends _Stmt {
  const _Stop();
}

class _Output extends _Stmt {
  const _Output(this.args);
  final String args;
}

class _Menu extends _Stmt {
  const _Menu(this.args);
  final String args;
}
