/// Editable token list with a cursor, mirroring the handheld's
/// entry line. Multi-character functions like `sin(` occupy a
/// single token so the cursor steps over them in one move.
class EntryLine {
  EntryLine([String initial = '']) {
    if (initial.isNotEmpty) setText(initial);
  }

  final List<String> tokens = [];

  /// Index between tokens, 0..tokens.length.
  int cursor = 0;

  /// When false the next typed token replaces the token at the
  /// cursor (2nd INS toggles this).
  bool insertMode = true;

  String get text => tokens.join();

  bool get isEmpty => tokens.isEmpty;

  void setText(String s) {
    tokens
      ..clear()
      ..addAll(splitTokens(s));
    cursor = tokens.length;
    insertMode = true;
  }

  /// Split source text into display tokens, keeping multi-char
  /// function names and names like L1 or [A] together.
  static List<String> splitTokens(String s) {
    const multi = [
      'sin⁻¹(', 'cos⁻¹(', 'tan⁻¹(', 'sinh⁻¹(', 'cosh⁻¹(', 'tanh⁻¹(',
      'summation Σ(', 'logBASE(', 'remainder(', 'piecewise(',
      'normalpdf(', 'normalcdf(', 'invNorm(', 'randIntNoRep(',
      'binompdf(', 'binomcdf(', 'poissonpdf(', 'poissoncdf(',
      'geometpdf(', 'geometcdf(', 'χ²pdf(', 'χ²cdf(',
      'Fpdf(', 'Fcdf(', 'tpdf(', 'tcdf(', 'invT(',
      'nDeriv(', 'fnInt(', 'fMin(', 'fMax(', 'solve(',
      'stdDev(', 'variance(', 'median(', 'mean(', 'augment(',
      'cumSum(', 'ΔList(', 'SortA(', 'SortD(', 'seq(',
      'randInt(', 'randNorm(', 'randBin(', 'randM(', 'rand',
      'identity(', 'rowSwap(', 'row+(', '*row+(', '*row(', 'ref(',
      'rref(', 'det(', 'dim(', 'Fill(',
      'iPart(', 'fPart(', 'round(', 'abs(', 'min(', 'max(',
      'lcm(', 'gcd(', 'not(', 'conj(', 'angle(', 'real(', 'imag(',
      'expr(', 'sub(', 'inString(', 'length(',
      'dayOfWk(', 'dbd(', 'getTime(', 'getDate(',
      'sinh(', 'cosh(', 'tanh(', 'sin(', 'cos(', 'tan(',
      '√(', 'ln(', 'log(', '10^(', 'e^(', '³√(', '⁻¹',
      'Str0', 'Str1', 'Str2', 'Str3', 'Str4', 'Str5', 'Str6', 'Str7',
      'Str8', 'Str9',
      'X1T', 'Y1T', 'X2T', 'Y2T', 'X3T', 'Y3T', 'X4T', 'Y4T', 'X5T',
      'Y5T', 'X6T', 'Y6T',
      'L1', 'L2', 'L3', 'L4', 'L5', 'L6',
      'Y1', 'Y2', 'Y3', 'Y4', 'Y5', 'Y6', 'Y7', 'Y8', 'Y9', 'Y0',
      'r1', 'r2', 'r3', 'r4', 'r5', 'r6',
      '[A]', '[B]', '[C]', '[D]', '[E]', '[F]', '[G]', '[H]', '[I]',
      '[J]',
      'nPr', 'nCr', 'and', 'xor', 'or', 'Ans',
      '▸Frac', '▸Dec', '▸DMS', '▸Rect', '▸Polar', '▸n/d', '▸Un/d',
      'u(', 'v(', 'w(',
    ];
    final out = <String>[];
    var i = 0;
    while (i < s.length) {
      String? best;
      for (final m in multi) {
        if (s.startsWith(m, i) && (best == null || m.length > best.length)) {
          best = m;
        }
      }
      if (best != null) {
        out.add(best);
        i += best.length;
      } else {
        out.add(s[i]);
        i++;
      }
    }
    return out;
  }

  void insert(String token) {
    if (!insertMode && cursor < tokens.length) {
      tokens[cursor] = token;
      cursor++;
      return;
    }
    tokens.insert(cursor, token);
    cursor++;
  }

  /// Insert several tokens as one string (menus paste whole chunks).
  void paste(String s) {
    for (final t in splitTokens(s)) {
      insert(t);
    }
  }

  bool delete() {
    if (cursor < tokens.length) {
      tokens.removeAt(cursor);
      return true;
    }
    return false;
  }

  bool backspace() {
    if (cursor > 0) {
      tokens.removeAt(--cursor);
      return true;
    }
    return false;
  }

  void left() {
    if (cursor > 0) cursor--;
  }

  void right() {
    if (cursor < tokens.length) cursor++;
  }

  void clear() {
    tokens.clear();
    cursor = 0;
  }

  /// Render for the LCD: returns (text, cursorCharIndex) where the
  /// cursor char index marks where the cursor bar/underline sits.
  (String, int) render() {
    final sb = StringBuffer();
    var cursorAt = 0;
    for (var i = 0; i < tokens.length; i++) {
      if (i == cursor) cursorAt = sb.length;
      sb.write(displayOf(tokens[i]));
    }
    if (cursor == tokens.length) cursorAt = sb.length;
    return (sb.toString(), cursorAt);
  }

  static String displayOf(String token) => switch (token) {
        '*' => '×',
        '/' => '÷',
        '⁻' => '⁻',
        'ᴇ' => 'ᴇ',
        _ => token,
      };
}
