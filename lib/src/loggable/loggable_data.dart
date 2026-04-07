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
  ClassProp _type;
  ClassProp get type => _type;

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

  void prop<T extends Object?>(
    String name,
    T value, {
    bool showName = true,
    String? view,
    String Function(
      T value,
      int level,
      String Function(String)? conver,
      LogDataTheme theme,
    )? convert,
    String? units,
  }) {
    assert(!props.any((e) => e.name == name));

    props.add(
      Prop<T>(
        name,
        value,
        showName: showName,
        view: view,
        convert: convert,
        units: units,
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

  void list<T extends Object?>(
    String name,
    List<T> list, {
    bool showName = true,
    int? maxCount,
    int? maxSize,
    bool showCount = true,
    String? units,
  }) {
    prop<List<T>>(
      name,
      list,
      showName: showName,
      convert: (value, level, preformat, theme) => Loggable.listToString(
        value,
        level: level,
        preformat: preformat,
        theme: theme,
        maxCount: maxCount,
        maxLength: maxSize,
        showIndexes: showCount,
        units: units,
      ),
      units: units,
    );
  }

  void set<T extends Object?>(
    String name,
    Set<T> set, {
    bool showName = true,
    int? maxCount,
    int? maxSize,
    bool showCount = true,
    String? units,
  }) {
    prop<Set<T>>(
      name,
      set,
      showName: showName,
      convert: (value, level, preformat, theme) => Loggable.setToString(
        value,
        level: level,
        preformat: preformat,
        theme: theme,
        maxCount: maxCount,
        maxLength: maxSize,
        showIndexes: showCount,
        units: units,
      ),
      units: units,
    );
  }

  void iterable<T extends Object?>(
    String name,
    Iterable<T> iterable, {
    bool showName = true,
    int? maxCount,
    int? maxSize,
    bool showCountIfPossible = true,
    String? units,
  }) {
    prop<Iterable<T>>(
      name,
      iterable,
      showName: showName,
      convert: (value, level, preformat, theme) => Loggable.iterableToString(
        value,
        level: level,
        preformat: preformat,
        theme: theme,
        maxCount: maxCount,
        maxLength: maxSize,
        showIndexes: showCountIfPossible,
        units: units,
      ),
      units: units,
    );
  }

  void efficientLengthIterable<T extends Object?>(
    String name,
    Iterable<T> iterable, {
    bool showName = true,
    String start = '(',
    String end = ')',
    int? length,
    int? maxCount,
    int? maxSize,
    bool showCount = true,
    String? units,
  }) {
    prop<Iterable<T>>(
      name,
      iterable,
      showName: showName,
      convert: (value, level, preformat, theme) =>
          Loggable.efficientLengthIterableToString(
        value,
        level: level,
        preformat: preformat,
        theme: theme,
        maxCount: maxCount,
        maxLength: maxSize,
        showIndexes: showCount,
        units: units,
      ),
      units: units,
    );
  }

  String toLogString({
    LogDataTheme theme = LogDataTheme.noColorsTheme,
    int level = 0,
    String Function(String value)? valueFormat,
  }) {
    final level2str = theme.level(level).call;

    String name2str() {
      final name = _type.view ?? _type.value.toString();
      return theme.name(valueFormat?.call(name) ?? name);
    }

    String prop2str(Prop<Object?> p) => p.toLogString(
          theme: theme,
          level: level,
          preformat: valueFormat,
        );

    return '${_type.showName ? name2str() : ''}'
        '${_type.showParentheses ? level2str(_type.openingParenthesis) : ''}'
        '${props.map(prop2str).join(', ')}'
        '${_type.showParentheses ? level2str(_type.closingParenthesis) : ''}';
  }

  @override
  String toString() => toLogString();
}

final class Prop<T extends Object?> {
  final String name;
  final T value;
  final String? view;
  final bool showName;
  final String units;
  final String Function(
    T value,
    int level,
    String Function(String value)? preformat,
    LogDataTheme theme,
  )? convert;

  const Prop(
    this.name,
    this.value, {
    this.showName = true,
    this.view,
    this.convert,
    String? units,
  }) : units = units ?? '';

  String toLogString({
    int level = 0,
    String Function(String value)? preformat,
    LogDataTheme theme = LogDataTheme.noColorsTheme,
  }) {
    String name2str() => theme.key(preformat?.call(name) ?? name);

    final valueStr = view ??
        convert?.call(value, level + 1, preformat, theme) ??
        Loggable.objectToString(
          value,
          level: level + 1,
          preformat: preformat,
          theme: theme,
        );

    return '${showName ? '${name2str()}: ' : ''}$valueStr'
        '${Loggable.units2str(units, preformat, theme)}';
  }

  @override
  String toString() => toLogString();
}

final class ClassProp extends Prop<Type> {
  final bool showParentheses;
  final String openingParenthesis;
  final String closingParenthesis;

  const ClassProp(
    Type type, {
    String? name,
    super.showName = true,
    this.showParentheses = true,
    String? openingParenthesis,
    String? closingParenthesis,
  })  : assert(!showName || showParentheses),
        openingParenthesis = showParentheses ? (openingParenthesis ?? '(') : '',
        closingParenthesis = showParentheses ? (closingParenthesis ?? ')') : '',
        super('class', type, view: name);

  ClassProp copyWith({
    String? name,
    bool? showName,
  }) =>
      ClassProp(
        value,
        name: name ?? this.name,
        showName: showName ?? this.showName,
        openingParenthesis: openingParenthesis,
        closingParenthesis: closingParenthesis,
      );
}

final class LoggableWrap<T extends Object?> extends LoggableData {
  LoggableWrap(
    T value, {
    String? name,
    bool showName = true,
    bool showParentheses = true,
    String? openingParenthesis,
    String? closingParenthesis,
  })  : assert(value is! Loggable),
        super._(
          ClassProp(
            value.runtimeType,
            name: name,
            showName: showName,
            showParentheses: showParentheses,
            openingParenthesis: openingParenthesis,
            closingParenthesis: closingParenthesis,
          ),
        );
}

final class LoggableMap<T extends Object?> extends LoggableData {
  LoggableMap()
      : super._(
          ClassProp(
            Map<String, T>,
            showName: false,
            openingParenthesis: '{',
            closingParenthesis: '}',
          ),
        );
}

final class LoggableList<T extends Object?> extends LoggableData {
  final String? units;

  LoggableList(
    List<T> list, {
    int? maxCount,
    int? maxSize,
    bool showCount = true,
    this.units,
  }) : super._(
          ClassProp(
            List<T>,
            showName: false,
            showParentheses: false,
          ),
        ) {
    this.list<T>(
      'list',
      list,
      showName: false,
      maxCount: maxCount,
      maxSize: maxSize,
      showCount: showCount,
      units: units,
    );
  }
}

final class LoggableSet<T extends Object?> extends LoggableData {
  final String? units;

  LoggableSet(
    Set<T> set, {
    int? maxCount,
    int? maxSize,
    bool showCount = true,
    this.units,
  }) : super._(
          ClassProp(
            Set<T>,
            showName: false,
            showParentheses: false,
          ),
        ) {
    this.set<T>(
      'set',
      set,
      showName: false,
      maxCount: maxCount,
      maxSize: maxSize,
      showCount: showCount,
      units: units,
    );
  }
}
