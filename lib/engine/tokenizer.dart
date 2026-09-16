import 'value.dart';

enum TokType {
  number,
  name,
  func,
  op,
  lparen,
  rparen,
  lbrace,
  rbrace,
  lbracket,
  rbracket,
  comma,
  str,
  colon,
  store
}

class Tok {
  const Tok(this.type, this.text);
  final TokType type;
  final String text;

  @override
  String toString() => '${type.name}($text)';
}

/// Names made of more than one character that must match before
/// single letters get consumed.
const multiNames = [
  'X1T', 'Y1T', 'X2T', 'Y2T', 'X3T', 'Y3T', 'X4T', 'Y4T', 'X5T', 'Y5T',
  'X6T', 'Y6T',
  'Str0', 'Str1', 'Str2', 'Str3', 'Str4', 'Str5', 'Str6', 'Str7', 'Str8',
  'Str9',
  'L1', 'L2', 'L3', 'L4', 'L5', 'L6',
  'Y1', 'Y2', 'Y3', 'Y4', 'Y5', 'Y6', 'Y7', 'Y8', 'Y9', 'Y0',
  'r1', 'r2', 'r3', 'r4', 'r5', 'r6',
  '[A]', '[B]', '[C]', '[D]', '[E]', '[F]', '[G]', '[H]', '[I]', '[J]',
  'Ans',
  'X', 'T', 'n', 'u', 'v', 'w', 'θ', 'i', 'π', 'e',
];

/// Function tokens. Every entry already carries its opening paren.
const functionNames = [
  'sin(', 'cos(', 'tan(', 'sin⁻¹(', 'cos⁻¹(', 'tan⁻¹(',
  'sinh(', 'cosh(', 'tanh(', 'sinh⁻¹(', 'cosh⁻¹(', 'tanh⁻¹(',
  '√(', 'ln(', 'log(', 'logBASE(', '10^(', 'e^(',
  'abs(', 'round(', 'iPart(', 'fPart(', 'int(', 'min(', 'max(',
  'lcm(', 'gcd(', 'remainder(',
  'nDeriv(', 'fnInt(', 'fMin(', 'fMax(', 'solve(', 'summation Σ(',
  'piecewise(', 'not(',
  'seq(', 'cumSum(', 'ΔList(', 'SortA(', 'SortD(', 'augment(',
  'mean(', 'median(', 'stdDev(', 'variance(', 'sum(', 'prod(',
  'det(', 'dim(', 'Fill(', 'identity(', 'randM(',
  'ref(', 'rref(', 'rowSwap(', 'row+(', '*row(', '*row+(',
  'normalpdf(', 'normalcdf(', 'invNorm(', 'invT(',
  'tpdf(', 'tcdf(', 'χ²pdf(', 'χ²cdf(', 'Fpdf(', 'Fcdf(',
  'binompdf(', 'binomcdf(', 'poissonpdf(', 'poissoncdf(',
  'geometpdf(', 'geometcdf(',
  'randInt(', 'randNorm(', 'randBin(', 'randIntNoRep(',
  'real(', 'imag(', 'conj(', 'angle(',
  'expr(', 'sub(', 'inString(', 'length(',
  '³√(', 'u(', 'v(', 'w(',
  'getTime(', 'getDate(',
  'dayOfWk(', 'dbd(',
  'rand',
];

/// Infix operators that read like functions: `5 nPr 2`.
const infixOps = {'nPr', 'nCr', 'ˣ√'};

/// Word-like operators matched before single letter names.
const wordOps = {'and', 'or', 'xor', 'nPr', 'nCr'};

const postfixOps = {'!', '°', '′', '″', 'ʳ', '²', '³', '⁻¹', 'ᵀ', '%'};

const hintTokens = {'▸Frac', '▸Dec', '▸DMS', '▸Rect', '▸Polar', '▸n/d', '▸Un/d'};

class Tokenizer {
  Tokenizer(this.src);

  final String src;
  int pos = 0;

  List<Tok> run() {
    final out = <Tok>[];
    while (pos < src.length) {
      final c = src[pos];
      if (c == ' ') {
        pos++;
        continue;
      }
      if (_isDigit(c) || c == '.' ||
          (c == 'ᴇ' && out.isNotEmpty && out.last.type == TokType.number)) {
        out.add(_number());
        continue;
      }
      if (c == '"') {
        out.add(_string());
        continue;
      }
      final fn = _matchFunction();
      if (fn != null) {
        out.add(Tok(TokType.func, fn));
        continue;
      }
      final wop = _matchWordOp();
      if (wop != null) {
        out.add(Tok(TokType.op, wop));
        continue;
      }
      final nm = _matchName();
      if (nm != null) {
        if (infixOps.contains(nm)) {
          out.add(Tok(TokType.op, nm));
        } else if (nm == 'rand') {
          out.add(Tok(TokType.func, nm));
        } else {
          out.add(Tok(TokType.name, nm));
        }
        continue;
      }
      if (src.startsWith('⁻¹', pos)) {
        out.add(const Tok(TokType.op, '⁻¹'));
        pos += 2;
        continue;
      }
      if (postfixOps.contains(c)) {
        out.add(Tok(TokType.op, c));
        pos++;
        continue;
      }
      if (hintTokens.contains(_matchHint())) {
        out.add(Tok(TokType.op, _matchHint()));
        pos += _matchHint().length;
        continue;
      }
      switch (c) {
        case '(':
          out.add(const Tok(TokType.lparen, '('));
        case ')':
          out.add(const Tok(TokType.rparen, ')'));
        case '[':
          out.add(const Tok(TokType.lbracket, '['));
        case ']':
          out.add(const Tok(TokType.rbracket, ']'));
        case '{':
          out.add(const Tok(TokType.lbrace, '{'));
        case '}':
          out.add(const Tok(TokType.rbrace, '}'));
        case ',':
          out.add(const Tok(TokType.comma, ','));
        case ':':
          out.add(const Tok(TokType.colon, ':'));
        case '→':
          out.add(const Tok(TokType.store, '→'));
        case '+' || '-' || '*' || '/' || '^' || '⁻' || '=' || '≠' ||
              '<' || '≤' || '>' || '≥':
          out.add(Tok(TokType.op, c));
        default:
          if (_isWordChar(c)) {
            out.add(Tok(TokType.name, c));
          } else {
            throw CalcException('SYNTAX', 'bad token "$c"');
          }
      }
      pos++;
    }
    return out;
  }

  bool _isDigit(String c) => c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;

  bool _isWordChar(String c) {
    final u = c.codeUnitAt(0);
    return (u >= 65 && u <= 90) || (u >= 97 && u <= 122) || c == 'θ';
  }

  Tok _number() {
    final start = pos;
    var sawDot = false;
    while (pos < src.length) {
      final c = src[pos];
      if (_isDigit(c)) {
        pos++;
      } else if (c == '.' && !sawDot) {
        sawDot = true;
        pos++;
      } else {
        break;
      }
    }
    if (pos < src.length && (src[pos] == 'E' || src[pos] == 'ᴇ')) {
      var p = pos + 1;
      if (p < src.length && (src[p] == '-' || src[p] == '⁻' || src[p] == '+')) {
        p++;
      }
      var digits = false;
      while (p < src.length && _isDigit(src[p])) {
        p++;
        digits = true;
      }
      if (digits) pos = p;
    }
    return Tok(TokType.number, src.substring(start, pos));
  }

  Tok _string() {
    pos++;
    final sb = StringBuffer();
    while (pos < src.length && src[pos] != '"') {
      sb.write(src[pos]);
      pos++;
    }
    pos++;
    return Tok(TokType.str, sb.toString());
  }

  String? _matchFunction() {
    String? best;
    for (final f in functionNames) {
      if (src.startsWith(f, pos) &&
          (best == null || f.length > best.length)) {
        best = f;
      }
    }
    if (best != null) pos += best.length;
    return best;
  }

  String? _matchWordOp() {
    String? best;
    for (final w in wordOps) {
      if (src.startsWith(w, pos) &&
          (best == null || w.length > best.length)) {
        best = w;
      }
    }
    if (src.startsWith('ˣ√', pos)) best = 'ˣ√';
    if (best != null) pos += best.length;
    return best;
  }

  String? _matchName() {
    String? best;
    for (final n in multiNames) {
      if (src.startsWith(n, pos) &&
          (best == null || n.length > best.length)) {
        best = n;
      }
    }
    if (best != null) {
      pos += best.length;
      return best;
    }
    return null;
  }

  String _matchHint() {
    var best = '';
    for (final h in hintTokens) {
      if (src.startsWith(h, pos) && h.length > best.length) best = h;
    }
    return best;
  }
}

List<Tok> tokenize(String src) => Tokenizer(src).run();
