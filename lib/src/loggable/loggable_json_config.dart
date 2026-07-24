import 'loggable.dart';
import 'loggable_config.dart';

final class _NoData {
  const _NoData();
}

const _noData = _NoData();

/// Конфигурация для [objectToJson].
///
/// [collectionMaxCount] - максимальное количество элементов в коллекции
/// (для [List], [Set] и [Iterable]). Если равно null, нет ограничений.
///
/// Обратите внимание! Все параметры действуют рекурсивно не только на сам
/// объект, но и на все вложенные в него объекты. При этом установленные
/// параметры сбросить в null уже нельзя.
abstract base class LoggableJsonConfig with Loggable {
  final int? collectionMaxCount;
  final String? units;

  const factory LoggableJsonConfig({
    int? collectionMaxCount,
    String? units,
  }) = _LoggableJsonConfig;

  const LoggableJsonConfig._({
    this.collectionMaxCount,
    this.units,
  });

  LoggableJsonConfig copyWith({
    int? collectionMaxCount,
    String? units,
  });

  @override
  void collectLoggableData(LoggableData data) {
    data
      ..name = '$LoggableJsonConfig'
      ..whenNotNull('collectionMaxCount', collectionMaxCount)
      ..whenNotNull('units', units);
  }
}

final class _LoggableJsonConfig extends LoggableJsonConfig {
  const _LoggableJsonConfig({
    super.collectionMaxCount,
    super.units,
  }) : super._();

  @override
  LoggableJsonConfig copyWith({
    Object? collectionMaxCount = _noData,
    Object? units = _noData,
  }) =>
      _LoggableJsonConfig(
        collectionMaxCount: collectionMaxCount is _NoData
            ? this.collectionMaxCount
            : collectionMaxCount as int?,
        units: units is _NoData ? this.units : units as String?,
      );
}
