import 'value.dart';

/// Dense real matrix used by the [A]-[J] matrix variables.
class Matrix {
  Matrix(int rows, int cols, [double fill = 0])
      : rows = rows,
        cols = cols,
        data = List.generate(rows, (_) => List.filled(cols, fill));

  Matrix.from(this.data)
      : rows = data.length,
        cols = data.isEmpty ? 0 : data.first.length;

  final int rows;
  final int cols;
  final List<List<double>> data;

  factory Matrix.identity(int n) {
    final m = Matrix(n, n);
    for (var i = 0; i < n; i++) {
      m.data[i][i] = 1;
    }
    return m;
  }

  double at(int r, int c) => data[r][c];

  void set(int r, int c, double v) => data[r][c] = v;

  Matrix copy() => Matrix.from([for (final row in data) List.of(row)]);

  Matrix transpose() {
    final m = Matrix(cols, rows);
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        m.data[c][r] = data[r][c];
      }
    }
    return m;
  }

  Matrix operator +(Matrix o) {
    _checkSame(o);
    final m = Matrix(rows, cols);
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        m.data[r][c] = data[r][c] + o.data[r][c];
      }
    }
    return m;
  }

  Matrix operator -(Matrix o) {
    _checkSame(o);
    final m = Matrix(rows, cols);
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        m.data[r][c] = data[r][c] - o.data[r][c];
      }
    }
    return m;
  }

  Matrix multiply(Matrix o) {
    if (cols != o.rows) throw const CalcException('DIM MISMATCH');
    final m = Matrix(rows, o.cols);
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < o.cols; c++) {
        var s = 0.0;
        for (var k = 0; k < cols; k++) {
          s += data[r][k] * o.data[k][c];
        }
        m.data[r][c] = s;
      }
    }
    return m;
  }

  Matrix scale(double s) {
    final m = Matrix(rows, cols);
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        m.data[r][c] = data[r][c] * s;
      }
    }
    return m;
  }

  Matrix pow(int n) {
    if (rows != cols) throw const CalcException('DIM MISMATCH');
    if (n < 0) return inverse().pow(-n);
    var result = Matrix.identity(rows);
    var base = this;
    var e = n;
    while (e > 0) {
      if (e.isOdd) result = result.multiply(base);
      base = base.multiply(base);
      e >>= 1;
    }
    return result;
  }

  double determinant() {
    if (rows != cols) throw const CalcException('DIM MISMATCH');
    final a = copy().data;
    var det = 1.0;
    for (var col = 0; col < rows; col++) {
      var pivot = col;
      for (var r = col + 1; r < rows; r++) {
        if (a[r][col].abs() > a[pivot][col].abs()) pivot = r;
      }
      if (a[pivot][col] == 0) return 0;
      if (pivot != col) {
        final tmp = a[col];
        a[col] = a[pivot];
        a[pivot] = tmp;
        det = -det;
      }
      det *= a[col][col];
      for (var r = col + 1; r < rows; r++) {
        final f = a[r][col] / a[col][col];
        for (var c = col; c < rows; c++) {
          a[r][c] -= f * a[col][c];
        }
      }
    }
    return det;
  }

  Matrix inverse() {
    if (rows != cols) throw const CalcException('DIM MISMATCH');
    final n = rows;
    final a = [for (var r = 0; r < n; r++) [...data[r], ...Matrix.identity(n).data[r]]];
    for (var col = 0; col < n; col++) {
      var pivot = col;
      for (var r = col + 1; r < n; r++) {
        if (a[r][col].abs() > a[pivot][col].abs()) pivot = r;
      }
      if (a[pivot][col] == 0) throw const CalcException('SINGULAR MAT');
      final tmp = a[col];
      a[col] = a[pivot];
      a[pivot] = tmp;
      final p = a[col][col];
      for (var c = 0; c < 2 * n; c++) {
        a[col][c] /= p;
      }
      for (var r = 0; r < n; r++) {
        if (r == col) continue;
        final f = a[r][col];
        for (var c = 0; c < 2 * n; c++) {
          a[r][c] -= f * a[col][c];
        }
      }
    }
    return Matrix.from([for (var r = 0; r < n; r++) a[r].sublist(n)]);
  }

  /// Gaussian elimination to row echelon form.
  Matrix ref() => _eliminate(false);

  /// Reduced row echelon form.
  Matrix rref() => _eliminate(true);

  Matrix _eliminate(bool reduced) {
    final a = copy().data;
    var lead = 0;
    for (var r = 0; r < rows && lead < cols; r++) {
      var i = r;
      while (lead < cols && a[i][lead] == 0) {
        i++;
        if (i == rows) {
          i = r;
          lead++;
        }
      }
      if (lead == cols) break;
      final tmp = a[i];
      a[i] = a[r];
      a[r] = tmp;
      final lv = a[r][lead];
      if (lv != 0) {
        for (var c = 0; c < cols; c++) {
          a[r][c] /= lv;
        }
      }
      final start = reduced ? 0 : r + 1;
      for (var i2 = start; i2 < rows; i2++) {
        if (i2 == r) continue;
        final f = a[i2][lead];
        for (var c = 0; c < cols; c++) {
          a[i2][c] -= f * a[r][c];
        }
      }
      lead++;
    }
    for (final row in a) {
      for (var c = 0; c < row.length; c++) {
        if (row[c].abs() < 1e-12) row[c] = 0;
      }
    }
    return Matrix.from(a);
  }

  void swapRows(int a, int b) {
    final t = data[a];
    data[a] = data[b];
    data[b] = t;
  }

  void addRows(int dst, int src) {
    for (var c = 0; c < cols; c++) {
      data[dst][c] += data[src][c];
    }
  }

  void scaleRow(int r, double k) {
    for (var c = 0; c < cols; c++) {
      data[r][c] *= k;
    }
  }

  void addScaledRow(int dst, int k, int src) =>
      addScaledRowK(dst, k.toDouble(), src);

  void addScaledRowK(int dst, double k, int src) {
    for (var c = 0; c < cols; c++) {
      data[dst][c] += k * data[src][c];
    }
  }

  void _checkSame(Matrix o) {
    if (o.rows != rows || o.cols != cols) {
      throw const CalcException('DIM MISMATCH');
    }
  }

  @override
  String toString() =>
      '[${data.map((r) => r.join(' ')).join(' ; ')}]';
}
