import 'logger.dart';

/// A trace identifier: `123`, `group-123` or `group-123.suffix`.
///
/// [TraceId.auto] numbering is lazy: the number is consumed on first use
/// (a disabled log does not consume one), so numbers follow resolve order,
/// and `initial` only takes effect for the first resolve in a group.
/// Group counters live for the whole isolate.
sealed class TraceId {
  const TraceId();

  /// A number set by hand.
  const factory TraceId.manual(String group, int num) = _ConstTraceId;

  /// Lazy automatic numbering.
  ///
  /// The number is consumed only on use, so disabled logs do not count. To
  /// pin the value, call [resolve]; trace ids reach [Log] already pinned.
  factory TraceId.auto(String group, {int initial}) = _LazyAutoTraceId;

  /// Lazy automatic numbering without a group.
  ///
  /// See also [TraceId.auto].
  factory TraceId.global({int initial}) = _LazyAutoTraceId.global;

  String? get group;

  int get num;

  String? get suffix;

  // Appends a suffix to the identifier: group-123.suffix
  TraceId withSuffix(String suffix);

  void resolve();

  static String _buildSuffix(String? currentSuffix, String addedSuffix) =>
      '${currentSuffix ?? ''}.$addedSuffix';

  @override
  String toString() => '${group == null ? '' : '$group-'}$num${suffix ?? ''}';
}

final class _ConstTraceId extends TraceId {
  @override
  final String? group;

  @override
  final int num;

  const _ConstTraceId(String this.group, this.num);

  @override
  String? get suffix => null;

  // Appends a suffix to the identifier.
  @override
  TraceId withSuffix(String suffix) =>
      _TraceIdWithSuffix(this, TraceId._buildSuffix(this.suffix, suffix));

  @override
  void resolve() {}
}

final class _LazyAutoTraceId extends TraceId {
  static final Map<String?, int> _autoNums = {};

  @override
  final String? group;

  final int initial;

  int? _num;

  _LazyAutoTraceId(String this.group, {this.initial = 1});

  _LazyAutoTraceId.global({this.initial = 1}) : group = null;

  @override
  String? get suffix => null;

  @override
  int get num => _num ??= _nextNum(initial);

  int _nextNum(int initial) =>
      _autoNums[group] = (_autoNums[group] ?? initial - 1) + 1;

  @override
  TraceId withSuffix(String suffix) =>
      _TraceIdWithSuffix(this, TraceId._buildSuffix(this.suffix, suffix));

  @override
  void resolve() {
    num;
  }
}

final class _TraceIdWithSuffix extends TraceId {
  final TraceId _base;

  @override
  final String suffix;

  _TraceIdWithSuffix(this._base, this.suffix);

  @override
  String? get group => _base.group;

  @override
  int get num => _base.num;

  @override
  void resolve() => _base.resolve();

  @override
  TraceId withSuffix(String suffix) =>
      _TraceIdWithSuffix(_base, TraceId._buildSuffix(this.suffix, suffix));
}
