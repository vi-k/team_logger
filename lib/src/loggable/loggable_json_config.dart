import 'package:meta/meta.dart';

import 'loggable.dart';
import 'loggable_config.dart';

/// Конфигурация для [objectToJson].
///
/// [collectionMaxCount] - максимальное количество элементов в коллекции
/// (для [List], [Set] и [Iterable]). Если равно null, нет ограничений.
///
/// Обратите внимание! Все параметры действуют рекурсивно не только на сам
/// объект, но и на все вложенные в него объекты. При этом установленные
/// параметры сбросить в null уже нельзя.
/// [iterableEfficientLength] - то же утверждение, что и в
/// `LoggableConfig`: у голого [Iterable] длина и последний элемент дёшевы,
/// и его можно печатать с `":l"` вместо `":trim"`.
abstract base class LoggableJsonConfig with Loggable {
  final int? collectionMaxCount;
  final String? units;
  final bool? iterableEfficientLength;

  const factory LoggableJsonConfig({
    int? collectionMaxCount,
    String? units,
    bool? iterableEfficientLength,
  }) = _LoggableJsonConfig;

  const LoggableJsonConfig._({
    this.collectionMaxCount,
    this.units,
    this.iterableEfficientLength,
  });

  LoggableJsonConfig copyWith({
    int? collectionMaxCount,
    String? units,
    bool? iterableEfficientLength,
  });

  /// Значения с наложенной цепочкой `default ← этот конфиг ← force`.
  ///
  /// Слои общие со строковым выводом: политика у приложения одна, и
  /// заводить для JSON вторую пару статик значило бы позволить им
  /// разойтись. Из `LoggableConfig` берутся те поля, которые здесь есть.
  @internal
  int? get resolvedCollectionMaxCount =>
      Loggable.forceConfig.collectionMaxCount ??
      collectionMaxCount ??
      Loggable.defaultConfig.collectionMaxCount;

  @internal
  String? get resolvedUnits =>
      Loggable.forceConfig.units ?? units ?? Loggable.defaultConfig.units;

  @internal
  bool get resolvedIterableEfficientLength =>
      Loggable.forceConfig.iterableEfficientLength ??
      iterableEfficientLength ??
      Loggable.defaultConfig.iterableEfficientLength ??
      LoggableConfig.defaultIterableEfficientLength;

  @override
  void collectLoggableData(LoggableData data) {
    data
      ..name = '$LoggableJsonConfig'
      ..whenNotNull('collectionMaxCount', collectionMaxCount)
      ..whenNotNull('units', units)
      ..whenNotNull('iterableEfficientLength', iterableEfficientLength);
  }
}

/// Маркер «параметр не передан» для [_LoggableJsonConfig.copyWith].
///
/// Собственный приватный тип, а не `const Object()`: все `const Object()`
/// в программе — один и тот же объект. Здесь маркер сравнивается только
/// с параметрами по умолчанию внутри пакета, так что коллизия сейчас не
/// достижима, — но именно такая коллизия уже была настоящим багом в
/// другом месте (см. [Prop._notSanitized]), поэтому тот же приватный тип
/// используется и тут, а не только там, где он уже эксплуатируем.
final class _Undefined {
  const _Undefined();
}

final class _LoggableJsonConfig extends LoggableJsonConfig {
  static const _undefined = _Undefined();

  const _LoggableJsonConfig({
    super.collectionMaxCount,
    super.units,
    super.iterableEfficientLength,
  }) : super._();

  @override
  LoggableJsonConfig copyWith({
    Object? collectionMaxCount = _undefined,
    Object? units = _undefined,
    Object? iterableEfficientLength = _undefined,
  }) =>
      _LoggableJsonConfig(
        collectionMaxCount: identical(collectionMaxCount, _undefined)
            ? this.collectionMaxCount
            : collectionMaxCount as int?,
        units: identical(units, _undefined) ? this.units : units as String?,
        iterableEfficientLength: identical(iterableEfficientLength, _undefined)
            ? this.iterableEfficientLength
            : iterableEfficientLength as bool?,
      );
}
