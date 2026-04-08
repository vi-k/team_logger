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
    String Function(
      T value,
      int level,
      String Function(String)? convert,
      LogDataTheme theme,
    )? convert,
    int? collectionMaxCount,
    int? collectionMaxLength,
    bool? showCount,
    bool? showIndexes,
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
        collectionMaxCount: collectionMaxCount,
        collectionMaxLength: collectionMaxLength,
        showCount: showCount,
        showIndexes: showIndexes,
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
    LogDataTheme theme = LogDataTheme.noColorsTheme,
    int level = 0,
    String Function(String value)? valueFormat,
    int? collectionMaxCount,
    int? collectionMaxLength,
    bool? showCount,
    bool? showIndexes,
    String? units,
  }) {
    final brackets = theme.bracketStyle(level);
    final content = theme.punctuationStyle(level);

    String name2str() {
      final name = _type.view ?? _type.value.toString();
      return theme.name(valueFormat?.call(name) ?? name);
    }

    String prop2str(Prop<Object?> p) => p.toLogString(
          theme: theme,
          level: level,
          preformat: valueFormat,
          collectionMaxCount: collectionMaxCount,
          collectionMaxLength: collectionMaxLength,
          showCount: showCount,
          showIndexes: showIndexes,
          units: units,
        );

    return '${_type.showName ? name2str() : ''}'
        '${brackets(_type.openingBracket)}'
        '${props.map(prop2str).join(content(', '))}'
        '${brackets(_type.closingBracket)}';
  }

  @override
  String toString() => toLogString();
}

final class Prop<T extends Object?> {
  final String name;
  final T value;
  final String? view;
  final bool showName;
  final int? collectionMaxCount;
  final int? collectionMaxLength;
  final bool? showCount;
  final bool? showIndexes;
  final String? units;
  final String Function(
    T value,
    int level,
    String Function(String value)? preformat,
    LogDataTheme theme,
  )? convert;
  final int levelCorrection;

  const Prop(
    this.name,
    this.value, {
    this.showName = true,
    this.view,
    this.convert,
    this.collectionMaxCount,
    this.collectionMaxLength,
    this.showCount,
    this.showIndexes,
    this.units,
    this.levelCorrection = 0,
  });

  String toLogString({
    int level = 0,
    String Function(String value)? preformat,
    LogDataTheme theme = LogDataTheme.noColorsTheme,
    int? collectionMaxCount,
    int? collectionMaxLength,
    bool? showCount,
    bool? showIndexes,
    String? units,
  }) {
    final content = theme.punctuationStyle(level);

    String name2str() => theme.key(preformat?.call(name) ?? name);

    final valueStr = view ??
        convert?.call(value, level + 1, preformat, theme) ??
        Loggable.objectToString(
          value,
          level: level + 1 + levelCorrection,
          preformat: preformat,
          theme: theme,
          collectionMaxCount: this.collectionMaxCount ?? collectionMaxCount,
          collectionMaxLength: this.collectionMaxLength ?? collectionMaxLength,
          showCount: this.showCount ?? showCount,
          showIndexes: this.showIndexes ?? showIndexes,
          units: this.units ?? units,
        );

    return '${showName ? '${name2str()}${content(':')} ' : ''}$valueStr';
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
    String? openingBrackets,
    String? closingBrackets,
  })  : _openingBracket = openingBrackets ?? '(',
        _closingBracket = closingBrackets ?? ')',
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
      );
}

final class LoggableWrap<T extends Object?> extends LoggableData {
  LoggableWrap(
    T value, {
    String? name,
    bool showName = true,
    bool showBrackets = true,
    String? openingBrackets,
    String? closingBrackets,
  })  : assert(value is! Loggable),
        super._(
          TypeProp(
            value.runtimeType,
            name: name,
            showName: showName,
            showBrackets: showBrackets,
            openingBrackets: openingBrackets,
            closingBrackets: closingBrackets,
          ),
        );
}

final class LoggableMap<T extends Object?> extends LoggableData {
  LoggableMap()
      : super._(
          TypeProp(
            Map<String, T>,
            showName: false,
            openingBrackets: '{',
            closingBrackets: '}',
          ),
        );
}

final class LoggableObject<T extends Object?> extends LoggableData {
  LoggableObject(
    T obj, {
    int? collectionMaxCount,
    int? collectionMaxLength,
    bool? showCount,
    bool? showIndexes,
    String? units,
  }) : super._(TypeProp(T, showName: false, showBrackets: false)) {
    prop<T>(
      'obj',
      obj,
      showName: false,
      collectionMaxCount: collectionMaxCount,
      collectionMaxLength: collectionMaxLength,
      showCount: showCount,
      showIndexes: showIndexes,
      units: units,
      levelCorrection: -1,
    );
  }
}
