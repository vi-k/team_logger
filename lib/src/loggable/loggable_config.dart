import 'package:meta/meta.dart';

import '../theme/log_main_theme.dart';
import 'loggable.dart';
import 'loggable_json_config.dart';

/// Конфигурация для [objectToString].
///
/// [enumDotShorthand] - сокращенное представление enums в виде `.value`.
/// Если равно null, значение берётся из [LogMainTheme.enumDotShorthand].
///
/// [collectionMaxCount] - максимальное количество элементов в коллекции
/// (для [List], [Set] и [Iterable]). Если равно null, нет ограничений.
///
/// [collectionMaxStringLength] - максимальная длина результирующей строки
/// после преобразования коллекции. В реальности строка может быть больше,
/// т.к. итерируемые объекты обязательно должны содержать первый элемент,
/// а списки первый и последний элемент без сокращений. Если равно null,
/// ограничений.
///
/// [collectionShowCount] - показывать ли длину коллекции в виде `₌₄`
/// (только для List и Set). Если равно null, значение берётся из
/// [LogMainTheme.collectionShowCount].
///
/// [collectionShowIndexes] - показывать ли индексы элементов в виде `₀:`,
/// `₁:` и т.д. Если равно null, значение берётся из
/// [LogMainTheme.collectionShowIndexes].
///
/// [units] - единицы измерения, будут добавлены к представлению объекта
/// в виде суффикса. Если равно null, единицы не добавляются.
///
/// [intFormat] и [doubleFormat] - шаблоны для чисел. Пакет их не
/// разбирает: шаблон уходит в [LogMainTheme.numberFormatter] темы вместе
/// со значением, и смысл ему придаёт форматтер. Тема без форматтера
/// шаблон игнорирует и печатает число как есть - исключения не будет.
/// Рецепт поверх `package:format`:
/// `numberFormatter: (theme, value, pattern) => format(pattern, value)`,
/// и тогда в конфиге пишут `'{:,d}'`, `'{:.4f}'` и так далее.
///
/// Обратите внимание! Все параметры действуют рекурсивно не только на сам
/// объект, но и на все вложенные в него объекты. При этом установленные
/// параметры сбросить в null уже нельзя.
///
/// ```dart
/// log.d(
///   'data',
///   data: Loggable.from(
///     [1, 2, [3, 4, 5]],
///     config: LoggableConfig(
///       units: 'kg',
///       collectionMaxCount: 2,
///     ),
///   ),
/// );
/// // data: [₌₃ ₀:1kg, …, ₂:[₌₃ ₀:3kg, …, ₂:5kg]]
/// ```
final class LoggableConfig with Loggable {
  final bool? enumDotShorthand;
  final int? collectionMaxCount;
  final int? collectionMaxStringLength;
  final bool? collectionShowCount;
  final bool? collectionShowIndexes;
  final String? units;
  final String? doubleFormat;
  final String? intFormat;
  final bool? stringInQuotes;

  const LoggableConfig({
    this.enumDotShorthand,
    this.collectionMaxCount,
    this.collectionMaxStringLength,
    this.collectionShowCount,
    this.collectionShowIndexes,
    this.units,
    this.doubleFormat,
    this.intFormat,
    this.stringInQuotes,
  });

  LoggableConfig merge(LoggableConfig other) => LoggableConfig(
        enumDotShorthand: enumDotShorthand ?? other.enumDotShorthand,
        collectionMaxCount: collectionMaxCount ?? other.collectionMaxCount,
        collectionMaxStringLength:
            collectionMaxStringLength ?? other.collectionMaxStringLength,
        collectionShowCount: collectionShowCount ?? other.collectionShowCount,
        collectionShowIndexes:
            collectionShowIndexes ?? other.collectionShowIndexes,
        units: units ?? other.units,
        doubleFormat: doubleFormat ?? other.doubleFormat,
        intFormat: intFormat ?? other.intFormat,
        stringInQuotes: stringInQuotes ?? other.stringInQuotes,
      );

  /// Копия конфигурации без [units].
  ///
  /// Нужна там, где значение подставлено санитайзером: units описывают
  /// исходную величину, а замаскированное значение — уже не она
  /// (см. `Prop.toLogString`).
  @internal
  LoggableConfig withoutUnits() => LoggableConfig(
        enumDotShorthand: enumDotShorthand,
        collectionMaxCount: collectionMaxCount,
        collectionMaxStringLength: collectionMaxStringLength,
        collectionShowCount: collectionShowCount,
        collectionShowIndexes: collectionShowIndexes,
        doubleFormat: doubleFormat,
        intFormat: intFormat,
        stringInQuotes: stringInQuotes,
      );

  LoggableEffectiveConfig toEffectiveConfig(LogMainTheme theme) =>
      LoggableEffectiveConfig(
        enumDotShorthand: enumDotShorthand ?? theme.enumDotShorthand,
        collectionMaxCount: collectionMaxCount,
        collectionMaxStringLength: collectionMaxStringLength,
        collectionShowCount: collectionShowCount ?? theme.collectionShowCount,
        collectionShowIndexes:
            collectionShowIndexes ?? theme.collectionShowIndexes,
        units: units,
        doubleFormat: doubleFormat,
        intFormat: intFormat,
        stringInQuotes: stringInQuotes ?? theme.stringInQuotes,
      );

  LoggableJsonConfig mergeWithJsonConfig(LoggableJsonConfig config) =>
      LoggableJsonConfig(
        collectionMaxCount: collectionMaxCount ?? config.collectionMaxCount,
        units: units ?? config.units,
      );

  @override
  void collectLoggableData(LoggableData data) {
    data
      ..prop('enumDotShorthand', enumDotShorthand)
      ..prop('collectionMaxCount', collectionMaxCount)
      ..prop('collectionMaxStringLength', collectionMaxStringLength)
      ..prop('collectionShowCount', collectionShowCount)
      ..prop('collectionShowIndexes', collectionShowIndexes)
      ..prop('units', units)
      ..prop('doubleFormat', doubleFormat)
      ..prop('intFormat', intFormat)
      ..prop('stringInQuotes', stringInQuotes);
  }
}

final class LoggableEffectiveConfig extends LoggableConfig with Loggable {
  const LoggableEffectiveConfig({
    required bool super.enumDotShorthand,
    required super.collectionMaxCount,
    required super.collectionMaxStringLength,
    required bool super.collectionShowCount,
    required bool super.collectionShowIndexes,
    required super.units,
    required super.doubleFormat,
    required super.intFormat,
    required bool super.stringInQuotes,
  });

  @override
  bool get enumDotShorthand => super.enumDotShorthand!;

  @override
  bool get collectionShowCount => super.collectionShowCount!;

  @override
  bool get collectionShowIndexes => super.collectionShowIndexes!;

  @override
  bool get stringInQuotes => super.stringInQuotes!;
}
