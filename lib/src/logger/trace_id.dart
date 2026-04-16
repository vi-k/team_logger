/// Идентификатор трассировки в виде: #123 или #Group-123
///
/// Группа и номер могут быть заданы вручную: Trace.manual(group, num). Или
/// можно задать только группу с автоматической нумерацией внутри неё:
/// Trace.auto(group). Или выбрать глобальную автоматическую нумерацию:
/// `Trace.global()`.
sealed class TraceId {
  const TraceId._();

  /// Ручная установка номера.
  const factory TraceId.manual(String group, int num) = _ConstTraceId;

  /// Автоматическая нумерация.
  factory TraceId.auto(String group, {int initial}) = _AutoTraceId;

  /// Автоматическая нумерация без группы.
  factory TraceId.global({int initial}) = _AutoTraceId.global;

  String? get group;

  int get num;

  String? get suffix;

  TraceId withSuffix(String suffix);

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

  @override
  final String? suffix;

  const _ConstTraceId(String this.group, this.num)
      : suffix = null,
        super._();

  const _ConstTraceId._(this.group, this.num, this.suffix) : super._();

  // Добавление суффикса к идентификатору.
  @override
  TraceId withSuffix(String suffix) =>
      _ConstTraceId._(group, num, TraceId._buildSuffix(this.suffix, suffix));
}

final class _AutoTraceId extends TraceId {
  static final Map<String?, int> _autoNums = {};

  @override
  final String? group;

  @override
  final String? suffix;

  final int initial;

  int? _num;

  _AutoTraceId(String this.group, {this.initial = 1})
      : suffix = null,
        super._();

  _AutoTraceId.global({this.initial = 1})
      : group = null,
        suffix = null,
        super._();

  _AutoTraceId._(this.group, this.initial, this.suffix) : super._();

  @override
  int get num => _num ??= _nextNum(initial);

  int _nextNum(int initial) =>
      _autoNums[group] = (_autoNums[group] ?? initial - 1) + 1;

  @override
  TraceId withSuffix(String suffix) =>
      _AutoTraceId._(group, initial, TraceId._buildSuffix(this.suffix, suffix));
}
