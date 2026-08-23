// ignore_for_file: prefer_const_constructors

part of 'loggable.dart';

final class LoggableData {
  static const _computed = _ComputedProp();

  /// The container's own config, or `null` when it has none.
  ///
  /// Needed by a root sanitizer replacement: it takes the container's place
  /// and is printed with the container's settings (see
  /// `Loggable._containerConfig`). [LoggableData] itself has no config of
  /// its own — the builders provide one.
  LoggableConfig? get _ownConfig => null;

  /// The class type.
  ///
  /// [runtimeType] is deliberately not used, because:
  ///
  /// > Calling `toString` on a runtime type is a non-trivial operation that
  /// > can negatively impact performance. It's better to avoid it
  /// > (https://dart.dev/tools/linter-rules/no_runtimeType_toString)
  TypeProp _type;
  TypeProp get type => _type;

  /// The list of properties with their values.
  ///
  /// A value that is itself a [Loggable] is converted to a string, or
  /// formatted for display in a UI, the same way.
  final List<Prop<Object?>> props = [];

  /// A repeated name replaces the earlier property: the string and JSON
  /// outputs behave alike (in a JSON map the last key already won).
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

  /// Adds a property to the description.
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

  /// Adds a property depending on its value.
  ///
  /// When the value is `null` the property is hidden (see [hidden]).
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

  /// Adds a hidden property to the description.
  ///
  /// The property is not printed by [Loggable.objectToString], but it can
  /// be shown in a user interface.
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

  /// Adds a computed property to the description.
  ///
  /// Such a property may be tied to no real data at all, or to several real
  /// properties at once. It is therefore omitted in a user interface that
  /// shows the real data.
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

  /// Adds a double property to the description, formatted with
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

  /// Adds a double property to the description, rounded to [precision]:
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
    // Units are not passed down to children: they describe the object as a
    // whole and land in ":u" at its own level.
    final propConfig = config.copyWith(units: null);

    final className = _type.typeName ?? _type.value.toString();
    final propsList = this.props.where((p) => !p.hidden).toList();

    final Object props;
    if (!Loggable._sanitizing) {
      // The old path: with no rule there is nothing to drop, so the
      // intermediate list of pairs is not needed.
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
      // Each property is sanitized exactly once: a drop removes it from
      // props entirely (the entry is absent, or the list element is
      // skipped).
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

      // The surviving properties decide the shape (a list or a map): once
      // the only unnamed property is dropped, the list form is no longer
      // needed.
      props = kept.any((e) => !e.$1.showName)
          ? kept.map(jsonOf).toList()
          : Map.fromEntries(kept.map(entryOf));
    }

    return {
      if (_type.showName) Loggable._classKey: className,
      Loggable._propsKey: props,
      if (!_type.showBrackets) Loggable._bracketsKey: false,
      if (config.resolvedUnits case final units?) Loggable._unitsKey: units,
    };
  }

  /// Renders WITHOUT offering the root: by the time the walker reaches
  /// here it has already offered this node to the rule. The root is offered
  /// by [toString] — the direct user path, which bypasses the walkers.
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

    // Each property is sanitized exactly once; a drop removes it from the
    // output entirely, leaving no dangling separator.
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

  /// As with [Loggable.toString]: the direct user path (interpolation,
  /// `print`, a debugger) has to offer the root to the rule — its
  /// properties are sanitized on that path anyway.
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

  /// The "not sanitized yet" sentinel for the `sanitized` argument of
  /// [toLogString]/[toMapEntry]. It tells "the caller passed no result"
  /// apart from "the sanitizer replaced the value with null" — `null` is a
  /// valid replacement in its own right and must not read as "not
  /// computed".
  ///
  /// A private type of its own rather than `const Object()`: every
  /// `const Object()` in a program is the same object, so a sanitizer
  /// returning `const Object()` as a replacement would be read as "the
  /// caller passed nothing" and the original would be printed.
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

  /// The value that actually gets rendered: `view` when one is set,
  /// otherwise `value`. The sanitizer sees exactly this one — otherwise a
  /// secret inside a `view` would slip past the rules: a [LoggableView]
  /// implementation is drawn by its own converter, and the `view` object
  /// never reaches
  /// [Loggable.objectToString]/[Loggable.objectToJson].
  ///
  /// That holds only for such a `view`. A bare [Loggable] or
  /// [LoggableWrapper] used as a `view` DOES enter the walkers: its
  /// `toString` is `logClassInfo().toLogString()` and
  /// [Loggable.objectToString] respectively. Rendering a `view` therefore
  /// has to happen under the property's segment (see [toLogString] and
  /// [toMapEntry]): without it the nested walk would start from an empty
  /// path — and would offer its value to the rule a second time, this time
  /// as a root.
  Object? get _renderedValue => view is LoggableNoView ? value : view;

  /// The result of sanitizing the property: the original
  /// [_renderedValue], a replacement, or [Sanitize.drop]. Call it exactly
  /// once per property — the result is handed to
  /// [toLogString]/[toMapEntry] as the `sanitized` argument, or the rule
  /// would fire on the same property twice.
  Object? _sanitized() => Loggable._sanitizeChild(name, name, _renderedValue);

  /// The sanitize result to render with: the one the caller passed, or,
  /// when the argument is omitted, the one computed here.
  ///
  /// [LoggableData] always passes `sanitized:` — it has to call the rule
  /// once per property to be able to drop the property entirely on
  /// [Sanitize.drop]. But [LoggableData.props] is public and
  /// `p.toLogString()` can be called directly: without this fallback such
  /// a call would print an unsanitized value.
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

    // A replacement renders as an ordinary value under the property's
    // segment: units and LoggableView are meant for the original and are
    // not applied to a substituted value — part of the original would leak
    // through them otherwise.
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

    // As before: units are applied to a value exactly once —
    // [Loggable.objectToJson] does it itself, [LoggableView] manages its
    // own units, and only a bare view is wrapped here.
    //
    // The property's segment stays on the stack in EVERY branch, both
    // view ones included: most views do not enter the walkers, but a
    // `Loggable` used as a view, and a [LoggableView.convert] converter
    // calling [Loggable.objectToJson], do. Without the segment such a
    // nested walk would start from an empty path: the property's path
    // would be lost, and the argument itself would be offered to the rule
    // a second time, as a root.
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
            if (effectiveConfig.resolvedUnits case final units?)
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
    final effectiveConfig = this.config.merge(config);

    String name2str() => theme.data.keyStyle(
          theme.formatValue(
            name,
            escapeAnsiCodes: effectiveConfig.resolvedEscapeAnsiCodes,
          ),
        );

    final effectiveSanitized = _effectiveSanitized(sanitized);
    final depthTheme = theme.depthTheme(depth);
    final prefix =
        showName ? '${name2str()}${depthTheme.punctuation(':')} ' : '';

    // A replacement renders as an ordinary value under the property's
    // segment: units and LoggableView are meant for the original and are
    // not applied to a substituted value.
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

      // The replacement is already rendered: its leaves went through the
      // formatter inside objectToString. A second pass over the styled
      // string would escape the theme's own codes.
      return '$prefix$replacement';
    }

    // The property's segment stays on the stack in EVERY branch: most
    // views do not enter the walkers, but a `Loggable` used as a view (its
    // `toString` calls [Loggable.objectToString]) and a
    // [LoggableView.convert] converter doing the same do. Without the
    // segment such a nested walk would start from an empty path: the
    // property's path would be lost, and the argument itself would be
    // offered to the rule a second time, as a root.
    final effectiveView = switch (view) {
      LoggableNoView() => null,
      final LoggableView view => Loggable._withSegment(
          name,
          () => view.toLogString(value, theme: theme, depth: depth),
        ),
      final view => Loggable._withSegment(
          name,
          () =>
              '$view${Loggable.unitsToString(effectiveConfig.resolvedUnits, theme)}',
        ),
    };
    // The formatter is applied to the view's text only: it is arbitrary
    // and has been through nothing so far. The objectToString branch is
    // already rendered — a second pass over it was the double formatting.
    //
    // The safe mode is off here deliberately: a view is a rendering
    // extension point, it was handed the theme, and
    // `LoggableMultiView`/`unitsToString` put the package's own styling
    // into its result. What has to be disarmed is the value the view
    // interpolates, not the text it assembled — and `_LoggableView` does
    // exactly that.
    final styledValue = effectiveView != null
        ? theme.formatValue(effectiveView, escapeAnsiCodes: false)
        : Loggable._withSegment(
            name,
            () => Loggable.objectToString(
              value,
              theme: theme,
              depth: depth + 1,
              config: effectiveConfig,
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

    // Units are not passed down to children: they describe the object as a
    // whole and land in ":u" at its own level.
    final propConfig = effectiveConfig.copyWith(units: null);

    // Each property is sanitized exactly once; a drop removes the entry
    // from the map entirely.
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
      if (effectiveConfig.resolvedUnits case final units?)
        Loggable._unitsKey: units,
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

    // Each property is sanitized exactly once; a drop removes the property
    // from the output entirely.
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
