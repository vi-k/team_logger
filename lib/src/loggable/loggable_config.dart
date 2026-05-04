import '../theme/log_theme.dart';
import 'loggable.dart';

/// Конфигурация для [objectToString].
///
/// [enumDotShorthand] - сокращенное представление enums в виде `.value`.
/// Если равно null, значение берётся из [LogTheme.enumDotShorthand].
///
/// [collectionMaxLength] - максимальное количество элементов в коллекции
/// (для [List], [Set] и [Iterable]). Если равно null, нет ограничений.
///
/// [collectionMaxStringLength] - максимальная длина результирующей строки
/// после преобразования коллекции. В реальности строка может быть больше,
/// т.к. итерируемые объекты обязательно должны содержать первый элемент,
/// а списки первый и последний элемент без сокращений. Если равно null,
/// ограничений.
///
/// [collectionShowLength] - показывать ли длину коллекции в виде `₌₄`
/// (только для List и Set). Если равно null, значение берётся из
/// [LogTheme.collectionShowLength].
///
/// [collectionShowIndexes] - показывать ли индексы элементов в виде `₀:`,
/// `₁:` и т.д. Если равно null, значение берётся из
/// [LogTheme.collectionShowIndexes].
///
/// [units] - единицы измерения, будут добавлены к представлению объекта
/// в виде суффикса. Если равно null, единицы не добавляются.
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
///       collectionMaxLength: 2,
///     ),
///   ),
/// );
/// // data: [₌₃ ₀:1kg, …, ₂:[₌₃ ₀:3kg, …, ₂:5kg]]
/// ```
final class LoggableConfig with Loggable {
  final bool? enumDotShorthand;
  final int? collectionMaxLength;
  final int? collectionMaxStringLength;
  final bool? collectionShowLength;
  final bool? collectionShowIndexes;
  final String? units;
  final String? doubleFormat;
  final String? intFormat;

  const LoggableConfig({
    this.enumDotShorthand,
    this.collectionMaxLength,
    this.collectionMaxStringLength,
    this.collectionShowLength,
    this.collectionShowIndexes,
    this.units,
    this.doubleFormat,
    this.intFormat,
  });

  LoggableConfig merge(LoggableConfig other) => LoggableConfig(
        enumDotShorthand: enumDotShorthand ?? other.enumDotShorthand,
        collectionMaxLength: collectionMaxLength ?? other.collectionMaxLength,
        collectionMaxStringLength:
            collectionMaxStringLength ?? other.collectionMaxStringLength,
        collectionShowLength:
            collectionShowLength ?? other.collectionShowLength,
        collectionShowIndexes:
            collectionShowIndexes ?? other.collectionShowIndexes,
        units: units ?? other.units,
        doubleFormat: doubleFormat ?? other.doubleFormat,
        intFormat: intFormat ?? other.intFormat,
      );

  LoggableResolvedConfig resolved(LogTheme theme) => LoggableResolvedConfig(
        enumDotShorthand: enumDotShorthand ?? theme.enumDotShorthand,
        collectionMaxLength: collectionMaxLength,
        collectionMaxStringLength: collectionMaxStringLength,
        collectionShowLength:
            collectionShowLength ?? theme.collectionShowLength,
        collectionShowIndexes:
            collectionShowIndexes ?? theme.collectionShowIndexes,
        units: units,
        doubleFormat: doubleFormat,
        intFormat: intFormat,
      );

  @override
  void collectLoggableData(LoggableData data) {
    data
      ..prop('enumDotShorthand', enumDotShorthand)
      ..prop('collectionMaxLength', collectionMaxLength)
      ..prop('collectionMaxStringLength', collectionMaxStringLength)
      ..prop('collectionShowLength', collectionShowLength)
      ..prop('collectionShowIndexes', collectionShowIndexes)
      ..prop('units', units)
      ..prop('doubleFormat', doubleFormat)
      ..prop('intFormat', intFormat);
  }
}

final class LoggableResolvedConfig extends LoggableConfig with Loggable {
  const LoggableResolvedConfig({
    required bool super.enumDotShorthand,
    required super.collectionMaxLength,
    required super.collectionMaxStringLength,
    required bool super.collectionShowLength,
    required bool super.collectionShowIndexes,
    required super.units,
    required super.doubleFormat,
    required super.intFormat,
  });

  @override
  bool get enumDotShorthand => super.enumDotShorthand!;

  @override
  bool get collectionShowLength => super.collectionShowLength!;

  @override
  bool get collectionShowIndexes => super.collectionShowIndexes!;

  @override
  void collectLoggableData(LoggableData data) {
    data
      ..prop('enumDotShorthand', enumDotShorthand)
      ..prop('collectionMaxLength', collectionMaxLength)
      ..prop('collectionMaxStringLength', collectionMaxStringLength)
      ..prop('collectionShowLength', collectionShowLength)
      ..prop('collectionShowIndexes', collectionShowIndexes)
      ..prop('units', units)
      ..prop('doubleFormat', doubleFormat)
      ..prop('intFormat', intFormat);
  }
}
