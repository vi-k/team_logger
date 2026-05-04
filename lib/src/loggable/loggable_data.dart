// ignore_for_file: prefer_const_constructors

part of 'loggable.dart';

final class LoggableData {
  static const _computed = _ComputedProp();

  /// Тип класса.
  ///
  /// Не используем [runtimeType], т.к.:
  ///
  /// > Calling `toString` on a runtime type is a non-trivial operation that
  /// > can negatively impact performance. It's better to avoid it
  /// > (https://dart.dev/tools/linter-rules/no_runtimeType_toString)
  TypeProp _type;
  TypeProp get type => _type;

  /// Список параметров с их значениями.
  ///
  /// Если значение само является наследником [Loggable], то и оно будет
  /// соответствующим образом преобразовано в строку или отформатировано для
  /// отображения в UI.
  final List<Prop<Object?>> props = [];

  LoggableData._(this._type);

  String get name => _type.name;
  set name(String value) {
    _type = _type.copyWith(name: value);
  }

  bool get showName => _type.showName;
  set showName(bool value) {
    _type = _type.copyWith(showName: value);
  }

  bool get showBrackets => _type.showBrackets;
  set showBrackets(bool value) {
    _type = _type.copyWith(showBrackets: value);
  }

  /// Добавляет свойство к описанию.
  void prop<T extends Object?>(
    String name,
    T value, {
    bool showName = true,
    bool hidden = false,
    String? view,
    String Function(T value, int dataLevel, LogLevelTheme theme)? convert,
    LoggableConfig? config,
    bool? enumDotShorthand,
    int? collectionMaxLength,
    int? collectionMaxStringLength,
    bool? collectionShowLength,
    bool? collectionShowIndexes,
    String? units,
    String? doubleFormat,
    String? intFormat,
    int dataLevelCorrection = 0,
  }) {
    assert(
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
    );

    props.add(
      Prop<T>._(
        name,
        value,
        showName: showName,
        hidden: hidden,
        view: view,
        convert: convert,
        config: config ??
            LoggableConfig(
              enumDotShorthand: enumDotShorthand,
              collectionMaxLength: collectionMaxLength,
              collectionMaxStringLength: collectionMaxStringLength,
              collectionShowLength: collectionShowLength,
              collectionShowIndexes: collectionShowIndexes,
              units: units,
              doubleFormat: doubleFormat,
              intFormat: intFormat,
            ),
        dataLevelCorrection: dataLevelCorrection,
      ),
    );
  }

  /// Добавляет невидимое свойство к описанию.
  ///
  /// Свойства не выводится через [Loggable.objectToString], но может быть
  /// показано в графическом интерфейсе.
  void hidden<T extends Object?>(
    String name,
    T value, {
    bool showName = true,
    String? view,
    String Function(T value, int dataLevel, LogLevelTheme theme)? convert,
    LoggableConfig? config,
    bool? enumDotShorthand,
    int? collectionMaxLength,
    int? collectionMaxStringLength,
    bool? collectionShowLength,
    bool? collectionShowIndexes,
    String? units,
    String? doubleFormat,
    String? intFormat,
    int dataLevelCorrection = 0,
  }) {
    prop<T>(
      name,
      value,
      showName: showName,
      hidden: true,
      view: view,
      convert: convert,
      config: config,
      enumDotShorthand: enumDotShorthand,
      collectionMaxLength: collectionMaxLength,
      collectionMaxStringLength: collectionMaxStringLength,
      collectionShowLength: collectionShowLength,
      collectionShowIndexes: collectionShowIndexes,
      units: units,
      doubleFormat: doubleFormat,
      intFormat: intFormat,
      dataLevelCorrection: dataLevelCorrection,
    );
  }

  /// Добавляет вычисляемое свойство к описанию.
  ///
  /// Свойство может быть как не привязано к реальным данным, так и привязано
  /// к нескольким реальным свойствам. Соответственное, в графическом
  /// интерфейсе при показе реальных данных будет опущено.
  void computed(
    String name,
    String? view, {
    bool showName = true,
    String Function(int dataLevel, LogLevelTheme theme)? convert,
    LoggableConfig? config,
    bool? enumDotShorthand,
    int? collectionMaxLength,
    int? collectionMaxStringLength,
    bool? collectionShowLength,
    bool? collectionShowIndexes,
    String? units,
    String? doubleFormat,
    String? intFormat,
    int dataLevelCorrection = 0,
  }) {
    prop(
      name,
      _computed,
      showName: showName,
      hidden: true,
      view: view,
      convert:
          convert == null ? null : (_, level, theme) => convert(level, theme),
      config: config,
      enumDotShorthand: enumDotShorthand,
      collectionMaxLength: collectionMaxLength,
      collectionMaxStringLength: collectionMaxStringLength,
      collectionShowLength: collectionShowLength,
      collectionShowIndexes: collectionShowIndexes,
      units: units,
      doubleFormat: doubleFormat,
      intFormat: intFormat,
      dataLevelCorrection: dataLevelCorrection,
    );
  }

  /// Добавляет свойство double к описанию, форматируя его с помощью
  /// [fractionDigits].
  void fixed(
    String name,
    double value,
    int fractionDigits, {
    bool showName = true,
    String? units,
  }) {
    prop<double>(
      name,
      value,
      showName: showName,
      view: value.toStringAsFixed(fractionDigits),
      units: units,
    );
  }

  String toLogString({
    LogLevelTheme theme = LogLevelTheme.noColors,
    int dataLevel = 0,
    String Function(String value)? valueFormat,
    LoggableConfig config = const LoggableConfig(),
  }) {
    final dataTheme = theme.dataLevelTheme(dataLevel);

    String name2str() {
      final name = _type.view ?? _type.value.toString();
      return theme.dataNameStyle(valueFormat?.call(name) ?? name);
    }

    String prop2str(Prop<Object?> p) => p.toLogString(
          theme: theme,
          dataLevel: dataLevel,
          config: config,
        );

    return '${_type.showName ? name2str() : ''}'
        '${dataTheme.brackets(_type.openingBracket)}'
        '${props.where((p) => !p.hidden).map(prop2str).join(dataTheme.punctuation(', '))}'
        '${dataTheme.brackets(_type.closingBracket)}';
  }

  @override
  String toString() => toLogString();
}

final class Prop<T extends Object?> {
  final String name;
  final T value;
  final String? view;
  final bool showName;
  final bool hidden;
  final LoggableConfig config;
  final String Function(T value, int dataLevel, LogLevelTheme theme)? convert;
  final int dataLevelCorrection;

  const Prop._(
    this.name,
    this.value, {
    this.showName = true,
    this.hidden = false,
    this.view,
    this.convert,
    this.config = const LoggableConfig(),
    this.dataLevelCorrection = 0,
  });

  String toLogString({
    int dataLevel = 0,
    LogLevelTheme theme = LogLevelTheme.noColors,
    LoggableConfig config = const LoggableConfig(),
  }) {
    String name2str() => theme.dataKeyStyle(theme.formatValue(name));

    final valueStr = view ??
        convert?.call(value, dataLevel + 1, theme) ??
        Loggable.objectToString(
          value,
          dataLevel: dataLevel + 1 + dataLevelCorrection,
          theme: theme,
          config: this.config.merge(config),
        );
    final styledValueStr = theme.formatValue(valueStr);

    final dataTheme = theme.dataLevelTheme(dataLevel);
    final prefix =
        showName ? '${name2str()}${dataTheme.punctuation(':')} ' : '';

    return '$prefix$styledValueStr';
  }

  @override
  String toString() => toLogString();
}

final class TypeProp extends Prop<Type> {
  final bool showBrackets;
  final String _openingBracket;
  final String _closingBracket;

  const TypeProp(
    Type type, {
    String? name,
    super.showName = true,
    this.showBrackets = true,
    String? openingBracket,
    String? closingBracket,
  })  : _openingBracket = openingBracket ?? '(',
        _closingBracket = closingBracket ?? ')',
        super._('type', type, view: name);

  String get openingBracket => showBrackets ? _openingBracket : '';

  String get closingBracket => showBrackets ? _closingBracket : '';

  TypeProp copyWith({
    String? name,
    bool? showName,
    bool? showBrackets,
  }) =>
      TypeProp(
        value,
        name: name ?? view,
        showName: showName ?? this.showName,
        showBrackets: showBrackets ?? this.showBrackets,
        openingBracket: openingBracket,
        closingBracket: closingBracket,
      );
}

final class _LoggableBuilder extends LoggableData {
  _LoggableBuilder(
    Object? obj, {
    required String? name,
    required bool showName,
    required bool showBrackets,
    required String? openingBracket,
    required String? closingBracket,
  }) : super._(
          TypeProp(
            obj.runtimeType,
            name: name,
            showName: showName,
            showBrackets: showBrackets,
            openingBracket: openingBracket,
            closingBracket: closingBracket,
          ),
        );
}

final class _LoggableMapBuilder extends LoggableData {
  _LoggableMapBuilder()
      : super._(
          TypeProp(
            Map<String, Object?>,
            showName: false,
            openingBracket: '{',
            closingBracket: '}',
          ),
        );
}

final class _ComputedProp {
  const _ComputedProp();

  @override
  String toString() => '<computed>';
}
