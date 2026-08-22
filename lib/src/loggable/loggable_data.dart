// ignore_for_file: prefer_const_constructors

part of 'loggable.dart';

final class LoggableData {
  static const _computed = _ComputedProp();

  /// Собственный config контейнера или `null`, если своего у него нет.
  ///
  /// Нужен корневой sanitizer-замене: она встаёт на место контейнера и
  /// печатается его настройками (см. `Loggable._containerConfig`). Сам
  /// [LoggableData] своего config не имеет — его задают билдеры.
  LoggableConfig? get _ownConfig => null;

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

    final className = _type.typeName ?? _type.value.toString();
    final propsList = this.props.where((p) => !p.hidden).toList();

    final Object props;
    if (!Loggable._sanitizing) {
      // Прежний путь: без правила выбрасывать нечего, промежуточный
      // список пар не нужен.
      MapEntry<String, Object?> entryOf(Prop<Object?> p) =>
          p.toMapEntry(config: propConfig);

      Object? jsonOf(Prop<Object?> p) {
        final entry = entryOf(p);
        return p.showName ? {entry.key: entry.value} : entry.value;
      }

      props = propsList.any((p) => !p.showName)
          ? propsList.map(jsonOf).toList()
          : Map.fromEntries(propsList.map(entryOf));
    } else {
      // Санитайз каждого свойства ровно один раз: drop исключает его из
      // props целиком (запись отсутствует / элемент списка пропущен).
      final kept = <(Prop<Object?>, Object?)>[];
      for (final p in propsList) {
        final sanitized = p._sanitized();
        if (!Loggable._isDropped(sanitized)) kept.add((p, sanitized));
      }

      MapEntry<String, Object?> entryOf((Prop<Object?>, Object?) e) =>
          e.$1.toMapEntry(config: propConfig, sanitized: e.$2);

      Object? jsonOf((Prop<Object?>, Object?) e) {
        final entry = entryOf(e);
        return e.$1.showName ? {entry.key: entry.value} : entry.value;
      }

      // Форму (список или Map) определяют уцелевшие свойства: если
      // единственное безымянное свойство выброшено, списочная форма
      // больше не нужна.
      props = kept.any((e) => !e.$1.showName)
          ? kept.map(jsonOf).toList()
          : Map.fromEntries(kept.map(entryOf));
    }

    return {
      if (_type.showName) Loggable._classKey: className,
      Loggable._propsKey: props,
      if (!_type.showBrackets) Loggable._bracketsKey: false,
      if (config.units case final units?) Loggable._unitsKey: units,
    };
  }

  /// Рендер БЕЗ корневого предложения: обходчик, дойдя сюда, уже
  /// предложил этот узел правилу. Корень предлагает [toString] — прямой
  /// пользовательский путь, мимо обходчиков.
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

    // Санитайз каждого свойства ровно один раз; drop убирает свойство из
    // вывода целиком (без повисшего разделителя).
    String? prop2str(Prop<Object?> p) {
      final sanitized = p._sanitized();
      if (Loggable._isDropped(sanitized)) return null;

      return p.toLogString(
        theme: theme,
        depth: depth,
        config: config,
        sanitized: sanitized,
      );
    }

    final buf = StringBuffer();
    if (_type.showName) buf.write(name2str());
    if (_type.showBrackets) buf.write(depthTheme.brackets('('));
    buf.write(
      props
          .where((p) => !p.hidden)
          .map(prop2str)
          .whereType<String>()
          .join(depthTheme.punctuation(', ')),
    );
    if (_type.showBrackets) buf.write(depthTheme.brackets(')'));

    return buf.toString();
  }

  /// Как и у [Loggable.toString]: прямой пользовательский путь
  /// (интерполяция, `print`, отладчик) обязан предложить правилу корень
  /// — свойства на нём санитайзятся и так.
  @override
  String toString() => Loggable._rootToString(this, toLogString);
}

final class LoggableNoView {
  const LoggableNoView._();

  @override
  String toString() => '<no view>';
}

final class _NotSanitized {
  const _NotSanitized();

  @override
  String toString() => '<not sanitized>';
}

final class Prop<T extends Object?> {
  static const noView = LoggableNoView._();

  /// Сентинел «санитайз ещё не считали» для параметра `sanitized` в
  /// [toLogString]/[toMapEntry]. Отличаем «вызывающий не передал результат»
  /// от «санитайзер заменил значение на null» — `null` сам по себе валидная
  /// замена и не должен читаться как «не считали».
  ///
  /// Собственный приватный тип, а не `const Object()`: все `const Object()`
  /// в программе — один и тот же объект, поэтому санитайзер, вернувший
  /// `const Object()` как замену, был бы прочитан как «вызывающий ничего не
  /// передал», и напечатался бы оригинал.
  static const Object _notSanitized = _NotSanitized();

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

  /// Значение, которое реально рендерится: `view`, если он задан, иначе
  /// `value`. Санитайзер видит именно его — иначе секрет во `view`
  /// прошёл бы мимо правил: реализацию [LoggableView] рисует её
  /// собственный конвертер, и сам объект `view` в
  /// [Loggable.objectToString]/[Loggable.objectToJson] не уходит.
  ///
  /// Это верно только для таких `view`. Сырой [Loggable] или
  /// [LoggableWrapper] в роли `view` в обходчики как раз ЗАХОДИТ: его
  /// `toString` — это `logClassInfo().toLogString()` и
  /// [Loggable.objectToString] соответственно. Поэтому рендер `view`
  /// обязан идти под сегментом свойства (см. [toLogString] и
  /// [toMapEntry]): без него вложенный обход стартовал бы с пустого
  /// пути — и предложил бы своё значение правилу второй раз, уже как
  /// корень.
  Object? get _renderedValue => view is LoggableNoView ? value : view;

  /// Результат санитайза свойства: исходное [_renderedValue], замена или
  /// [Sanitize.drop]. Вызывать ровно один раз на свойство — результат
  /// передаётся в [toLogString]/[toMapEntry] параметром `sanitized`,
  /// иначе правило сработает на одно и то же свойство дважды.
  Object? _sanitized() => Loggable._sanitizeChild(name, name, _renderedValue);

  /// Результат санитайза для рендера: переданный вызывающим либо,
  /// если аргумент опущен, посчитанный здесь.
  ///
  /// [LoggableData] всегда передаёт `sanitized:` — она обязана позвать
  /// правило один раз на свойство, чтобы уметь выбросить свойство
  /// целиком при [Sanitize.drop]. Но [LoggableData.props] публичен, и
  /// `p.toLogString()` можно вызвать напрямую: без этого fallback такой
  /// вызов печатал бы несанитизированное значение.
  Object? _effectiveSanitized(Object? sanitized) =>
      identical(sanitized, _notSanitized) && Loggable._sanitizing
          ? _sanitized()
          : sanitized;

  MapEntry<String, Object?> toMapEntry({
    LoggableJsonConfig config = const LoggableJsonConfig(),
    Object? sanitized = _notSanitized,
  }) {
    final effectiveConfig = this.config.mergeWithJsonConfig(config);
    final effectiveSanitized = _effectiveSanitized(sanitized);

    // Замена рендерится как обычное значение под сегментом свойства: units
    // и LoggableView рассчитаны на оригинал и к подставленному значению не
    // применяются — иначе часть оригинала просочилась бы через них.
    if (!identical(effectiveSanitized, _notSanitized) &&
        !identical(effectiveSanitized, _renderedValue)) {
      final propJson = Loggable._withSegment(
        name,
        () => Loggable.objectToJson(
          effectiveSanitized,
          config: effectiveConfig.copyWith(units: null),
        ),
      );

      return MapEntry(showName ? name : '@$name', propJson);
    }

    // Как и раньше: units применяются к значению ровно один раз —
    // [Loggable.objectToJson] делает это сам, [LoggableView] сам управляет
    // своими units, и только «сырой» view оборачивается здесь.
    //
    // Сегмент свойства держится в стеке во ВСЕХ ветках, включая обе
    // «видовые»: большинство view в обходчики не заходят, но `Loggable`
    // в качестве view и конвертер [LoggableView.convert], зовущий
    // [Loggable.objectToJson], — заходят. Без сегмента такой вложенный
    // обход стартовал бы с пустого пути: путь свойства терялся бы, а сам
    // аргумент предлагался бы правилу второй раз — уже как корень.
    final propJson = switch (view) {
      LoggableNoView() => Loggable._withSegment(
          name,
          () => Loggable.objectToJson(value, config: effectiveConfig),
        ),
      final LoggableView view =>
        Loggable._withSegment(name, () => view.toJson(value)),
      bool() || num() => Loggable._withSegment(
          name,
          () => Loggable.objectToJson(view, config: effectiveConfig),
        ),
      final view => Loggable._withSegment<Object?>(
          name,
          () => {
            Loggable._viewKey: view.toString(),
            if (effectiveConfig.units case final units?)
              Loggable._unitsKey: units,
          },
        ),
    };

    return MapEntry(showName ? name : '@$name', propJson);
  }

  String toLogString({
    LogTheme theme = LogTheme.noColors,
    int depth = 0,
    LoggableConfig config = const LoggableConfig(),
    Object? sanitized = _notSanitized,
  }) {
    String name2str() => theme.data.keyStyle(theme.formatValue(name));

    final effectiveConfig = this.config.merge(config);
    final effectiveSanitized = _effectiveSanitized(sanitized);
    final depthTheme = theme.depthTheme(depth);
    final prefix =
        showName ? '${name2str()}${depthTheme.punctuation(':')} ' : '';

    // Замена рендерится как обычное значение под сегментом свойства: units
    // и LoggableView рассчитаны на оригинал и к подставленному значению не
    // применяются.
    if (!identical(effectiveSanitized, _notSanitized) &&
        !identical(effectiveSanitized, _renderedValue)) {
      final replacement = Loggable._withSegment(
        name,
        () => Loggable.objectToString(
          effectiveSanitized,
          theme: theme,
          depth: depth + 1,
          config: effectiveConfig.withoutUnits(),
        ),
      );

      return '$prefix${theme.formatValue(replacement)}';
    }

    // Сегмент свойства держится в стеке во ВСЕХ ветках: большинство view
    // в обходчики не заходят, но `Loggable` в качестве view (его
    // `toString` зовёт [Loggable.objectToString]) и конвертер
    // [LoggableView.convert], делающий то же самое, — заходят. Без
    // сегмента такой вложенный обход стартовал бы с пустого пути: путь
    // свойства терялся бы, а сам аргумент предлагался бы правилу второй
    // раз — уже как корень.
    final effectiveView = switch (view) {
      LoggableNoView() => null,
      final LoggableView view => Loggable._withSegment(
          name,
          () => view.toLogString(value, theme: theme, depth: depth),
        ),
      final view => Loggable._withSegment(
          name,
          () => '$view${Loggable.unitsToString(effectiveConfig.units, theme)}',
        ),
    };
    final styledValue = theme.formatValue(
      effectiveView ??
          Loggable._withSegment(
            name,
            () => Loggable.objectToString(
              value,
              theme: theme,
              depth: depth + 1,
              config: effectiveConfig,
            ),
          ),
    );

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

  @override
  LoggableConfig? get _ownConfig => config;

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

  @override
  LoggableConfig? get _ownConfig => config;

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

    // Санитайз каждого свойства ровно один раз; drop убирает запись из
    // Map целиком.
    MapEntry<String, Object?>? prop2entry(Prop<Object?> p) {
      final sanitized = p._sanitized();
      if (Loggable._isDropped(sanitized)) return null;

      return p.toMapEntry(config: propConfig, sanitized: sanitized);
    }

    final propsList = this.props.where((p) => !p.hidden).toList();
    final props = Map.fromEntries(
      propsList.map(prop2entry).whereType<MapEntry<String, Object?>>(),
    );

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

    // Санитайз каждого свойства ровно один раз; drop убирает свойство из
    // вывода целиком.
    String? prop2str(Prop<Object?> p) {
      final sanitized = p._sanitized();
      if (Loggable._isDropped(sanitized)) return null;

      return p.toLogString(
        theme: theme,
        depth: depth,
        config: effectiveConfig,
        sanitized: sanitized,
      );
    }

    final body = props
        .where((p) => !p.hidden)
        .map(prop2str)
        .whereType<String>()
        .join(depthTheme.punctuation(', '));

    return '${depthTheme.brackets('{')}$body${depthTheme.brackets('}')}';
  }
}

final class _ComputedProp {
  const _ComputedProp();

  @override
  String toString() => '<computed>';
}
