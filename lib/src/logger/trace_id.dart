import 'logger.dart';

/// Идентификатор трассировки в виде: #123 или #Group-123
///
/// Группа и номер могут быть заданы вручную: Trace.manual(group, num). Или
/// можно задать только группу с автоматической нумерацией внутри неё:
/// Trace.auto(group). Или выбрать глобальную автоматическую нумерацию:
/// `Trace.global()`.
sealed class TraceId {
  const TraceId();

  /// Ручная установка номера.
  const factory TraceId.manual(String group, int num) = _ConstTraceId;

  /// Ленивая автоматическая нумерация.
  ///
  /// Нумерация увеличивается лениво только при использовании, чтобы не считать
  /// отключенные логи. Если необходимо зафиксировать значение, используйте
  /// метод [resolve]. В [Log] traceId's попадают уже зафиксированными.
  factory TraceId.auto(String group, {int initial}) = _LazyAutoTraceId;

  /// Ленивая автоматическая нумерация без группы.
  ///
  /// See also [TraceId.auto].
  factory TraceId.global({int initial}) = _LazyAutoTraceId.global;

  String? get group;

  int get num;

  String? get suffix;

  // Добавление суффикса к идентификатору в виде: group-123.suffix
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

  // Добавление суффикса к идентификатору.
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
