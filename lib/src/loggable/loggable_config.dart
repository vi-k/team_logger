import 'package:meta/meta.dart';

import '../theme/log_main_theme.dart';
import 'loggable.dart';
import 'loggable_json_config.dart';

/// Конфигурация для [objectToString].
///
/// [enumDotShorthand] - сокращенное представление enums в виде `.value`.
/// Если равно null, решают слои цепочки (см. ниже); по умолчанию `true`.
///
/// [collectionMaxCount] - максимальное количество элементов в коллекции
/// (для [List], [Set], [Map] и [Iterable]). Если равно null, нет
/// ограничений. У [Map] лимит считает выжившие записи: выброшенная
/// правилом запись слот не занимает.
///
/// [collectionMaxStringLength] - максимальная длина результирующей строки
/// после преобразования коллекции. В реальности строка может быть больше,
/// т.к. итерируемые объекты обязательно должны содержать первый элемент,
/// а списки первый и последний элемент без сокращений. Если равно null,
/// ограничений.
///
/// [collectionShowCount] - показывать ли длину коллекции в виде `₌₄`
/// (для [List], [Set] и [Map]). Если равно null, решают слои цепочки;
/// по умолчанию `true`. У [Map] это длина исходной коллекции — записи,
/// выброшенные правилом, в выводе не видны, и счётчик остаётся
/// единственным их следом.
///
/// [collectionShowIndexes] - показывать ли индексы элементов в виде `₀:`,
/// `₁:` и т.д. Если равно null, решают слои цепочки; по умолчанию `true`.
///
/// [iterableEfficientLength] - утверждение вызывающего, что у голого
/// [Iterable] длина и последний элемент дёшевы. Без него коллекция, которая
/// не [List] и не [Set], обходится ровно один раз: печатаются первые
/// элементы и многоточие, а длина не читается вовсе — иначе однопроходный
/// или дорогой итератор пострадал бы. С ним вывод становится таким же
/// богатым, как у [List]: количество (`₌₅`) и последний элемент. По
/// умолчанию выключено; на генераторе включать нельзя.
///
/// [escapeAnsiCodes] - безопасный вывод: управляющая последовательность в
/// тексте показывается (`[CSI 2 ED]forged`), а не отправляется в терминал.
/// Включено по умолчанию. Выключать стоит там, где значение стилизовано
/// осознанно; для недоверенного ввода — наоборот, включать через
/// [Loggable.forceConfig], чтобы место вызова не могло снять.
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
/// ## Слои
///
/// Незаданное (`null`) поле разрешается цепочкой, от слабого к сильному:
///
/// 1. дефолт пакета — то, что печатается, если не сказано ничего;
/// 2. [Loggable.defaultConfig] — дефолт приложения;
/// 3. этот конфиг: с места вызова и от контейнеров по пути к значению
///    (ближний к значению сильнее);
/// 4. [Loggable.forceConfig] — политика приложения, которую нельзя снять
///    ни с места вызова, ни вложенным контейнером.
///
/// Раньше слои 1 и 2 отсутствовали, а дефолты четырёх булевых настроек
/// брались из темы. Тема отвечает за то, как вывод выглядит; конфиг — за
/// то, что в нём печатается.
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
  final bool? escapeAnsiCodes;
  final bool? iterableEfficientLength;

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
    this.escapeAnsiCodes,
    this.iterableEfficientLength,
  });

  /// Дефолты пакета — нижний пол цепочки, ниже [Loggable.defaultConfig].
  ///
  /// Раньше их держала тема (`LogMainTheme.stringInQuotes` и соседние), и
  /// разрешение «конфиг, иначе тема» было размазано по пяти местам
  /// рендеринга. Теперь тема отвечает за то, как вывод выглядит, а конфиг —
  /// за то, что в нём печатается.
  static const bool defaultEnumDotShorthand = true;
  static const bool defaultCollectionShowCount = true;
  static const bool defaultCollectionShowIndexes = true;
  static const bool defaultStringInQuotes = true;

  /// Безопасный вывод включён по умолчанию: недоверенный текст попадает в
  /// логи не по злому умыслу, а потому что так устроены логи.
  static const bool defaultEscapeAnsiCodes = true;

  /// Голый [Iterable] по умолчанию обходится один раз: он может быть
  /// однопроходным или дорогим, и читать его длину пакет не вправе.
  static const bool defaultIterableEfficientLength = false;

  /// Значение [escapeAnsiCodes] там, где локального конфига нет вовсе.
  ///
  /// Сообщение лога, текст ошибки и `units` конфига не имеют: `config:` с
  /// места вызова оборачивает только `data`. Для них цепочка состоит из
  /// слоёв приложения, и это правильный набор — сообщение ровно то место,
  /// где нужна политика, а не вкус вызывающего.
  @internal
  static bool get appEscapeAnsiCodes =>
      const LoggableConfig().resolvedEscapeAnsiCodes;

  /// Значения с наложенной цепочкой `default ← этот конфиг ← force`.
  ///
  /// Спрашиваются в точке использования, а не собираются заранее: конфиг
  /// контейнера подмешивается уже во время обхода, и слой, свёрнутый до
  /// него, вложенный контейнер перебил бы. Здесь перебить нечего — порядок
  /// задан прямо в выражении.
  @internal
  bool get resolvedEnumDotShorthand =>
      Loggable.forceConfig.enumDotShorthand ??
      enumDotShorthand ??
      Loggable.defaultConfig.enumDotShorthand ??
      defaultEnumDotShorthand;

  @internal
  bool get resolvedCollectionShowCount =>
      Loggable.forceConfig.collectionShowCount ??
      collectionShowCount ??
      Loggable.defaultConfig.collectionShowCount ??
      defaultCollectionShowCount;

  @internal
  bool get resolvedCollectionShowIndexes =>
      Loggable.forceConfig.collectionShowIndexes ??
      collectionShowIndexes ??
      Loggable.defaultConfig.collectionShowIndexes ??
      defaultCollectionShowIndexes;

  @internal
  bool get resolvedStringInQuotes =>
      Loggable.forceConfig.stringInQuotes ??
      stringInQuotes ??
      Loggable.defaultConfig.stringInQuotes ??
      defaultStringInQuotes;

  @internal
  bool get resolvedIterableEfficientLength =>
      Loggable.forceConfig.iterableEfficientLength ??
      iterableEfficientLength ??
      Loggable.defaultConfig.iterableEfficientLength ??
      defaultIterableEfficientLength;

  @internal
  bool get resolvedEscapeAnsiCodes =>
      Loggable.forceConfig.escapeAnsiCodes ??
      escapeAnsiCodes ??
      Loggable.defaultConfig.escapeAnsiCodes ??
      defaultEscapeAnsiCodes;

  @internal
  int? get resolvedCollectionMaxCount =>
      Loggable.forceConfig.collectionMaxCount ??
      collectionMaxCount ??
      Loggable.defaultConfig.collectionMaxCount;

  @internal
  int? get resolvedCollectionMaxStringLength =>
      Loggable.forceConfig.collectionMaxStringLength ??
      collectionMaxStringLength ??
      Loggable.defaultConfig.collectionMaxStringLength;

  /// `units` разрешаются цепочкой, но снимаются `withoutUnits()` на пути
  /// корневой sanitizer-замены — там `units` уже вычеркнуты из самого
  /// конфига, и force их не возвращает.
  @internal
  String? get resolvedUnits =>
      Loggable.forceConfig.units ?? units ?? Loggable.defaultConfig.units;

  @internal
  String? get resolvedIntFormat =>
      Loggable.forceConfig.intFormat ??
      intFormat ??
      Loggable.defaultConfig.intFormat;

  @internal
  String? get resolvedDoubleFormat =>
      Loggable.forceConfig.doubleFormat ??
      doubleFormat ??
      Loggable.defaultConfig.doubleFormat;

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
        escapeAnsiCodes: escapeAnsiCodes ?? other.escapeAnsiCodes,
        iterableEfficientLength:
            iterableEfficientLength ?? other.iterableEfficientLength,
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
        escapeAnsiCodes: escapeAnsiCodes,
        iterableEfficientLength: iterableEfficientLength,
      );

  /// Конфиг со всеми слоями цепочки, разрешёнными до конца.
  LoggableEffectiveConfig toEffectiveConfig() => LoggableEffectiveConfig(
        enumDotShorthand: resolvedEnumDotShorthand,
        collectionMaxCount: resolvedCollectionMaxCount,
        collectionMaxStringLength: resolvedCollectionMaxStringLength,
        collectionShowCount: resolvedCollectionShowCount,
        collectionShowIndexes: resolvedCollectionShowIndexes,
        units: resolvedUnits,
        doubleFormat: resolvedDoubleFormat,
        intFormat: resolvedIntFormat,
        stringInQuotes: resolvedStringInQuotes,
        escapeAnsiCodes: resolvedEscapeAnsiCodes,
        iterableEfficientLength: resolvedIterableEfficientLength,
      );

  LoggableJsonConfig mergeWithJsonConfig(LoggableJsonConfig config) =>
      LoggableJsonConfig(
        collectionMaxCount: collectionMaxCount ?? config.collectionMaxCount,
        units: units ?? config.units,
        iterableEfficientLength:
            iterableEfficientLength ?? config.iterableEfficientLength,
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
      ..prop('stringInQuotes', stringInQuotes)
      ..prop('escapeAnsiCodes', escapeAnsiCodes)
      ..prop('iterableEfficientLength', iterableEfficientLength);
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
    required bool super.escapeAnsiCodes,
    required bool super.iterableEfficientLength,
  });

  @override
  bool get enumDotShorthand => super.enumDotShorthand!;

  @override
  bool get collectionShowCount => super.collectionShowCount!;

  @override
  bool get collectionShowIndexes => super.collectionShowIndexes!;

  @override
  bool get stringInQuotes => super.stringInQuotes!;

  @override
  bool get escapeAnsiCodes => super.escapeAnsiCodes!;

  @override
  bool get iterableEfficientLength => super.iterableEfficientLength!;
}
