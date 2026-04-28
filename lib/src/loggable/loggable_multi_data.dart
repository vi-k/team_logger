import 'loggable.dart';

final class LoggableMultiData {
  final Map<String, Object?> data;
  final int? collectionMaxCount;
  final int? collectionMaxLength;
  final bool? showCount;
  final bool? showIndexes;
  final String? units;

  const LoggableMultiData(
    this.data, {
    this.collectionMaxCount,
    this.collectionMaxLength,
    this.showCount,
    this.showIndexes,
    this.units,
  });

  @override
  String toString({
    bool wrapLines = false,
    String Function(String key)? keyFormatter,
    String Function(String value)? valueFormatter,
  }) =>
      data.entries.map((e) {
        final value = Loggable.objectToString(e.value);
        final key = e.key;
        return '${key.isEmpty ? '' : '${keyFormatter?.call(key) ?? key}: '}'
            '${valueFormatter?.call(value) ?? value}';
      }).join(wrapLines ? '\n' : ', ');
}
