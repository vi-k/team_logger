final class LoggableNamedData {
  final String name;
  final Object? data;
  final int? collectionMaxCount;
  final int? collectionMaxLength;
  final bool? showCount;
  final bool? showIndexes;
  final String? units;

  const LoggableNamedData(
    this.name,
    this.data, {
    this.collectionMaxCount,
    this.collectionMaxLength,
    this.showCount,
    this.showIndexes,
    this.units,
  });
}
