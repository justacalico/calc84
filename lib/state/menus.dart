import '../model/screens.dart';
import 'calc_state.dart';

/// Factory for all the menus reachable from the keypad.
/// Items either paste text into the active entry or run an action.
class MenuFactory {
  MenuFactory(this.s);

  final CalcState s;

  MenuModel math() => MenuModel(
        title: 'MATH',
        tabs: ['MATH', 'NUM', 'CPX', 'PRB', 'FRAC'],
        items: [
          [
            MenuItem('▸Frac', insert: '▸Frac'),
            MenuItem('▸Dec', insert: '▸Dec'),
            MenuItem('³', insert: '³'),
            MenuItem('³√(', insert: '³√('),
            MenuItem('ˣ√', insert: 'ˣ√'),
            MenuItem('fMin(', insert: 'fMin('),
            MenuItem('fMax(', insert: 'fMax('),
            MenuItem('nDeriv(', insert: 'nDeriv('),
            MenuItem('fnInt(', insert: 'fnInt('),
            MenuItem('summation Σ(', insert: 'summation Σ('),
            MenuItem('logBASE(', insert: 'logBASE('),
            MenuItem('piecewise(', insert: 'piecewise('),
            MenuItem('Solver...', action: () => s.openSolver()),
          ],
          [
            MenuItem('abs(', insert: 'abs('),
            MenuItem('round(', insert: 'round('),
            MenuItem('iPart(', insert: 'iPart('),
            MenuItem('fPart(', insert: 'fPart('),
            MenuItem('int(', insert: 'int('),
            MenuItem('min(', insert: 'min('),
            MenuItem('max(', insert: 'max('),
            MenuItem('lcm(', insert: 'lcm('),
            MenuItem('gcd(', insert: 'gcd('),
            MenuItem('remainder(', insert: 'remainder('),
          ],
          [
            MenuItem('conj(', insert: 'conj('),
            MenuItem('real(', insert: 'real('),
            MenuItem('imag(', insert: 'imag('),
            MenuItem('angle(', insert: 'angle('),
            MenuItem('abs(', insert: 'abs('),
            MenuItem('▸Rect', insert: '▸Rect'),
            MenuItem('▸Polar', insert: '▸Polar'),
          ],
          [
            MenuItem('rand', insert: 'rand'),
            MenuItem('nPr', insert: ' nPr '),
            MenuItem('nCr', insert: ' nCr '),
            MenuItem('!', insert: '!'),
            MenuItem('randInt(', insert: 'randInt('),
            MenuItem('randNorm(', insert: 'randNorm('),
            MenuItem('randBin(', insert: 'randBin('),
            MenuItem('randIntNoRep(', insert: 'randIntNoRep('),
          ],
          [
            MenuItem('▸n/d', insert: '▸n/d'),
            MenuItem('▸Un/d', insert: '▸Un/d'),
            MenuItem('▸F◂D', insert: '▸Frac'),
          ],
        ],
      );

  MenuModel test() => MenuModel(
        title: 'TEST',
        tabs: ['TEST', 'LOGIC'],
        items: [
          [
            MenuItem('=', insert: '='),
            MenuItem('≠', insert: '≠'),
            MenuItem('>', insert: '>'),
            MenuItem('≥', insert: '≥'),
            MenuItem('<', insert: '<'),
            MenuItem('≤', insert: '≤'),
          ],
          [
            MenuItem('and', insert: ' and '),
            MenuItem('or', insert: ' or '),
            MenuItem('xor', insert: ' xor '),
            MenuItem('not(', insert: 'not('),
          ],
        ],
      );

  MenuModel angle() => MenuModel(
        title: 'ANGLE',
        tabs: ['ANGLE'],
        items: [
          [
            MenuItem('°', insert: '°'),
            MenuItem('′', insert: '′'),
            MenuItem('″', insert: '″'),
            MenuItem('ʳ', insert: 'ʳ'),
            MenuItem('▸DMS', insert: '▸DMS'),
          ],
        ],
      );

  MenuModel distr() => MenuModel(
        title: 'DISTR',
        tabs: ['DISTR', 'DRAW'],
        items: [
          [
            MenuItem('normalpdf(', insert: 'normalpdf('),
            MenuItem('normalcdf(', insert: 'normalcdf('),
            MenuItem('invNorm(', insert: 'invNorm('),
            MenuItem('invT(', insert: 'invT('),
            MenuItem('tpdf(', insert: 'tpdf('),
            MenuItem('tcdf(', insert: 'tcdf('),
            MenuItem('χ²pdf(', insert: 'χ²pdf('),
            MenuItem('χ²cdf(', insert: 'χ²cdf('),
            MenuItem('Fpdf(', insert: 'Fpdf('),
            MenuItem('Fcdf(', insert: 'Fcdf('),
            MenuItem('binompdf(', insert: 'binompdf('),
            MenuItem('binomcdf(', insert: 'binomcdf('),
            MenuItem('poissonpdf(', insert: 'poissonpdf('),
            MenuItem('poissoncdf(', insert: 'poissoncdf('),
            MenuItem('geometpdf(', insert: 'geometpdf('),
            MenuItem('geometcdf(', insert: 'geometcdf('),
          ],
          [
            MenuItem('ShadeNorm(', action: () => s.insertText('ShadeNorm(')),
            MenuItem('Shade_t(', action: () => s.insertText('Shade_t(')),
            MenuItem('Shadeχ²(', action: () => s.insertText('Shadeχ²(')),
            MenuItem('ShadeF(', action: () => s.insertText('ShadeF(')),
          ],
        ],
      );

  MenuModel matrix() => MenuModel(
        title: 'MATRIX',
        tabs: ['NAMES', 'MATH', 'EDIT'],
        items: [
          [
            for (final n in ['[A]', '[B]', '[C]', '[D]', '[E]', '[F]', '[G]', '[H]', '[I]', '[J]'])
              MenuItem(n, insert: n),
          ],
          [
            MenuItem('det(', insert: 'det('),
            MenuItem('ᵀ', insert: 'ᵀ'),
            MenuItem('dim(', insert: 'dim('),
            MenuItem('Fill(', insert: 'Fill('),
            MenuItem('identity(', insert: 'identity('),
            MenuItem('randM(', insert: 'randM('),
            MenuItem('augment(', insert: 'augment('),
            MenuItem('rowSwap(', insert: 'rowSwap('),
            MenuItem('row+(', insert: 'row+('),
            MenuItem('*row(', insert: '*row('),
            MenuItem('*row+(', insert: '*row+('),
            MenuItem('ref(', insert: 'ref('),
            MenuItem('rref(', insert: 'rref('),
          ],
          [
            for (final n in ['[A]', '[B]', '[C]', '[D]', '[E]'])
              MenuItem(n, action: () => s.openMatrixEditor(n)),
          ],
        ],
      );

  MenuModel list() => MenuModel(
        title: 'LIST',
        tabs: ['NAMES', 'OPS', 'MATH'],
        items: [
          [
            for (var i = 1; i <= 6; i++) MenuItem('L$i', insert: 'L$i'),
          ],
          [
            MenuItem('SortA(', insert: 'SortA('),
            MenuItem('SortD(', insert: 'SortD('),
            MenuItem('dim(', insert: 'dim('),
            MenuItem('Fill(', insert: 'Fill('),
            MenuItem('seq(', insert: 'seq('),
            MenuItem('cumSum(', insert: 'cumSum('),
            MenuItem('ΔList(', insert: 'ΔList('),
            MenuItem('augment(', insert: 'augment('),
          ],
          [
            MenuItem('min(', insert: 'min('),
            MenuItem('max(', insert: 'max('),
            MenuItem('mean(', insert: 'mean('),
            MenuItem('median(', insert: 'median('),
            MenuItem('sum(', insert: 'sum('),
            MenuItem('prod(', insert: 'prod('),
            MenuItem('stdDev(', insert: 'stdDev('),
            MenuItem('variance(', insert: 'variance('),
          ],
        ],
      );

  MenuModel stat() => MenuModel(
        title: 'STAT',
        tabs: ['EDIT', 'CALC'],
        items: [
          [
            MenuItem('Edit...', action: () => s.openListEditor()),
            MenuItem('SortA(', insert: 'SortA('),
            MenuItem('SortD(', insert: 'SortD('),
            MenuItem('ClrList ', insert: 'ClrList '),
            MenuItem('SetUpEditor', action: () => s.setupEditor()),
          ],
          [
            MenuItem('1-Var Stats ', insert: '1-Var Stats '),
            MenuItem('2-Var Stats ', insert: '2-Var Stats '),
            MenuItem('Med-Med ', insert: 'Med-Med '),
            MenuItem('LinReg(ax+b) ', insert: 'LinReg(ax+b) '),
            MenuItem('QuadReg ', insert: 'QuadReg '),
            MenuItem('CubicReg ', insert: 'CubicReg '),
            MenuItem('QuartReg ', insert: 'QuartReg '),
            MenuItem('LinReg(a+bx) ', insert: 'LinReg(a+bx) '),
            MenuItem('LnReg ', insert: 'LnReg '),
            MenuItem('ExpReg ', insert: 'ExpReg '),
            MenuItem('PwrReg ', insert: 'PwrReg '),
          ],
        ],
      );

  MenuModel draw() => MenuModel(
        title: 'DRAW',
        tabs: ['DRAW', 'POINTS', 'STO'],
        items: [
          [
            MenuItem('ClrDraw', insert: 'ClrDraw'),
            MenuItem('Line(', insert: 'Line('),
            MenuItem('Horizontal ', insert: 'Horizontal '),
            MenuItem('Vertical ', insert: 'Vertical '),
            MenuItem('Tangent(', insert: 'Tangent('),
            MenuItem('DrawF ', insert: 'DrawF '),
            MenuItem('Shade(', insert: 'Shade('),
            MenuItem('DrawInv ', insert: 'DrawInv '),
          ],
          [
            MenuItem('Pt-On(', insert: 'Pt-On('),
            MenuItem('Pt-Off(', insert: 'Pt-Off('),
            MenuItem('Pt-Change(', insert: 'Pt-Change('),
          ],
          [
            MenuItem('StorePic ', insert: 'StorePic '),
            MenuItem('RecallPic ', insert: 'RecallPic '),
          ],
        ],
      );

  MenuModel vars() => MenuModel(
        title: 'VARS',
        tabs: ['VARS', 'Y-VARS'],
        items: [
          [
            for (final c in ['X', 'Y', 'Z', 'T'])
              MenuItem(c, insert: c),
            MenuItem('θ', insert: 'θ'),
            MenuItem('n', insert: 'n'),
          ],
          [
            MenuItem('Function...', sub: () => _yVars('Function', [
                  for (var i = 1; i <= 9; i++) 'Y$i',
                  'Y0'
                ])),
            MenuItem('Parametric...', sub: () => _yVars('Parametric', [
                  for (var i = 1; i <= 6; i++) ...['X${i}T', 'Y${i}T']
                ])),
            MenuItem('Polar...', sub: () => _yVars('Polar', [
                  for (var i = 1; i <= 6; i++) 'r$i'
                ])),
            MenuItem('Sequence...', sub: () => _yVars('Sequence', ['u', 'v', 'w'])),
            MenuItem('String...', sub: () => _yVars('String', [
                  for (var i = 0; i <= 9; i++) 'Str$i'
                ])),
          ],
        ],
      );

  MenuModel _yVars(String title, List<String> names) => MenuModel(
        title: title,
        tabs: [title],
        items: [
          [for (final n in names) MenuItem(n, insert: n)],
        ],
      );

  MenuModel zoom() => MenuModel(
        title: 'ZOOM',
        tabs: ['ZOOM', 'MEMORY'],
        items: [
          [
            MenuItem('ZBox', action: () => s.zoomAction('box')),
            MenuItem('Zoom In', action: () => s.zoomAction('in')),
            MenuItem('Zoom Out', action: () => s.zoomAction('out')),
            MenuItem('ZDecimal', action: () => s.zoomAction('decimal')),
            MenuItem('ZSquare', action: () => s.zoomAction('square')),
            MenuItem('ZStandard', action: () => s.zoomAction('standard')),
            MenuItem('ZTrig', action: () => s.zoomAction('trig')),
            MenuItem('ZInteger', action: () => s.zoomAction('integer')),
            MenuItem('ZoomStat', action: () => s.zoomAction('stat')),
            MenuItem('ZFit', action: () => s.zoomAction('fit')),
          ],
          [
            MenuItem('ZPrevious', action: () => s.zoomAction('previous')),
            MenuItem('ZoomSto', action: () => s.zoomAction('store')),
            MenuItem('ZoomRcl', action: () => s.zoomAction('recall')),
            MenuItem('Reset...', action: () => s.zoomAction('standard')),
          ],
        ],
      );

  MenuModel calc() => MenuModel(
        title: 'CALCULATE',
        tabs: ['CALC'],
        items: [
          [
            MenuItem('value', action: () => s.calcAction('value')),
            MenuItem('zero', action: () => s.calcAction('zero')),
            MenuItem('minimum', action: () => s.calcAction('min')),
            MenuItem('maximum', action: () => s.calcAction('max')),
            MenuItem('intersect', action: () => s.calcAction('intersect')),
            MenuItem('dy/dx', action: () => s.calcAction('dydx')),
            MenuItem('∫f(x)dx', action: () => s.calcAction('int')),
          ],
        ],
      );

  MenuModel catalog() => MenuModel(
        title: 'CATALOG',
        tabs: ['CATALOG'],
        items: [
          [
            for (final n in _catalogNames) MenuItem(n, insert: n),
          ],
        ],
      );

  MenuModel apps() => MenuModel(
        title: 'APPLICATIONS',
        tabs: ['APPS'],
        items: [
          [
            MenuItem('Finance...', action: () => s.openTvm()),
            MenuItem('Clock', action: () => s.openClock()),
            MenuItem('About', action: () => s.openAbout()),
          ],
        ],
      );

  MenuModel link() => MenuModel(
        title: 'LINK',
        tabs: ['SEND', 'RECEIVE'],
        items: [
          [
            MenuItem('All+...', action: () => s.linkFail()),
            MenuItem('Prgm...', action: () => s.linkFail()),
            MenuItem('List...', action: () => s.linkFail()),
            MenuItem('Matrix...', action: () => s.linkFail()),
          ],
          [MenuItem('Receive', action: () => s.linkFail())],
        ],
      );

  MenuModel mem() => MenuModel(
        title: 'MEMORY',
        tabs: ['MEMORY'],
        items: [
          [
            MenuItem('About', action: () => s.openAbout()),
            MenuItem('Mem Management/Delete...',
                action: () => s.openMemManage()),
            MenuItem('Clear Entries', action: () => s.clearEntries()),
            MenuItem('ClrAllLists', action: () => s.clearAllLists()),
            MenuItem('Archive/Unarchive...', action: () => s.openMemManage()),
            MenuItem('Reset...', action: () => s.resetAll()),
          ],
        ],
      );

  static const _catalogNames = [
    'abs(', 'and', 'angle(', 'Ans', 'asm(', 'augment(',
    'binomcdf(', 'binompdf(', 'conj(', 'cos(', 'cos⁻¹(',
    'cosh(', 'cosh⁻¹(', 'cumSum(', 'dbd(', 'det(', 'dim(',
    'Disp ', 'DrawF ', 'DrawInv ', 'e^(',
    'Else', 'End', 'expr(', 'ExpReg ',
    'fPart(', 'Fill(', 'fMax(', 'fMin(', 'fnInt(', 'For(',
    'gcd(', 'geometcdf(', 'geometpdf(', 'getDate(', 'getKey',
    'getTime(', 'Goto ', 'Horizontal ', 'i', 'identity(',
    'If ', 'imag(', 'Input', 'inString(', 'int(', 'invNorm(',
    'invT(', 'iPart(', 'Lbl ', 'lcm(', 'length(', 'Line(',
    'LinReg(a+bx) ', 'LinReg(ax+b) ', 'LnReg ', 'ln(', 'log(',
    'logBASE(', 'max(', 'mean(', 'Med-Med ', 'median(', 'Menu(',
    'min(', 'nCr', 'nDeriv(', 'not(', 'normalcdf(', 'normalpdf(',
    'nPr', 'or', 'Output(', 'Pause', 'piecewise(',
    'poissoncdf(', 'poissonpdf(', 'prod(', 'Prompt ', 'PwrReg ',
    'QuadReg ', 'QuartReg ', 'rand', 'randBin(', 'randInt(',
    'randIntNoRep(', 'randM(', 'randNorm(', 'real(', 'RecallPic ',
    'ref(', 'remainder(', 'Repeat ', 'round(', 'row+(',
    'rowSwap(', 'rref(', '*row(', '*row+(', 'seq(', 'sin(',
    'sin⁻¹(', 'sinh(', 'sinh⁻¹(', 'solve(', 'SortA(', 'SortD(',
    'stdDev(', 'Stop', 'StorePic ', 'sub(', 'sum(',
    'summation Σ(', 'tan(', 'tan⁻¹(', 'tanh(', 'tanh⁻¹(',
    'Then', 'While ', 'variance(', 'xor', 'ΔList(', '°', '′',
    '″', 'ʳ', '²', '³', '³√(', '⁻¹', 'ᵀ', '!', 'π', 'θ',
    '▸Dec', '▸DMS', '▸Frac', '▸n/d', '▸Polar', '▸Rect', '▸Un/d',
    'Σx', 'σx', 'χ²cdf(', 'χ²pdf(', '√(', 'ᴇ', '{', '}',
  ];
}
