/// Every physical key on the handheld, in reading order.
enum KeyId {
  yEqu, window, zoom, trace, graph,
  second, mode, del,
  up, down, left, right,
  alpha, xttn, stat,
  math, apps, prgm, vars, clear,
  xInv, sin, cos, tan, pow,
  xSq, comma, lParen, rParen, div,
  log, n7, n8, n9, mul,
  ln, n4, n5, n6, sub,
  sto, n1, n2, n3, add,
  on, n0, dot, neg, enter,
}

/// What a key produces under each modifier.
class KeyDef {
  const KeyDef(
    this.id,
    this.label, {
    this.secondLabel,
    this.alphaLabel,
    this.insert,
    this.secondInsert,
    this.alphaInsert,
    this.style = KeyStyle.dark,
  });

  final KeyId id;

  /// Printed on the key itself.
  final String label;

  /// Printed above-left (blue) and above-right (green) of the key.
  final String? secondLabel;
  final String? alphaLabel;

  /// Text inserted into the active entry field.
  final String? insert;
  final String? secondInsert;
  final String? alphaInsert;

  final KeyStyle style;
}

enum KeyStyle { dark, light, blue, green }

const keypadDefs = <KeyDef>[
  KeyDef(KeyId.yEqu, 'y=', secondLabel: 'stat plot', style: KeyStyle.light),
  KeyDef(KeyId.window, 'window', secondLabel: 'tblset', style: KeyStyle.light),
  KeyDef(KeyId.zoom, 'zoom', secondLabel: 'format', style: KeyStyle.light),
  KeyDef(KeyId.trace, 'trace', secondLabel: 'calc', style: KeyStyle.light),
  KeyDef(KeyId.graph, 'graph', secondLabel: 'table', style: KeyStyle.light),
  KeyDef(KeyId.second, '2nd', style: KeyStyle.blue),
  KeyDef(KeyId.mode, 'mode', secondLabel: 'quit'),
  KeyDef(KeyId.del, 'del', secondLabel: 'ins'),
  KeyDef(KeyId.alpha, 'alpha', secondLabel: 'a-lock', style: KeyStyle.green),
  KeyDef(KeyId.xttn, 'x,t,θ,n', secondLabel: 'link'),
  KeyDef(KeyId.stat, 'stat', secondLabel: 'list'),
  KeyDef(KeyId.math, 'math', secondLabel: 'test', alphaLabel: 'A'),
  KeyDef(KeyId.apps, 'apps', secondLabel: 'angle', alphaLabel: 'B'),
  KeyDef(KeyId.prgm, 'prgm', secondLabel: 'draw', alphaLabel: 'C'),
  KeyDef(KeyId.vars, 'vars', secondLabel: 'distr'),
  KeyDef(KeyId.clear, 'clear'),
  KeyDef(KeyId.xInv, 'x⁻¹', secondLabel: 'matrix', alphaLabel: 'D',
      insert: '⁻¹'),
  KeyDef(KeyId.sin, 'sin', secondLabel: 'sin⁻¹', alphaLabel: 'E',
      insert: 'sin(', secondInsert: 'sin⁻¹('),
  KeyDef(KeyId.cos, 'cos', secondLabel: 'cos⁻¹', alphaLabel: 'F',
      insert: 'cos(', secondInsert: 'cos⁻¹('),
  KeyDef(KeyId.tan, 'tan', secondLabel: 'tan⁻¹', alphaLabel: 'G',
      insert: 'tan(', secondInsert: 'tan⁻¹('),
  KeyDef(KeyId.pow, '^', secondLabel: 'π', alphaLabel: 'H', insert: '^',
      secondInsert: 'π'),
  KeyDef(KeyId.xSq, 'x²', secondLabel: '√', alphaLabel: 'I', insert: '²',
      secondInsert: '√('),
  KeyDef(KeyId.comma, ',', secondLabel: 'EE', alphaLabel: 'J', insert: ',',
      secondInsert: 'ᴇ'),
  KeyDef(KeyId.lParen, '(', secondLabel: '{', alphaLabel: 'K', insert: '(',
      secondInsert: '{'),
  KeyDef(KeyId.rParen, ')', secondLabel: '}', alphaLabel: 'L', insert: ')',
      secondInsert: '}'),
  KeyDef(KeyId.div, '÷', secondLabel: 'e', alphaLabel: 'M', insert: '/',
      secondInsert: 'e'),
  KeyDef(KeyId.log, 'log', secondLabel: '10ˣ', alphaLabel: 'N',
      insert: 'log(', secondInsert: '10^('),
  KeyDef(KeyId.n7, '7', secondLabel: 'u', alphaLabel: 'O', insert: '7',
      secondInsert: 'u'),
  KeyDef(KeyId.n8, '8', secondLabel: 'v', alphaLabel: 'P', insert: '8',
      secondInsert: 'v'),
  KeyDef(KeyId.n9, '9', secondLabel: 'w', alphaLabel: 'Q', insert: '9',
      secondInsert: 'w'),
  KeyDef(KeyId.mul, '×', secondLabel: '[', alphaLabel: 'R', insert: '*',
      secondInsert: '['),
  KeyDef(KeyId.ln, 'ln', secondLabel: 'eˣ', alphaLabel: 'S', insert: 'ln(',
      secondInsert: 'e^('),
  KeyDef(KeyId.n4, '4', secondLabel: 'L4', alphaLabel: 'T', insert: '4',
      secondInsert: 'L4'),
  KeyDef(KeyId.n5, '5', secondLabel: 'L5', alphaLabel: 'U', insert: '5',
      secondInsert: 'L5'),
  KeyDef(KeyId.n6, '6', secondLabel: 'L6', alphaLabel: 'V', insert: '6',
      secondInsert: 'L6'),
  KeyDef(KeyId.sub, '−', secondLabel: ']', alphaLabel: 'W', insert: '-',
      secondInsert: ']'),
  KeyDef(KeyId.sto, 'sto→', secondLabel: 'rcl', alphaLabel: 'X',
      insert: '→'),
  KeyDef(KeyId.n1, '1', secondLabel: 'L1', alphaLabel: 'Y', insert: '1',
      secondInsert: 'L1'),
  KeyDef(KeyId.n2, '2', secondLabel: 'L2', alphaLabel: 'Z', insert: '2',
      secondInsert: 'L2'),
  KeyDef(KeyId.n3, '3', secondLabel: 'L3', alphaLabel: 'θ', insert: '3',
      secondInsert: 'L3'),
  KeyDef(KeyId.add, '+', secondLabel: 'mem', alphaLabel: '"', insert: '+',
      secondInsert: '"'),
  KeyDef(KeyId.on, 'on', secondLabel: 'off'),
  KeyDef(KeyId.n0, '0', secondLabel: 'catalog', alphaLabel: ' ', insert: '0',
      secondInsert: ' '),
  KeyDef(KeyId.dot, '.', secondLabel: 'i', alphaLabel: ':', insert: '.',
      secondInsert: 'i'),
  KeyDef(KeyId.neg, '(-)', secondLabel: 'ans', alphaLabel: '?',
      insert: '⁻', secondInsert: 'Ans'),
  KeyDef(KeyId.enter, 'enter', secondLabel: 'entry', alphaLabel: 'solve',
      style: KeyStyle.light),
];

/// Keys laid out in rows for the keypad widget. The arrows sit in a
/// cluster on the right and are handled separately by the layout.
const keypadRows = <List<KeyId>>[
  [KeyId.yEqu, KeyId.window, KeyId.zoom, KeyId.trace, KeyId.graph],
  [KeyId.second, KeyId.mode, KeyId.del],
  [KeyId.alpha, KeyId.xttn, KeyId.stat],
  [KeyId.math, KeyId.apps, KeyId.prgm, KeyId.vars, KeyId.clear],
  [KeyId.xInv, KeyId.sin, KeyId.cos, KeyId.tan, KeyId.pow],
  [KeyId.xSq, KeyId.comma, KeyId.lParen, KeyId.rParen, KeyId.div],
  [KeyId.log, KeyId.n7, KeyId.n8, KeyId.n9, KeyId.mul],
  [KeyId.ln, KeyId.n4, KeyId.n5, KeyId.n6, KeyId.sub],
  [KeyId.sto, KeyId.n1, KeyId.n2, KeyId.n3, KeyId.add],
  [KeyId.on, KeyId.n0, KeyId.dot, KeyId.neg, KeyId.enter],
];

KeyDef keyDefOf(KeyId id) => keypadDefs.firstWhere((k) => k.id == id);
