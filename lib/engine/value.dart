import 'complex.dart';
import 'matrix.dart';

/// Runtime value produced by evaluating an expression.
sealed class Value {
  const Value();
}

class RealValue extends Value {
  const RealValue(this.v);

  final double v;

  @override
  String toString() => '$v';
}

class ComplexValue extends Value {
  const ComplexValue(this.v);

  final Complex v;

  @override
  String toString() => '$v';
}

class ListValue extends Value {
  const ListValue(this.items);

  final List<Value> items;

  @override
  String toString() => '{${items.join(' ')}}';
}

class MatrixValue extends Value {
  const MatrixValue(this.m);

  final Matrix m;

  @override
  String toString() => '[$m]';
}

class StringValue extends Value {
  const StringValue(this.v);

  final String v;

  @override
  String toString() => v;
}

class CalcException implements Exception {
  const CalcException(this.code, [this.detail]);

  /// Short error code in the spirit of the classic error screens.
  final String code;
  final String? detail;

  @override
  String toString() => 'ERR:$code${detail == null ? '' : ' $detail'}';
}

extension ValueNum on Value {
  double get asReal {
    final v = this;
    if (v is RealValue) return v.v;
    if (v is ComplexValue && v.v.isReal) return v.v.re;
    throw const CalcException('DATA TYPE');
  }

  Complex get asComplex {
    final v = this;
    if (v is RealValue) return Complex(v.v, 0);
    if (v is ComplexValue) return v.v;
    throw const CalcException('DATA TYPE');
  }

  bool get isComplex => this is ComplexValue;
}

