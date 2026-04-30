// ignore_for_file: prefer_const_constructors

part of 'loggable.dart';

final class LoggableData {
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

  void prop<T extends Object?>(
    String name,
    T value, {
    bool showName = true,
    String? view,
    String Function(T value, int level, LogLevelTheme theme)? convert,
    bool? enumDotShorthand,
    int? collectionMaxLength,
    int? collectionMaxStringLength,
    bool? collectionShowLength,
    bool? collectionShowIndexes,
    String? units,
    int levelCorrection = 0,
  }) {
    assert(!props.any((e) => e.name == name));

    props.add(
      Prop<T>(
        name,
        value,
        showName: showName,
        view: view,
        convert: convert,
        enumDotShorthand: enumDotShorthand,
        collectionMaxLength: collectionMaxLength,
        collectionMaxStringLength: collectionMaxStringLength,
        collectionShowLength: collectionShowLength,
        collectionShowIndexes: collectionShowIndexes,
        units: units,
        levelCorrection: levelCorrection,
      ),
    );
  }

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
    int level = 0,
    String Function(String value)? valueFormat,
    bool? enumDotShorthand,
    int? collectionMaxLength,
    int? collectionMaxStringLength,
    bool? collectionShowLength,
    bool? collectionShowIndexes,
    String? units,
  }) {
    final levelTheme = theme.dataLevelTheme(level);

    String name2str() {
      final name = _type.view ?? _type.value.toString();
      return theme.dataNameStyle(valueFormat?.call(name) ?? name);
    }

    String prop2str(Prop<Object?> p) => p.toLogString(
          theme: theme,
          level: level,
          enumDotShorthand: enumDotShorthand,
          collectionMaxLength: collectionMaxLength,
          collectionMaxStringLength: collectionMaxStringLength,
          collectionShowLength: collectionShowLength,
          collectionShowIndexes: collectionShowIndexes,
          units: units,
        );

    return '${_type.showName ? name2str() : ''}'
        '${levelTheme.brackets(_type.openingBracket)}'
        '${props.map(prop2str).join(levelTheme.punctuation(', '))}'
        '${levelTheme.brackets(_type.closingBracket)}';
  }

  @override
  String toString() => toLogString();
}

final class Prop<T extends Object?> {
  final String name;
  final T value;
  final String? view;
  final bool showName;
  final bool? enumDotShorthand;
  final int? collectionMaxLength;
  final int? collectionMaxStringLength;
  final bool? collectionShowLength;
  final bool? collectionShowIndexes;
  final String? units;
  final String Function(T value, int level, LogLevelTheme theme)? convert;
  final int levelCorrection;

  const Prop(
    this.name,
    this.value, {
    this.showName = true,
    this.view,
    this.convert,
    this.enumDotShorthand,
    this.collectionMaxLength,
    this.collectionMaxStringLength,
    this.collectionShowLength,
    this.collectionShowIndexes,
    this.units,
    this.levelCorrection = 0,
  });

  String toLogString({
    int level = 0,
    LogLevelTheme theme = LogLevelTheme.noColors,
    bool? enumDotShorthand,
    int? collectionMaxLength,
    int? collectionMaxStringLength,
    bool? collectionShowLength,
    bool? collectionShowIndexes,
    String? units,
  }) {
    String name2str() => theme.dataKeyStyle(theme.formatValue(name));

    final valueStr = view ??
        convert?.call(value, level + 1, theme) ??
        Loggable.objectToString(
          value,
          level: level + 1 + levelCorrection,
          theme: theme,
          enumDotShorthand: this.enumDotShorthand ?? enumDotShorthand,
          collectionMaxLength: this.collectionMaxLength ?? collectionMaxLength,
          collectionMaxStringLength:
              this.collectionMaxStringLength ?? collectionMaxStringLength,
          collectionShowLength:
              this.collectionShowLength ?? collectionShowLength,
          collectionShowIndexes:
              this.collectionShowIndexes ?? collectionShowIndexes,
          units: this.units ?? units,
        );
    final styledValueStr = theme.formatValue(valueStr);

    final levelTheme = theme.dataLevelTheme(level);
    final prefix =
        showName ? '${name2str()}${levelTheme.punctuation(':')} ' : '';

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
        super('type', type, view: name);

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
