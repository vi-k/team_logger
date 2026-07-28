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

  /// Повторное имя заменяет предыдущее свойство: строковый и JSON-вывод
  /// ведут себя одинаково (в JSON-Map последний ключ побеждал и раньше).
  void _addProp(Prop<Object?> prop) {
    final existing = props.indexWhere((p) => p.name == prop.name);
    if (existing != -1) {
      props[existing] = prop;
    } else {
      props.add(prop);
    }
  }

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
    Object view = Prop.noView,
    LoggableConfig? config,
    bool? enumDotShorthand,
    int? collectionMaxCount,
    int? collectionMaxStringLength,
    bool? collectionShowCount,
    bool? collectionShowIndexes,
    String? units,
    String? doubleFormat,
    String? intFormat,
    bool? stringInQuotes,
  }) {
    assert(
      config == null ||
          (enumDotShorthand == null &&
              collectionMaxCount == null &&
              collectionMaxStringLength == null &&
              collectionShowCount == null &&
              collectionShowIndexes == null &&
              units == null &&
              doubleFormat == null &&
              intFormat == null &&
              stringInQuotes == null),
      'Use either `LoggableConfig` or individual parameters',
    );

    _addProp(
      Prop<T>._(
        name,
        value,
        showName: showName,
        hidden: hidden,
        view: view,
        config: config ??
            LoggableConfig(
              enumDotShorthand: enumDotShorthand,
              collectionMaxCount: collectionMaxCount,
              collectionMaxStringLength: collectionMaxStringLength,
              collectionShowCount: collectionShowCount,
              collectionShowIndexes: collectionShowIndexes,
              units: units,
              doubleFormat: doubleFormat,
              intFormat: intFormat,
              stringInQuotes: stringInQuotes,
            ),
      ),
    );
  }

  /// Добавляет свойство в зависимости от значения.
  ///
  /// Если значение равно `null`, то свойство невидимо (см. [hidden]).
  void whenNotNull<T extends Object?>(
    String name,
    T value, {
    bool showName = true,
    Object view = Prop.noView,
    LoggableConfig? config,
    bool? enumDotShorthand,
    int? collectionMaxCount,
    int? collectionMaxStringLength,
    bool? collectionShowCount,
    bool? collectionShowIndexes,
    String? units,
    String? doubleFormat,
    String? intFormat,
    bool? stringInQuotes,
  }) {
    prop<T>(
      name,
      value,
      showName: showName,
      hidden: value == null,
      view: view,
      config: config,
      enumDotShorthand: enumDotShorthand,
      collectionMaxCount: collectionMaxCount,
      collectionMaxStringLength: collectionMaxStringLength,
      collectionShowCount: collectionShowCount,
      collectionShowIndexes: collectionShowIndexes,
      units: units,
      doubleFormat: doubleFormat,
      intFormat: intFormat,
      stringInQuotes: stringInQuotes,
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
    Object view = Prop.noView,
    LoggableConfig? config,
    bool? enumDotShorthand,
    int? collectionMaxCount,
    int? collectionMaxStringLength,
    bool? collectionShowCount,
    bool? collectionShowIndexes,
    String? units,
    String? doubleFormat,
    String? intFormat,
    bool? stringInQuotes,
  }) {
    prop<T>(
      name,
      value,
      showName: showName,
      hidden: true,
      view: view,
      config: config,
      enumDotShorthand: enumDotShorthand,
      collectionMaxCount: collectionMaxCount,
      collectionMaxStringLength: collectionMaxStringLength,
      collectionShowCount: collectionShowCount,
      collectionShowIndexes: collectionShowIndexes,
      units: units,
      doubleFormat: doubleFormat,
      intFormat: intFormat,
      stringInQuotes: stringInQuotes,
    );
  }

  /// Добавляет вычисляемое свойство к описанию.
  ///
  /// Свойство может быть как не привязано к реальным данным, так и привязано
  /// к нескольким реальным свойствам. Соответственное, в графическом
  /// интерфейсе при показе реальных данных будет опущено.
  void computed(
    String name,
    Object view, {
    bool showName = true,
    LoggableConfig? config,
    bool? enumDotShorthand,
    int? collectionMaxCount,
    int? collectionMaxStringLength,
    bool? collectionShowCount,
    bool? collectionShowIndexes,
    String? units,
    String? doubleFormat,
    String? intFormat,
    bool? stringInQuotes,
  }) {
    prop(
      name,
      _computed,
      showName: showName,
      view: view,
      config: config,
      enumDotShorthand: enumDotShorthand,
      collectionMaxCount: collectionMaxCount,
      collectionMaxStringLength: collectionMaxStringLength,
      collectionShowCount: collectionShowCount,
      collectionShowIndexes: collectionShowIndexes,
      units: units,
      doubleFormat: doubleFormat,
      intFormat: intFormat,
      stringInQuotes: stringInQuotes,
    );
  }

  /// Добавляет свойство double к описанию, форматируя его с помощью
  /// [fractionDigits]: 1.000 with fractionDigits 2 = '1.00'.
  void fixed(
    String name,
    double value,
    int fractionDigits, {
    bool showName = true,
    String? units,
  }) {
    if (!value.isFinite) {
      return prop<double>(
        name,
        value,
        showName: showName,
        units: units,
      );
    }

    prop<double>(
      name,
      value,
      showName: showName,
      view: value.toStringAsFixed(fractionDigits),
      units: units,
    );
  }

  /// Добавляет свойство double к описанию, округляя его до [precision]:
  /// 1.000 with precision 2 = 1.
  void round(
    String name,
    double value, {
    int precision = 0,
    bool showName = true,
    String? units,
  }) {
    if (!value.isFinite) {
      return prop<double>(
        name,
        value,
        showName: showName,
        units: units,
      );
    }

    final scale = math.pow(10.0, precision);

    prop<double>(
      name,
      value,
      showName: showName,
      view: (value * scale).roundToDouble() / scale,
      units: units,
    );
  }

  Object? toJson({
    LoggableJsonConfig config = const LoggableJsonConfig(),
  }) {
    // Не передаём units дочерним элементам: units описывают объект целиком
    // и попадают в ":u" на его уровне.
    final propConfig = config.copyWith(units: null);

    MapEntry<String, Object?> prop2entry(Prop<Object?> p) =>
        p.toMapEntry(config: propConfig);

    Object? prop2json(Prop<Object?> p) {
      final entry = prop2entry(p);
      return p.showName ? {entry.key: entry.value} : entry.value;
    }

    final className = _type.typeName ?? _type.value.toString();
    final propsList = this.props.where((p) => !p.hidden).toList();
    final hasNonamed = propsList.any((p) => !p.showName);
    final props = hasNonamed
        ? propsList.map(prop2json).toList()
        : Map.fromEntries(propsList.map(prop2entry));

    return {
      if (_type.showName) Loggable._classKey: className,
      Loggable._propsKey: props,
      if (!_type.showBrackets) Loggable._bracketsKey: false,
      if (config.units case final units?) Loggable._unitsKey: units,
    };
  }

  String toLogString({
    LogTheme theme = LogTheme.noColors,
    int depth = 0,
    String Function(String value)? valueFormat,
    LoggableConfig config = const LoggableConfig(),
  }) {
    final depthTheme = theme.depthTheme(depth);

    String name2str() {
      final name = _type.typeName ?? _type.value.toString();
      return theme.data.nameStyle(valueFormat?.call(name) ?? name);
    }

    String prop2str(Prop<Object?> p) => p.toLogString(
          theme: theme,
          depth: depth,
          config: config,
        );

    final buf = StringBuffer();
    if (_type.showName) buf.write(name2str());
    if (_type.showBrackets) buf.write(depthTheme.brackets('('));
    buf.write(
      props
          .where((p) => !p.hidden)
          .map(prop2str)
          .join(depthTheme.punctuation(', ')),
    );
    if (_type.showBrackets) buf.write(depthTheme.brackets(')'));

    return buf.toString();
  }

  @override
  String toString() => toLogString();
}

final class LoggableNoView {
  const LoggableNoView._();

  @override
  String toString() => '<no view>';
}

final class Prop<T extends Object?> {
  static const noView = LoggableNoView._();

  final String name;
  final T value;
  final Object? view;
  final bool showName;
  final bool hidden;
  final LoggableConfig config;

  Prop._(
    this.name,
    this.value, {
    this.showName = true,
    this.hidden = false,
    this.view = noView,
    this.config = const LoggableConfig(),
  });

  MapEntry<String, Object?> toMapEntry({
    LoggableJsonConfig config = const LoggableJsonConfig(),
  }) {
    final effectiveConfig = this.config.mergeWithJsonConfig(config);

    // Как и в [toLogString]: units применяются к значению ровно один раз —
    // [Loggable.objectToJson] делает это сам, [LoggableView] сам управляет
    // своими units, и только «сырой» view оборачивается здесь.
    final propJson = switch (view) {
      LoggableNoView() => Loggable.objectToJson(value, config: effectiveConfig),
      final LoggableView view => view.toJson(value),
      bool() || num() => Loggable.objectToJson(view, config: effectiveConfig),
      final view => {
          Loggable._viewKey: view.toString(),
          if (effectiveConfig.units case final units?)
            Loggable._unitsKey: units,
        },
    };

    return MapEntry(showName ? name : '@$name', propJson);
  }

  String toLogString({
    LogTheme theme = LogTheme.noColors,
    int depth = 0,
    LoggableConfig config = const LoggableConfig(),
  }) {
    String name2str() => theme.data.keyStyle(theme.formatValue(name));

    final effectiveConfig = this.config.merge(config);
    final effectiveView = switch (view) {
      LoggableNoView() => null,
      final LoggableView view =>
        view.toLogString(value, theme: theme, depth: depth),
      final view =>
        '$view${Loggable.unitsToString(effectiveConfig.units, theme)}',
    };
    final styledValue = theme.formatValue(
      effectiveView ??
          Loggable.objectToString(
            value,
            theme: theme,
            depth: depth + 1,
            config: effectiveConfig,
          ),
    );
    final depthTheme = theme.depthTheme(depth);
    final prefix =
        showName ? '${name2str()}${depthTheme.punctuation(':')} ' : '';

    return '$prefix$styledValue';
  }

  @override
  String toString() => toLogString();
}

final class TypeProp extends Prop<Type> {
  final bool showBrackets;
  final String? typeName;

  TypeProp._(
    Type type, {
    String? name,
    super.showName = true,
    this.showBrackets = true,
  })  : typeName = name,
        super._('type', type);

  TypeProp copyWith({
    String? name,
    bool? showName,
    bool? showBrackets,
  }) =>
      TypeProp._(
        value,
        name: name ?? typeName,
        showName: showName ?? this.showName,
        showBrackets: showBrackets ?? this.showBrackets,
      );
}

final class _LoggableBuilder extends LoggableData {
  final LoggableConfig config;

  _LoggableBuilder(
    Object? obj, {
    required String? name,
    required bool showName,
    required bool showBrackets,
    this.config = const LoggableConfig(),
  }) : super._(
          TypeProp._(
            obj.runtimeType,
            name: name,
            showName: showName,
            showBrackets: showBrackets,
          ),
        );

  @override
  Object? toJson({
    LoggableJsonConfig config = const LoggableJsonConfig(),
  }) =>
      super.toJson(config: this.config.mergeWithJsonConfig(config));

  @override
  String toLogString({
    LogTheme theme = LogTheme.noColors,
    int depth = 0,
    String Function(String value)? valueFormat,
    LoggableConfig config = const LoggableConfig(),
  }) =>
      super.toLogString(
        theme: theme,
        depth: depth,
        valueFormat: valueFormat,
        config: this.config.merge(config),
      );
}

final class _LoggableMapBuilder extends LoggableData {
  final LoggableConfig config;

  _LoggableMapBuilder({this.config = const LoggableConfig()})
      : super._(TypeProp._(Map<String, Object?>, showName: false));

  @override
  Object? toJson({
    LoggableJsonConfig config = const LoggableJsonConfig(),
  }) {
    final effectiveConfig = this.config.mergeWithJsonConfig(config);

    // Не передаём units дочерним элементам: units описывают объект целиком
    // и попадают в ":u" на его уровне.
    final propConfig = effectiveConfig.copyWith(units: null);

    MapEntry<String, Object?> prop2entry(Prop<Object?> p) =>
        p.toMapEntry(config: propConfig);

    final propsList = this.props.where((p) => !p.hidden).toList();
    final props = Map.fromEntries(propsList.map(prop2entry));

    return {
      ...props,
      if (effectiveConfig.units case final units?) Loggable._unitsKey: units,
    };
  }

  @override
  String toLogString({
    LogTheme theme = LogTheme.noColors,
    int depth = 0,
    String Function(String value)? valueFormat,
    LoggableConfig config = const LoggableConfig(),
  }) {
    final effectiveConfig = this.config.merge(config);
    final depthTheme = theme.depthTheme(depth);

    String prop2str(Prop<Object?> p) => p.toLogString(
          theme: theme,
          depth: depth,
          config: effectiveConfig,
        );

    return '${depthTheme.brackets('{')}'
        '${props.where((p) => !p.hidden).map(prop2str).join(depthTheme.punctuation(', '))}'
        '${depthTheme.brackets('}')}';
  }
}

final class _ComputedProp {
  const _ComputedProp();

  @override
  String toString() => '<computed>';
}
