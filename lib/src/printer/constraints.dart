import 'dart:math' as math;

sealed class Constraints {
  const factory Constraints({int min, int? max}) = _ConstConstraints;

  const factory Constraints.unlimited() = _ConstConstraints.unlimited;

  const factory Constraints.exact(int size) = _ConstConstraints.exact;

  factory Constraints.growable({int initial, int? max}) = _GrowableConstraints;

  const Constraints._();

  int get _min;

  int? get _max;

  bool get isGrowable;

  int apply(int value) => switch (_max) {
        null => math.max(value, _min),
        final max when _min <= max => value.clamp(_min, max),
        final max => math.min(value, max),
      };

  Constraints restrict(int? max);

  int _restrict(int max) => switch (_max) {
        null => max,
        final currentMax => math.min(currentMax, max),
      };

  @override
  String toString() =>
      '$Constraints(min: $_min, max: $_max, isGrowable: $isGrowable)';
}

final class _ConstConstraints extends Constraints {
  @override
  final int _min;

  @override
  final int? _max;

  const _ConstConstraints({int min = 0, int? max})
      : _min = min,
        _max = max,
        super._();

  const _ConstConstraints.exact(int size)
      : _min = size,
        _max = size,
        super._();

  const _ConstConstraints.unlimited()
      : _min = 0,
        _max = null,
        super._();

  @override
  bool get isGrowable => false;

  @override
  Constraints restrict(int? max) =>
      max == null ? this : _ConstConstraints(min: _min, max: _restrict(max));
}

final class _GrowableConstraints extends Constraints {
  @override
  int _min;

  @override
  final int? _max;

  _GrowableConstraints({int initial = 0, int? max})
      : _min = initial,
        _max = max,
        super._();

  @override
  bool get isGrowable => true;

  @override
  int apply(int value) => _min = super.apply(value);

  @override
  Constraints restrict(int? max) =>
      max == null ? this : _GrowableWrapper(this, _restrict(max));
}

final class _GrowableWrapper extends Constraints {
  final _GrowableConstraints _constraints;

  @override
  final int _max;

  _GrowableWrapper(this._constraints, this._max) : super._();

  @override
  int get _min => _constraints._min;

  @override
  bool get isGrowable => true;

  @override
  int apply(int value) => _constraints.apply(math.min(value, _max));

  @override
  Constraints restrict(int? max) => max == null || max >= _max
      ? this
      : _GrowableWrapper(_constraints, _restrict(max));
}

final class GrowableConstraintsValues {
  final List<Constraints> values = [];
  final int initial;
  final int? max;

  GrowableConstraintsValues({this.initial = 0, this.max});

  Constraints operator [](int index) {
    while (index >= values.length) {
      values.add(Constraints.growable(initial: initial, max: max));
    }

    return values[index];
  }
}
