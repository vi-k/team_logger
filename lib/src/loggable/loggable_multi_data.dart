import 'loggable.dart';
import 'loggable_config.dart';

final class LoggableMultiData {
  final Map<String, Object?> data;
  final LoggableConfig config;

  LoggableMultiData(
    this.data, {
    LoggableConfig? config,
    bool? enumDotShorthand,
    int? collectionMaxLength,
    int? collectionMaxStringLength,
    bool? collectionShowLength,
    bool? collectionShowIndexes,
    String? units,
    String? doubleFormat,
    String? intFormat,
  })  : assert(
          config == null ||
              (enumDotShorthand == null &&
                  collectionMaxLength == null &&
                  collectionMaxStringLength == null &&
                  collectionShowLength == null &&
                  collectionShowIndexes == null &&
                  units == null &&
                  doubleFormat == null &&
                  intFormat == null),
          'Use either `LoggableConfig` or individual parameters',
        ),
        config = config ??
            LoggableConfig(
              enumDotShorthand: enumDotShorthand,
              collectionMaxLength: collectionMaxLength,
              collectionMaxStringLength: collectionMaxStringLength,
              collectionShowLength: collectionShowLength,
              collectionShowIndexes: collectionShowIndexes,
              units: units,
              doubleFormat: doubleFormat,
              intFormat: intFormat,
            );

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
