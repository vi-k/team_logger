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
  }) {
    // Корень предлагаем правилу тем же хелпером, что и обходчики: этот
    // метод в них не заходит, поэтому без вызова сам объект данных
    // правилу не показывался бы вовсе.
    if (Loggable.sanitizeRootToString(this, config: config)
        case final rendered?) {
      return rendered;
    }

    // Секции — через общий хелпер, а не по data.entries напрямую: иначе
    // значение секции ушло бы в обходчик как корень — мимо правил по
    // имени и с потерей префикса пути (см.
    // [Loggable.forEachMultiDataEntry]).
    final parts = <String>[];
    Loggable.forEachMultiDataEntry(this, (key, value) {
      final text = Loggable.objectToString(value, config: config);
      parts.add(
        '${key.isEmpty ? '' : '${keyFormatter?.call(key) ?? key}: '}'
        '${valueFormatter?.call(text) ?? text}',
      );
    });

    return parts.join(wrapLines ? '\n' : ', ');
  }
}
