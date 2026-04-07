import 'loggable.dart';

final class LoggableMultiData {
  final Map<String, Object?> data;

  const LoggableMultiData(this.data);

  @override
  String toString({
    bool wrapLines = false,
    String Function(String key)? keyFormatter,
    String Function(String value)? valueFormatter,
  }) =>
      data.entries.map((e) {
        final value = Loggable.objectToString(e.value);
        return '${keyFormatter?.call(e.key) ?? e.key}:'
            ' ${valueFormatter?.call(value) ?? value}';
      }).join(wrapLines ? '\n' : ', ');
}
