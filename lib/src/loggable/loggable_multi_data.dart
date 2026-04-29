import 'loggable.dart';

final class LoggableMultiData {
  final Map<String, Object?> data;
  final bool? enumDotShorthand;
  final int? collectionMaxLength;
  final int? collectionMaxStringLength;
  final bool? collectionShowLength;
  final bool? collectionShowIndexes;
  final String? units;

  const LoggableMultiData(
    this.data, {
    this.enumDotShorthand,
    this.collectionMaxLength,
    this.collectionMaxStringLength,
    this.collectionShowLength,
    this.collectionShowIndexes,
    this.units,
  });

  @override
  String toString({
    bool wrapLines = false,
    String Function(String key)? keyFormatter,
    String Function(String value)? valueFormatter,
  }) =>
      data.entries.map((e) {
        final value = Loggable.objectToString(
          e.value,
          enumDotShorthand: enumDotShorthand,
          collectionMaxLength: collectionMaxLength,
          collectionMaxStringLength: collectionMaxStringLength,
          collectionShowLength: collectionShowLength,
          collectionShowIndexes: collectionShowIndexes,
        );
        final key = e.key;
        return '${key.isEmpty ? '' : '${keyFormatter?.call(key) ?? key}: '}'
            '${valueFormatter?.call(value) ?? value}';
      }).join(wrapLines ? '\n' : ', ');
}
