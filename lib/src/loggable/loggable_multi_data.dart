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
    // The root is offered to the rule through the same helper the walkers
    // use: this method does not enter them, so without the call the data
    // object itself would never be shown to the rule at all.
    if (Loggable.sanitizeRootToString(this, config: config)
        case final rendered?) {
      return rendered.text;
    }

    // Sections go through the shared helper rather than data.entries
    // directly: otherwise a section's value would reach the walker as a
    // root — past name-based rules and losing the path prefix (see
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
