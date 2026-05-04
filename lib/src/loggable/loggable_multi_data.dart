import 'loggable.dart';
import 'loggable_config.dart';

final class LoggableMultiData {
  final Map<String, Object?> data;
  final LoggableConfig config;

  LoggableMultiData(
    this.data, {
    this.config = const LoggableConfig(),
  });

  @override
  String toString({
    bool wrapLines = false,
    String Function(String key)? keyFormatter,
    String Function(String value)? valueFormatter,
  }) =>
      data.entries.map((e) {
        final value = Loggable.objectToString(e.value, config: config);
        final key = e.key;
        return '${key.isEmpty ? '' : '${keyFormatter?.call(key) ?? key}: '}'
            '${valueFormatter?.call(value) ?? value}';
      }).join(wrapLines ? '\n' : ', ');
}
