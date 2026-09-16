import 'dart:math' as math;

import 'matrix.dart';
import 'value.dart';

/// Radian or degree mode for trig evaluation.
enum AngleMode { radian, degree }

/// Whether complex results are allowed.
enum ComplexMode { real, aBi }

/// A stored equation such as Y1 or X1T.
class StoredEquation {
  StoredEquation(this.expression);

  /// Raw expression text, empty when undefined.
  String expression;
  bool enabled = true;

  bool get isDefined => expression.trim().isNotEmpty;
}

/// A recursive sequence definition (u, v, w in Seq mode).
class StoredSequence {
  String expression = '';
  bool enabled = true;

  /// u(nMin) style initial values, one per leading term.
  final List<double> initial = [1];

  bool get isDefined => expression.trim().isNotEmpty;
}

/// Mutable calculator memory: variables, lists, matrices, equations,
/// string vars and the last answer.
class CalcContext {
  final Map<String, double> vars = {};
  final Map<String, List<double>> lists = {
    for (var i = 1; i <= 6; i++) 'L$i': <double>[],
  };
  final Map<String, Matrix> matrices = {};
  final Map<String, String> strings = {};
  final Map<String, StoredEquation> equations = {};
  final Map<String, StoredSequence> sequences = {
    'u': StoredSequence(),
    'v': StoredSequence(),
    'w': StoredSequence(),
  };

  Value ans = const RealValue(0);
  AngleMode angleMode = AngleMode.radian;
  ComplexMode complexMode = ComplexMode.real;
  int nMin = 1;
  int lastKeyCode = 0;
  final math.Random random = math.Random();

  /// Memoized sequence values keyed by sequence name then index.
  final Map<String, Map<int, double>> seqCache = {
    'u': {},
    'v': {},
    'w': {},
  };

  double getVar(String name) => vars[name] ?? 0;

  void setVar(String name, double v) => vars[name] = v;

  List<double> list(String name) =>
      lists.putIfAbsent(name, () => <double>[]);

  Matrix? matrix(String name) => matrices[name];

  void setMatrix(String name, Matrix m) => matrices[name] = m;

  StoredEquation equation(String name) =>
      equations.putIfAbsent(name, () => StoredEquation(''));

  void reset() {
    vars.clear();
    strings.clear();
    for (final l in lists.values) {
      l.clear();
    }
    matrices.clear();
    equations.clear();
    for (final s in sequences.values) {
      s.expression = '';
      s.enabled = true;
      s.initial
        ..clear()
        ..add(1);
    }
    ans = const RealValue(0);
    nMin = 1;
    clearSequenceCache();
  }

  /// Sequence helper: evaluate u/v/w at integer n with the stored
  /// definition and initial terms. Computed terms are cached.
  double sequenceAt(String name, int n) {
    final seq = sequences[name];
    if (seq == null || !seq.isDefined) {
      throw const CalcException('UNDEFINED');
    }
    final cache = seqCache[name]!;
    for (var i = 0; i < seq.initial.length; i++) {
      cache.putIfAbsent(nMin + i, () => seq.initial[i]);
    }
    if (n < nMin) throw const CalcException('DOMAIN');
    for (var k = nMin; k <= n; k++) {
      if (cache.containsKey(k)) continue;
      final savedN = vars['n'];
      vars['n'] = k.toDouble();
      final savedSeq = <String, double?>{};
      for (final nm in const ['u', 'v', 'w']) {
        savedSeq[nm] = vars['_seq_$nm'];
        final prev = seqCache[nm]?[k - 1];
        if (prev == null) {
          vars.remove('_seq_$nm');
        } else {
          vars['_seq_$nm'] = prev;
        }
      }
      double v;
      try {
        v = evaluateInline(seq.expression, this).asReal;
      } finally {
        for (final e in savedSeq.entries) {
          if (e.value == null) {
            vars.remove('_seq_${e.key}');
          } else {
            vars['_seq_${e.key}'] = e.value!;
          }
        }
        if (savedN == null) {
          vars.remove('n');
        } else {
          vars['n'] = savedN;
        }
      }
      cache[k] = v;
    }
    return cache[n]!;
  }

  void clearSequenceCache() {
    for (final c in seqCache.values) {
      c.clear();
    }
  }
}

/// Late bound to avoid a circular import between context and evaluator.
/// The evaluator registers itself here at first use.
typedef InlineEval = Value Function(String source, CalcContext ctx);

InlineEval? _inlineEval;

void registerInlineEval(InlineEval fn) => _inlineEval = fn;

Value evaluateInline(String source, CalcContext ctx) {
  final fn = _inlineEval;
  if (fn == null) throw StateError('evaluator not registered');
  return fn(source, ctx);
}
