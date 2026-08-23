import 'dart:math' as math;

import 'package:ansi_escape_codes/extensions.dart';
import 'package:meta/meta.dart';

import '../theme/log_main_theme.dart';
import 'loggable_config.dart';
import 'loggable_json_config.dart';
import 'loggable_multi_data.dart';

part 'loggable_data.dart';
part 'log_value_sanitizer.dart';

/// A mixin describing how a class should look in logs.
///
/// Implement [collectLoggableData] to declare properties. Then:
///
/// - [Loggable.objectToString] (or [toString]) renders the object as
///   a themed string;
/// - [Loggable.objectToJson] renders it as a JSON-compatible structure;
/// - [logClassInfo] returns the property list for in-app UIs.
///
/// Cyclic structures are rendered as a cycle marker (`↺₂` — the
/// number is how many levels up the cycle points; configurable via
/// `LogMainTheme.cycleFormatter`/`cycleStyle`) instead of recursing
/// forever.
/// In JSON a cycle becomes `{":k": "cycle", ":up": 2}`.
abstract mixin class Loggable {
  static const _kindKey = ':k';
  static const _classKey = ':c';
  static const _lengthKey = ':l';
  static const _valueKey = ':v';
  static const _viewKey = ':view';
  static const _unitsKey = ':u';
  static const _propsKey = ':p';
  static const _bracketsKey = ':brackets';
  static const _trimKey = ':trim';
  static const _upKey = ':up';

  static final Map<Type, LoggableTypeConverter<Object?>> _converters = {};

  /// The global sanitizer for values on their way into the output.
  ///
  /// `null` (the default) means output with no processing and no overhead.
  /// It applies in [objectToString] and [objectToJson], and therefore to
  /// ALL outputs: publishers, an in-app log viewer, session export.
  ///
  /// Every value is processed exactly once, by whoever knows its position
  /// (a property, a [Map] key, an element index). The rule is given a
  /// [SanitizeContext] and returns the original value, a replacement, or
  /// [Sanitize.drop].
  ///
  /// ```dart
  /// Loggable.sanitizer = (ctx) => switch (ctx.name) {
  ///   'password' || 'token' => Sanitize.drop,
  ///   _ => ctx.value,
  /// };
  /// ```
  ///
  /// The rule has to be a pure function of [SanitizeContext]: no side
  /// effects (being called does not guarantee the value will be printed —
  /// see the spec, "Cycles, limits, laziness") and no rendering. Rendering
  /// is not only an explicit [objectToString]/[objectToJson], but also
  /// interpolating `'${ctx.value}'` or calling `ctx.value.toString()` for
  /// [Loggable], [LoggableData], [LoggableWrapper] and [LoggableMultiData]:
  /// their `toString` enters the very walkers the rule was called from.
  /// Logging from inside the rule is out too.
  ///
  /// A [Map] key is not offered to the rule: the rule gets the entry's
  /// value and sees the key as [SanitizeContext.name] and as part of
  /// [SanitizeContext.path]. A secret in the key itself
  /// (`{'ann@example.com': {...}}`) cannot be cleaned out by replacement —
  /// a name-based rule can only drop the whole entry with
  /// [Sanitize.drop].
  ///
  /// Values INSIDE a key object are offered only where rendering the key
  /// enters the walkers: in the string output always, in JSON only for
  /// keys whose `toString()` calls a walker itself ([Loggable],
  /// [LoggableData], [LoggableWrapper], [LoggableMultiData]). Any other key
  /// [objectToJson] draws with a plain `key.toString()`, past the walkers —
  /// so a secret inside an ordinary container key
  /// (`{{'pw': 'hunter2'}: 'primary'}`) is masked on the console
  /// (`{{pw: "<masked>"}: "primary"}`) and survives into [objectToJson]
  /// (`{"{pw: hunter2}": "primary"}`), and therefore into a JSONL file
  /// written with `dataFormat: FileLogDataFormat.json` (the default,
  /// `text`, writes the string — already masked — form). The only way to
  /// get the secret out of there is to drop the whole entry, and by a rule
  /// on the VALUE: the key's text differs between the two outputs (see
  /// below), so a rule on it would fire in one of them only. And where a
  /// key's contents are offered, they come under the CONTAINER's path
  /// rather than the entry's: in `{'acc': {Account('DE89'): 'x'}}` the
  /// key's property arrives as `acc.iban`, while the entry itself is
  /// `acc.Account(iban: "DE89")`.
  ///
  /// For a non-`String` key, [SanitizeContext.name] is the key as THIS
  /// PARTICULAR output draws it: the string one through the walker and the
  /// theme (`[₌₂ ₀:1, ₁:2]`, `.admin`), JSON through `key.toString()`
  /// (`[1, 2]`, `Role.admin`). The forms differ, and the string one depends
  /// on the theme as well, so a rule on the key's text fires in one output
  /// and lets the entry through in the other: redact such entries by value,
  /// or drop them whole.
  ///
  /// The sanitizer is a static field and therefore lives within one
  /// isolate: a rule installed in the main isolate does not apply to logs
  /// rendered in a spawned one — it has to be set again there.
  ///
  /// The ROOT value — the `data` object itself — is offered to the rule
  /// unnamed, at `depth == 0`. The direct user paths offer it too, the ones
  /// that never enter the walkers: [toString] on [Loggable] and
  /// [LoggableData], `LoggableMultiData.toString`, `LogMessage` in the
  /// printer. So a `depth == 0` rule also changes what `'$obj'`/`print(obj)`
  /// prints, and [Sanitize.drop] at the root renders an empty string
  /// there.
  ///
  /// A root replacement renders with the container's settings
  /// (`collectionMaxCount`, `stringInQuotes`, the number formats) but
  /// WITHOUT its `units`: units describe the original quantity, and a mask
  /// is not that quantity. A property replacement behaves exactly the
  /// same.
  ///
  /// The scope is values INSIDE `data` only. `message`, `error`,
  /// `stackTrace`, the tags and the namespace path do not pass through the
  /// [objectToString]/[objectToJson] walkers: the printer prints
  /// `log.message` as it is and `error` through `toString()`,
  /// `FileLogCodec` writes them the same way, and the tags and the logger
  /// name are turned into strings by `LazyTags` and `LazyString` — so the
  /// sanitizer never sees these fields and cannot substitute them. The root
  /// offer does not reach them either: the library renders all of it
  /// through [renderOutsideSanitizerScope]. Masking these fields, or
  /// dropping the log entirely, is the job of
  /// `Logger.transformer`.
  ///
  /// THE BOUNDARY: only a `toString()` the library itself calls is
  /// suppressed. Interpolation the caller did — `log.i('$obj')` or
  /// `log.i(() => '$obj')` — is still seen by the rule: it runs in user
  /// code and reaches the library as a finished string. That is the one
  /// case where `depth == 0` changes the text of a log.
  ///
  /// The rule must not throw: there is no fail-closed guard here, unlike
  /// in `Logger.transformer`. The exception escapes into whichever
  /// publisher was rendering at the time: `FileLogStorage` hands it to its
  /// `onError` and writes a fallback line without the data, while
  /// `ConsoleLogPrinter` does not catch it — the exception leaves
  /// `publish()`, and `MultiPublisher` isolates it, but a printer on its
  /// own propagates it to the logging call site.
  static LogValueSanitizer? sanitizer;

  /// The application's default: how to render what the call site left
  /// unsaid.
  ///
  /// The weakest layer of the `defaultConfig ← call site ← [forceConfig]`
  /// chain. Any config from a call site and any container's config
  /// override it, so this is where preferences go ("our strings carry no
  /// quotes") rather than policy — policy has [forceConfig].
  ///
  /// A per-isolate static, like [sanitizer]: [objectToString] and
  /// [objectToJson] are called without a theme and without a logger too,
  /// and the default has to apply there as well. Set it again in a spawned
  /// isolate.
  static LoggableConfig defaultConfig = const LoggableConfig();

  /// The application's policy: what a call site cannot lift.
  ///
  /// The strongest layer of the `[defaultConfig] ← call site ← forceConfig`
  /// chain. It overrides both the call's config and a container's — including
  /// one merged in during the walk, deep inside the data. Unset (`null`)
  /// fields are not policy and are decided by the layers below.
  ///
  /// Units do not belong here: `units` describe one particular quantity
  /// rather than a way of printing, and forced ones would be pinned onto
  /// everything. There is no prohibition — the "force overrides everything"
  /// contract matters more than one special guard — but a root sanitizer
  /// replacement strips units even against force: a replacement is not the
  /// original quantity.
  ///
  /// A per-isolate static, like [sanitizer]. Set it again in a spawned
  /// isolate.
  static LoggableConfig forceConfig = const LoggableConfig();

  /// Path segments down to the current value: a [String] is a name or a
  /// key, an [int] is an index. A static stack, like [_visiting], so that
  /// the walkers' signatures do not have to change.
  static final List<Object> _sanitizeSegments = <Object>[];

  static bool get _sanitizing => sanitizer != null;

  /// The guard segment for the root position: it keeps [_sanitizeSegments]
  /// non-empty while staying out of the path and out of the depth count.
  ///
  /// It is pushed twice (see [_sanitizeRoot]): for the duration of the
  /// rule's call on the root — otherwise rendering from inside the rule
  /// would land in the root branch again and recurse — and for re-rendering
  /// the value that replaced the root — otherwise the sanitizer would fire
  /// on the replacement a second time.
  ///
  /// A private type of its own rather than `const Object()`: two different
  /// `const Object()`s are identical, and the marker would be confused with
  /// any other (see [Prop._notSanitized]).
  static const Object _rootGuardSegment = _SanitizeGuardSegment();

  /// How many guards are in [_sanitizeSegments] right now (0 or 1), so
  /// that [_sanitizeChild] and [SanitizeContext.path] can exclude them in
  /// O(1) instead of scanning the stack for every node.
  static int _placeholderCount = 0;

  /// Applies the sanitizer to a child, knowing its position.
  ///
  /// Returns the original value (left alone), a replacement, or
  /// [Sanitize.drop]. Call it exactly once per value: the walkers do not
  /// apply the sanitizer to non-root values themselves.
  ///
  /// A [LoggableWrapper] is unwrapped: the rule is shown the wrapped value
  /// rather than the wrapper, as at the root (see [objectToString]), or
  /// `Loggable.from(password)` in a property, a [Map] entry or a collection
  /// element would slip past content-based rules. When the rule returns the
  /// contents unchanged, the ORIGINAL wrapper is rendered — its `config`
  /// has to survive; a replacement renders as an ordinary value (the same
  /// as in the rule for `view`).
  static Object? _sanitizeChild(Object segment, String? name, Object? value) {
    final sanitizer = Loggable.sanitizer;
    if (sanitizer == null) return value;

    var offered = value;
    while (offered is LoggableWrapper) {
      offered = offered.data;
    }

    final Object? result;
    _sanitizeSegments.add(segment);
    try {
      result = sanitizer(
        SanitizeContext._(
          name,
          offered,
          _sanitizeSegments.length - _placeholderCount,
          _sanitizeSegments,
        ),
      );
    } finally {
      _sanitizeSegments.removeLast();
    }

    return identical(result, offered) ? value : result;
  }

  /// Renders a child while holding its segment on the path stack, so that
  /// nested values get a complete path.
  static T _withSegment<T>(Object segment, T Function() render) {
    if (!_sanitizing) return render();

    final isPlaceholder = identical(segment, _rootGuardSegment);
    _sanitizeSegments.add(segment);
    if (isPlaceholder) _placeholderCount++;
    try {
      return render();
    } finally {
      if (isPlaceholder) _placeholderCount--;
      _sanitizeSegments.removeLast();
    }
  }

  /// `true` when [value] is the [Sanitize.drop] marker from an ACTIVE
  /// sanitizer.
  ///
  /// With no sanitizer installed, [Sanitize.drop] is ordinary user data:
  /// being public API, without this check it could accidentally wipe
  /// somebody's entry out of the output. A shared predicate, so that the
  /// map, collection and property walkers do not each repeat this check —
  /// and its potential mistake — in their own way.
  static bool _isDropped(Object? value) =>
      _sanitizing && identical(value, Sanitize.drop);

  /// Sanitizing the root: the root has neither a name nor a path segment.
  ///
  /// Returns [Sanitize.drop], a replacement, or the original object. It is
  /// never applied twice: the recursive call with the replacement runs
  /// inside [_withSegment], so the stack is no longer empty by then.
  ///
  /// The rule itself is called under the guard as well: without it,
  /// rendering from inside the rule — including implicitly, via
  /// `'${ctx.value}'` for [Loggable] and company — would see an empty stack
  /// again, call the rule again, and recurse forever. The rule still must
  /// not render (see [sanitizer]), but a hang is too high a price for
  /// breaking that contract.
  static Object? _sanitizeRoot(Object? obj) {
    final sanitizer = Loggable.sanitizer;
    if (sanitizer == null) return obj;

    return _withSegment(
      _rootGuardSegment,
      () => sanitizer(SanitizeContext._(null, obj, 0, _sanitizeSegments)),
    );
  }

  /// Offers the ROOT value to the rule and, when the rule touched it,
  /// returns the finished string output together with a drop flag.
  ///
  /// `null` means "the caller renders it itself": the rule left the value
  /// alone, there is no sanitizer, or this is not a root at all — the
  /// segment stack is not empty, so the value has already been offered to
  /// the rule by its own position.
  ///
  /// `dropped` is a field of its own rather than an empty `text`: a
  /// replacement may legitimately render to an empty string
  /// (`Loggable.builder` with no properties, an empty [LoggableMultiData]),
  /// and emptiness alone cannot tell a drop from that — while the printer's
  /// data block disappears only on a drop.
  ///
  /// THE SINGLE point of the root offer for the string output. It is called
  /// by [objectToString], and the alternative multi-data renderers
  /// (`LoggableMultiData.toString` and `LogMessage` in the printer) MUST
  /// call it as well: they enter [forEachMultiDataEntry] directly, so
  /// without this call the root would never be offered to the rule — and
  /// the console would print what the rule drops from the JSONL file.
  @internal
  static ({String text, bool dropped})? sanitizeRootToString(
    Object? obj, {
    LogTheme theme = LogTheme.noColors,
    int depth = 0,
    LoggableConfig config = const LoggableConfig(),
  }) {
    if (!_sanitizing || _sanitizeSegments.isNotEmpty) return null;

    final sanitized = _sanitizeRoot(obj);
    if (identical(sanitized, Sanitize.drop)) return (text: '', dropped: true);
    if (identical(sanitized, obj)) return null;

    // The guard segment keeps the stack non-empty: the sanitizer will not
    // be applied to the replacement a second time. It does not count
    // towards depth or path.
    return (
      text: _withSegment(
        _rootGuardSegment,
        () => objectToString(
          sanitized,
          theme: theme,
          depth: depth,
          config: _rootConfig(obj, config),
        ),
      ),
      dropped: false,
    );
  }

  /// The configuration a ROOT REPLACEMENT is rendered with.
  ///
  /// The replacement takes the container's place, so it is formatted with
  /// the container's settings: [LoggableMultiData] has a `config` of its
  /// own, and the walker cannot see it — only the surrounding one was
  /// passed in. Without this merge the renderers would diverge:
  /// `LoggableMultiData.toString` and `LogMessage` pass `data.config` here
  /// themselves (for them the merge is idempotent), while
  /// [objectToString]/[objectToJson] would print the replacement without
  /// the container's limits — and the JSONL would disagree with the
  /// console.
  ///
  /// `units` are stripped in the process: units describe the original
  /// quantity, and a replacement is not that quantity. A property does
  /// exactly the same (see `Prop.toLogString`), and the root has to behave
  /// alike. The remaining config fields describe not the value but the way
  /// it is printed (`collectionMaxCount`, `stringInQuotes`, the number
  /// formats) — those are inherited.
  static LoggableConfig _rootConfig(Object? obj, LoggableConfig config) =>
      (_containerConfig(obj)?.merge(config) ?? config).withoutUnits();

  /// The same as [_rootConfig], but for the JSON output.
  static LoggableJsonConfig _rootJsonConfig(
    Object? obj,
    LoggableJsonConfig config,
  ) =>
      (_containerConfig(obj)?.mergeWithJsonConfig(config) ?? config)
          .copyWith(units: null);

  /// The own config of the container standing at the root, or `null`.
  ///
  /// A single point for [_rootConfig] and [_rootJsonConfig]: there is more
  /// than one container with a config of its own, and the shared code used
  /// to see only [LoggableMultiData]. The builders keep their config in a
  /// private field of the subclass, so it is asked for through
  /// [LoggableData._ownConfig].
  ///
  /// `LoggableWrapper` deliberately does not reach here: it unwraps itself
  /// before the walk (`toString`/`toJson` call
  /// `objectToString`/`objectToJson` on their data with their config), so
  /// what the rule is offered is already the contents, not the wrapper.
  static LoggableConfig? _containerConfig(Object? obj) => switch (obj) {
        LoggableMultiData() => obj.config,
        LoggableData() => obj._ownConfig,
        _ => null,
      };

  /// Renders the ROOT value and reports whether the rule dropped it.
  ///
  /// Finished text is not enough for the printer: an empty string can be a
  /// legitimate render (an empty [LoggableMultiData], a `Loggable.builder`
  /// with no properties) as well as the result of [Sanitize.drop] — and the
  /// data block's colon must disappear only in the second case. The two
  /// cannot be told apart from outside: the root offer lives inside
  /// [sanitizeRootToString], and calling that a second time is not allowed —
  /// the rule would fire on the root twice. So whoever made the offer
  /// reports the signal.
  ///
  /// The root is offered exactly once: when the rule leaves it alone, the
  /// value is rendered under the guard and [objectToString] will not offer
  /// it again.
  ///
  /// The callers are `LogMessage` in the printer and `FileLogCodec`: for
  /// both, a dropped data block has to vanish entirely rather than turn
  /// into an empty string.
  @internal
  static ({String text, bool dropped}) renderRoot(
    Object? obj, {
    LogTheme theme = LogTheme.noColors,
    LoggableConfig config = const LoggableConfig(),
  }) {
    if (!_sanitizing) {
      return (
        text: objectToString(obj, theme: theme, config: config),
        dropped: false,
      );
    }

    // The wrapper is unwrapped BEFORE the root offer — as in
    // [objectToString]: the rule is shown the wrapped value, not the
    // packaging of render parameters.
    var value = obj;
    var effective = config;
    while (value is LoggableWrapper) {
      effective = value.config.merge(effective);
      value = value.data;
    }

    if (sanitizeRootToString(value, theme: theme, config: effective)
        case final rendered?) {
      return rendered;
    }

    // The root was already offered a line above, so it renders under the
    // guard: without it [objectToString] would see an empty stack and offer
    // the same value a second time.
    return (
      text: _withSegment(
        _rootGuardSegment,
        () => objectToString(value, theme: theme, config: effective),
      ),
      dropped: false,
    );
  }

  /// The same as [renderRoot], but for the JSON output.
  ///
  /// [objectToJson] returns `null` for a dropped root, and `null` is also a
  /// legitimate value: a drop cannot be recognised from it alone. Yet
  /// `FileLogCodec` has to leave out the `data` key entirely in that case —
  /// exactly as the printer removes the data block.
  @internal
  static ({Object? json, bool dropped}) renderRootJson(
    Object? obj, {
    LoggableJsonConfig config = const LoggableJsonConfig(),
  }) {
    if (!_sanitizing || _sanitizeSegments.isNotEmpty) {
      return (json: objectToJson(obj, config: config), dropped: false);
    }

    var value = obj;
    var effective = config;
    while (value is LoggableWrapper) {
      effective = value.config.mergeWithJsonConfig(effective);
      value = value.data;
    }

    final sanitized = _sanitizeRoot(value);
    if (identical(sanitized, Sanitize.drop)) return (json: null, dropped: true);

    // The guard is held for the whole root render — both of a replacement
    // and of an untouched value (see [objectToJson]).
    return (
      json: _withSegment(
        _rootGuardSegment,
        () => identical(sanitized, value)
            ? _visitToJson(value, config: effective)
            : objectToJson(
                sanitized,
                config: _rootJsonConfig(value, effective),
              ),
      ),
      dropped: false,
    );
  }

  /// Runs [render] with the root offer SUPPRESSED: what the library prints
  /// inside is not shown to the rule as a root.
  ///
  /// Needed where the library itself calls `toString()` on a user object
  /// that is NOT part of `data`:
  ///
  /// - `error` — in the printer (`LogMessage`) and in `FileLogCodec`;
  /// - `stackTrace` — the same two; in the printer through a LAZY
  ///   `Trace.from`, so the suppression has to cover reading the frames as
  ///   well;
  /// - the tags — `LazyTags.convert`, together with diagnosing an invalid
  ///   value;
  /// - `message` and the namespace name — `_GuardedLazyString.convert`.
  ///
  /// The sanitizer's scope is values inside `data` only (see [sanitizer]),
  /// and the root offer that `toString()` on [Loggable] and [LoggableData]
  /// makes must not reach these values: a `depth == 0` rule would otherwise
  /// erase the error (leaving a dangling colon) or the log's text, and
  /// would rewrite `Log.tags` and `Logger.path`. The last two are not a
  /// render at all: they are cached, they feed the
  /// `activeTags`/`activeNamespaces` filters, and they are what publishers
  /// that draw nothing see.
  ///
  /// What has to be wrapped is THE PLACE where the value is actually turned
  /// into a string, not the place where the lazy holder was created:
  /// `Trace.from` and `TypedLazy` stringify on first read, which happens
  /// later. The user's closure (a lazy message, a lazy name) stays OUTSIDE
  /// the suppression — inside it the sanitizer works as usual.
  ///
  /// The positions of nested values do not change: the guard counts
  /// towards neither the path nor the depth, so such an object's properties
  /// are offered to the rule exactly as before.
  @internal
  static T renderOutsideSanitizerScope<T>(T Function() render) =>
      _withSegment(_rootGuardSegment, render);

  /// Walks the entries of a [LoggableMultiData], applying the sanitizer to
  /// each one by its key exactly once, and calls [render] for the
  /// survivors.
  ///
  /// THE SINGLE point where multi-data entries are sanitized. Four
  /// different places draw the sections ([_multiDataToString],
  /// [_multiDataToJson], `LoggableMultiData.toString` and `LogMessage` in
  /// the printer — each with its own separators and line breaks), but only
  /// this helper knows a value's position: a renderer that went around it
  /// would hand the value to the walker as a ROOT — with no name, no path
  /// segment and past the rule.
  ///
  /// The root is not this helper's business: renderers for which the
  /// multi-data is itself the root value have to first call
  /// [sanitizeRootToString].
  ///
  /// [render] is given an already sanitized value and must render it only
  /// inside the call: the key's segment is held on the path stack so that
  /// nested values get a complete path.
  ///
  /// Returns `true` when the rule dropped at least one entry. The printer
  /// needs it: a multi-data with ALL of its sections dropped must not leave
  /// a dangling `login: ` label with nothing after it, while a multi-data
  /// that is empty in its own right keeps the colon. Emptiness of the text
  /// cannot tell those two apart — only the fact of a drop can.
  @internal
  static bool forEachMultiDataEntry(
    LoggableMultiData data,
    void Function(String key, Object? value) render,
  ) {
    var dropped = false;
    for (final entry in data.data.entries) {
      final sanitized = _sanitizeChild(entry.key, entry.key, entry.value);
      if (_isDropped(sanitized)) {
        dropped = true;
        continue;
      }

      _withSegment(entry.key, () => render(entry.key, sanitized));
    }

    return dropped;
  }

  /// The method has to fill [data] with a description of the class.
  void collectLoggableData(LoggableData data);

  /// Wraps an object so that logging parameters can be passed with it.
  ///
  /// Worth using only for primitives, enums, collections and [Loggable], to
  /// carry logging parameters. For other objects that do not support
  /// [Loggable] directly, use
  /// [Loggable.builder].
  ///
  /// For a [Loggable] it allows passing parameters the object itself did
  /// not set.
  static LoggableWrapper from(
    Object? obj, {
    LoggableConfig config = const LoggableConfig(),
  }) =>
      LoggableWrapper(obj, config: config);

  /// Builds a [LoggableData] for any object that does not support
  /// [Loggable] to begin with.
  ///
  /// ```dart
  /// const obj = NotLoggableData(a: 'abc', b: [1, 2, 3]);
  /// log.d(
  ///   'object',
  ///   data: Loggable.builder(obj)
  ///     ..prop('a', obj.a)
  ///     ..prop('b', obj.b, collectionMaxCount: 2),
  /// );
  /// // object: NotLoggableData(a: "abc", b: [₌₃ ₀:1, …, ₂:3])
  /// ```
  ///
  /// In some cases you may want to hide the class name or the brackets.
  /// Use the [showName] and [showBrackets] parameters for that:
  ///
  /// ```dart
  /// final point = Point(lat: 27.988056, lon: 86.925278);
  /// log.d(
  ///   'Mount Everest',
  ///   data: Loggable.builder(point, showName: false, showBrackets: false)
  ///     ..prop('lat', point.lat, showName: false)
  ///     ..prop('lon', point.lon, showName: false),
  /// );
  /// // Mount Everest: 27.988056, 86.925278
  /// ```
  static LoggableData builder(
    Object? value, {
    String? name,
    bool showName = true,
    bool showBrackets = true,
    LoggableConfig config = const LoggableConfig(),
  }) =>
      _LoggableBuilder(
        value,
        name: name,
        showName: showName,
        showBrackets: showBrackets,
        config: config,
      );

  /// Builds a [Map]-like structure out of a [LoggableData].
  ///
  /// ```dart
  /// log.d('map', data: {'a': 1, 'b': 2, 'c': 3});
  /// // map: {a: 1, b: 2, c: 3}
  ///
  /// log.d('map', data: Loggable.mapBuilder()
  ///     ..prop('a', 1, units: 'kg')
  ///     ..prop('b', 2, units: 'm')
  ///     ..prop('c', 3, units: 'sec'),
  /// );
  /// // map: {a: 1kg, b: 2m, c: 3sec}
  ///
  /// log.d('map', data: Loggable.mapBuilder(config: LoggableConfig(units: 'm'))
  ///     ..prop('a', 1)
  ///     ..prop('b', 2)
  ///     ..prop('c', 3),
  /// );
  /// // map: {a: 1m, b: 2m, c: 3m}
  /// ```
  static LoggableData mapBuilder({
    LoggableConfig config = const LoggableConfig(),
  }) =>
      _LoggableMapBuilder(config: config);

  static void registerTypeConverter<T extends Object?>(
    LoggableTypeConverter<T> converter,
  ) {
    _converters[T] = converter as LoggableTypeConverter<Object?>;
  }

  /// Removes a converter by its target type [T] (the same one used to
  /// register it), not by the converter's type. A wrong [T] is a silent
  /// no-op.
  static void unregisterTypeConverter<T>() {
    _converters.remove(T);
  }

  @nonVirtual
  LoggableData logClassInfo() {
    final data = LoggableData._(TypeProp._(runtimeType));
    collectLoggableData(data);
    return data;
  }

  /// A class that mixes in [Loggable] has thereby accepted that its
  /// `toString` IS log rendering: its properties are sanitized here just as
  /// in [objectToString], so the object itself is offered to the rule in
  /// the root position too (see [_rootToString]).
  @override
  String toString() => _rootToString(this, () => logClassInfo().toLogString());

  /// Objects being formatted in the current recursion chain — protection
  /// against cyclic structures (after the SDK's `_toStringVisiting`).
  static final List<Object> _visiting = <Object>[];

  /// Primitives cannot hold references and need no cycle protection.
  static bool _canContainCycle(Object obj) => switch (obj) {
        bool() ||
        num() ||
        String() ||
        Enum() ||
        DateTime() ||
        Duration() =>
          false,
        _ => true,
      };

  /// The object's index in the formatting stack, or -1 when it is not on
  /// the stack.
  static int _visitingIndexOf(Object obj) {
    for (var i = 0; i < _visiting.length; i++) {
      if (identical(_visiting[i], obj)) return i;
    }

    return -1;
  }

  /// How many levels up the ancestor at [ancestorIndex] sits on the
  /// stack.
  static int _cycleLevelsUp(int ancestorIndex) =>
      _visiting.length - ancestorIndex;

  /// User keys starting with ':' are escaped with one more ':' — otherwise
  /// they would be indistinguishable from the service ones (':k', ':v',
  /// ...).
  static String _escapeServiceKey(String key) =>
      key.startsWith(':') ? ':$key' : key;

  /// Converts an object to a string using the [theme] and the
  /// [config].
  static String objectToString(
    Object? obj, {
    LogTheme theme = LogTheme.noColors,
    int depth = 0,
    LoggableConfig config = const LoggableConfig(),
  }) {
    // LoggableWrapper is transparent packaging for render parameters, not
    // a value in its own right. It is unwrapped before the root check:
    // otherwise the sanitizer would see the wrapper and its contents as two
    // different roots (the wrapper object, and then the data inside it
    // again).
    if (obj is LoggableWrapper) {
      return objectToString(
        obj.data,
        theme: theme,
        depth: depth,
        config: obj.config.merge(config),
      );
    }

    // The root offer lives in the shared helper: the multi-data renderers
    // that do not pass through this walker call the same one.
    if (sanitizeRootToString(obj, theme: theme, depth: depth, config: config)
        case final rendered?) {
      return rendered.text;
    }

    // A root the rule left alone renders under the guard too, not only a
    // replacement. Otherwise the stack would stay empty for the duration of
    // the root render, and `toString()` of any [Loggable] the render
    // reaches directly (a [Map] key, interpolation inside someone else's
    // `toString`) would make an offer of ITS OWN — the same root would be
    // offered to the rule a second time.
    if (_sanitizing && _sanitizeSegments.isEmpty) {
      return _withSegment(
        _rootGuardSegment,
        () => _visitToString(obj, theme: theme, depth: depth, config: config),
      );
    }

    return _visitToString(obj, theme: theme, depth: depth, config: config);
  }

  /// Renders with cycle protection; the root offer has been made by this
  /// point.
  static String _visitToString(
    Object? obj, {
    required LogTheme theme,
    required int depth,
    required LoggableConfig config,
  }) {
    if (obj != null && _canContainCycle(obj)) {
      final ancestorIndex = _visitingIndexOf(obj);
      if (ancestorIndex != -1) {
        return theme.main.cycleStyle(
          theme.formatCycle(_cycleLevelsUp(ancestorIndex)),
        );
      }

      _visiting.add(obj);
      try {
        return _objectToString(
          obj,
          theme: theme,
          depth: depth,
          config: config,
        );
      } finally {
        _visiting.removeLast();
      }
    }

    return _objectToString(obj, theme: theme, depth: depth, config: config);
  }

  /// Renders a value standing in the ROOT position with the caller's own
  /// `toString`, having offered it to the rule first.
  ///
  /// `toString` is a direct user path (interpolation, `print`, a debugger)
  /// and never enters [objectToString], so it makes the root offer itself.
  /// Inside a walk the segment stack is not empty — there the value has
  /// already been offered by its own position and is not shown to the rule
  /// twice.
  ///
  /// A replacement is rendered by the walker as an ordinary value: the
  /// caller's own `config` (on `Loggable.builder`) is not applied to it —
  /// exactly as in [objectToString], where the replacement of a
  /// [LoggableData] root does not inherit it either.
  static String _rootToString(Object? obj, String Function() render) {
    if (!_sanitizing || _sanitizeSegments.isNotEmpty) return render();

    final sanitized = _sanitizeRoot(obj);
    if (identical(sanitized, Sanitize.drop)) return '';

    return _withSegment(
      _rootGuardSegment,
      () => identical(sanitized, obj) ? render() : objectToString(sanitized),
    );
  }

  static String _objectToString(
    Object? obj, {
    required LogTheme theme,
    required int depth,
    required LoggableConfig config,
  }) {
    final converter = _converters[obj.runtimeType];
    if (converter != null) {
      return converter.convertToData(obj).toLogString(
            theme: theme,
            depth: depth,
            config: config.toEffectiveConfig(),
          );
    }

    return switch (obj) {
      null => 'null',
      Enum() => _enumToString(obj, theme: theme, config: config),
      int() => _intToString(obj, theme: theme, config: config),
      double() => _doubleToString(obj, theme: theme, config: config),
      String() => _stringToString(obj, theme: theme, config: config),
      DateTime() => _dateTimeToString(obj, theme: theme),
      List<Object?>() =>
        listToString(obj, theme: theme, depth: depth, config: config),
      Set<Object?>() =>
        setToString(obj, theme: theme, depth: depth, config: config),
      // A bare Iterable is walked once by default: its length and last
      // element may be expensive or single-use. Only the caller knows, so
      // only the caller says so.
      Iterable<Object?>() => config.resolvedIterableEfficientLength
          ? efficientLengthIterableToString(
              obj,
              theme: theme,
              depth: depth,
              config: config,
            )
          : iterableToString(
              obj,
              theme: theme,
              depth: depth,
              config: config,
            ),
      Map<Object?, Object?>() => _mapToString(
          obj,
          theme: theme,
          depth: depth,
          config: config,
        ),
      Loggable() => obj
          .logClassInfo()
          .toLogString(theme: theme, depth: depth, config: config),
      LoggableData() => obj.toLogString(
          theme: theme,
          depth: depth,
          config: config,
        ),
      // LoggableWrapper is unwrapped transparently in [objectToString]
      // before reaching here (see the comment there) — this branch is
      // unreachable.
      LoggableMultiData() => _multiDataToString(
          obj,
          theme: theme,
          depth: depth,
          config: config,
        ),
      _ => theme.formatValue(
          obj.toString(),
          escapeAnsiCodes: config.resolvedEscapeAnsiCodes,
        )
    };
  }

  static String _multiDataToString(
    LoggableMultiData obj, {
    required LogTheme theme,
    required int depth,
    required LoggableConfig config,
  }) {
    final depthTheme = theme.depthTheme(depth);
    final entryConfig = obj.config.merge(config);
    final parts = <String>[];

    forEachMultiDataEntry(obj, (key, value) {
      final text = objectToString(
        value,
        theme: theme,
        depth: depth,
        config: entryConfig,
      );

      parts.add(
        key.isEmpty
            ? text
            : '${theme.data.sectionStyle(key)}${theme.styledColon} $text',
      );
    });

    return parts.join(depthTheme.punctuation(', '));
  }

  /// Converts [obj] to a JSON-compatible value.
  ///
  /// Map keys are strings as required by JSON. Non-string keys use
  /// `toString()`. If distinct emitted entries produce the same JSON key, an
  /// [ArgumentError] is thrown instead of silently keeping the later value.
  /// Entries removed by [Sanitize.drop] do not participate in this check.
  static Object? objectToJson(
    Object? obj, {
    LoggableJsonConfig config = const LoggableJsonConfig(),
  }) {
    // See the comment in [objectToString]: the wrapper is unwrapped before
    // the root check, so that the sanitizer does not see two roots instead
    // of one.
    if (obj is LoggableWrapper) {
      return objectToJson(
        obj.data,
        config: obj.config.mergeWithJsonConfig(config),
      );
    }

    if (_sanitizing && _sanitizeSegments.isEmpty) {
      final sanitized = _sanitizeRoot(obj);
      if (identical(sanitized, Sanitize.drop)) return null;

      // The guard segment keeps the stack non-empty for the WHOLE root
      // render — of a replacement and of an untouched value alike (see
      // [objectToString]): the sanitizer will not be applied to the root a
      // second time. The guard counts towards neither depth nor path. The
      // replacement's configuration matches [sanitizeRootToString] (see
      // [_rootJsonConfig]), or the JSON would diverge from the string
      // output.
      return _withSegment(
        _rootGuardSegment,
        () => identical(sanitized, obj)
            ? _visitToJson(obj, config: config)
            : objectToJson(sanitized, config: _rootJsonConfig(obj, config)),
      );
    }

    return _visitToJson(obj, config: config);
  }

  /// Renders with cycle protection; the root offer has been made by this
  /// point.
  static Object? _visitToJson(
    Object? obj, {
    required LoggableJsonConfig config,
  }) {
    if (obj != null && _canContainCycle(obj)) {
      final ancestorIndex = _visitingIndexOf(obj);
      if (ancestorIndex != -1) {
        return {_kindKey: 'cycle', _upKey: _cycleLevelsUp(ancestorIndex)};
      }

      _visiting.add(obj);
      try {
        return _objectToJson(obj, config: config);
      } finally {
        _visiting.removeLast();
      }
    }

    return _objectToJson(obj, config: config);
  }

  static Object? _objectToJson(
    Object? obj, {
    required LoggableJsonConfig config,
  }) {
    final converter = _converters[obj.runtimeType];
    if (converter != null) {
      return converter.convertToData(obj).toJson(config: config);
    }

    return switch (obj) {
      null || bool() || String() => obj,
      int() => _intToJson(obj, config: config),
      double() => _doubleToJson(obj, config: config),
      Enum() => _enumToJson(obj, config: config),
      DateTime() => _dateTimeToJson(obj),
      Duration() => _durationToJson(obj),
      List<Object?>() => listToJson(obj, config: config),
      Set<Object?>() => setToJson(obj, config: config),
      Iterable<Object?>() => config.resolvedIterableEfficientLength
          ? efficientLengthIterableToJson(obj, config: config)
          : iterableToJson(obj, config: config),
      Map<Object?, Object?>() => _mapToJson(obj, config: config),
      Loggable() => obj.logClassInfo().toJson(config: config),
      LoggableData() => obj.toJson(config: config),
      // LoggableWrapper is unwrapped transparently in [objectToJson]
      // before reaching here (see the comment there) — this branch is
      // unreachable.
      LoggableMultiData() => _multiDataToJson(obj, config: config),
      _ => {_viewKey: obj.toString()}
    };
  }

  /// Sanitizes `LoggableMultiData` entries by key for JSON; collected with
  /// a loop rather than `Map.map` so that entries sanitized down to
  /// [Sanitize.drop] can be skipped.
  static Map<String, Object?> _multiDataToJson(
    LoggableMultiData obj, {
    required LoggableJsonConfig config,
  }) {
    final entryConfig = obj.config.mergeWithJsonConfig(config);

    // The type marker comes first, as in the other service structures. A
    // user key cannot overwrite it: keys starting with ':' are escaped.
    final result = <String, Object?>{_kindKey: 'multi'};
    forEachMultiDataEntry(obj, (key, value) {
      result[_escapeServiceKey(key)] = objectToJson(value, config: entryConfig);
    });

    return result;
  }

  /// Converts a list to a string of the form `[₌₅ ₀:first, …, ₄:last]`.
  ///
  /// See [efficientLengthIterableToString].
  @visibleForTesting
  static String listToString(
    List<Object?> list, {
    LogTheme theme = LogTheme.noColors,
    int depth = 0,
    LoggableConfig config = const LoggableConfig(),
  }) =>
      efficientLengthIterableToString(
        list,
        theme: theme,
        depth: depth,
        start: '[',
        end: ']',
        config: config,
      );

  @visibleForTesting
  static Object listToJson(
    List<Object?> list, {
    LoggableJsonConfig config = const LoggableJsonConfig(),
  }) =>
      _efficientLengthIterableToJson(
        list,
        'list',
        isList: true,
        config: config,
      );

  /// Converts a set to a string of the form `{₌₅ ₀:first, …, ₄:last}`.
  ///
  /// See [efficientLengthIterableToString].
  @visibleForTesting
  static String setToString(
    Set<Object?> set, {
    LogTheme theme = LogTheme.noColors,
    int depth = 0,
    LoggableConfig config = const LoggableConfig(),
  }) =>
      efficientLengthIterableToString(
        set,
        theme: theme,
        depth: depth,
        start: '{',
        end: '}',
        config: config,
      );

  @visibleForTesting
  static Object setToJson(
    Set<Object?> set, {
    LoggableJsonConfig config = const LoggableJsonConfig(),
  }) =>
      _efficientLengthIterableToJson(
        set,
        'set',
        config: config,
      );

  /// Converts a collection to a string of the form
  /// `(₌₅ ₀:first, …, ₄:last)`.
  ///
  /// Only for collections with an efficient length (a [List] or a [Set],
  /// for instance) and efficient access to the last element.
  ///
  /// When the collection holds more elements than
  /// [LoggableConfig.collectionMaxCount], or the string is longer than
  /// [LoggableConfig.collectionMaxStringLength], the result is truncated.
  ///
  /// The possible shapes:
  /// - 0 elements
  ///   - (₌₀)
  /// - 1 element
  ///   - (₌₁ …)
  ///   - (₌₁ ₀:a)
  /// - 2 elements
  ///   - (₌₂ …)
  ///   - (₌₂ ₀:a, …)
  ///   - (₌₂ ₀:a, ₁:b)
  /// - 3 elements
  ///   - (₌₃ …)
  ///   - (₌₃ ₀:a, …)
  ///   - (₌₃ ₀:a, …, ₂:c)
  ///   - (₌₃ ₀:a, ₁:b, ₂:c)
  /// - 4 elements
  ///   - (₌₄ …)
  ///   - (₌₄ ₀:a, …)
  ///   - (₌₄ ₀:a, …, ₃:d)
  ///   - (₌₄ ₀:a, ₁:b, …, ₃:d)
  ///   - (₌₄ ₀:a, ₁:b, ₂:c, ₃:d)
  ///
  /// Throws [ArgumentError] when the count limit is negative, the length
  /// limit is not positive, or the delimiters contain control codes.
  @visibleForTesting
  static String efficientLengthIterableToString(
    Iterable<Object?> iterable, {
    LogTheme theme = LogTheme.noColors,
    int depth = 0,
    String start = '(',
    String end = ')',
    LoggableConfig config = const LoggableConfig(),
  }) {
    final maxCount = config.resolvedCollectionMaxCount;
    final maxLength = config.resolvedCollectionMaxStringLength;

    _validateIterableToStringArguments(
      maxCount: maxCount,
      maxLength: maxLength,
      start: start,
      end: end,
    );

    final depthTheme = theme.depthTheme(depth);
    final showCount = config.resolvedCollectionShowCount;
    final showIndexes = config.resolvedCollectionShowIndexes;

    final buf = StringBuffer(depthTheme.brackets(start));

    // In this mode neither the length nor the last element is needed.
    if (!showCount && maxCount == null && maxLength == null) {
      _addAllIterableItemsToBuf(
        buf,
        iterable,
        theme: theme,
        depth: depth,
        depthTheme: depthTheme,
        config: config,
        showIndexes: showIndexes,
      );
      buf.write(depthTheme.brackets(end));
      return buf.toString();
    }

    final count = iterable.length;
    var reservedLength = start.length + end.length;

    // Add the collection's size.
    if (showCount) {
      final countText = '${theme.formatCount(count)}${count > 0 ? ' ' : ''}';
      reservedLength += countText.length;
      buf.write(depthTheme.description(countText));
    }

    _addEfficientLengthIterableItemsToBuf(
      buf,
      iterable,
      theme: theme,
      depth: depth,
      depthTheme: depthTheme,
      config: config,
      count: count,
      maxCount: maxCount,
      maxLength:
          maxLength == null ? null : math.max(maxLength - reservedLength, 0),
      showIndexes: showIndexes,
    );

    buf.write(depthTheme.brackets(end));

    return buf.toString();
  }

  static void _addEfficientLengthIterableItemsToBuf(
    StringBuffer buf,
    Iterable<Object?> iterable, {
    required LogTheme theme,
    required int depth,
    required LogDepthTheme depthTheme,
    required LoggableConfig config,
    required int count,
    required int? maxCount,
    required int? maxLength,
    required bool showIndexes,
  }) {
    // Sanitizing a collection element: the position is the index in the
    // original collection (not the ordinal among the printed ones, or the
    // path would lie after truncation), and there is no name. Sanitize.drop
    // in this position does not remove the element — the length and the
    // truncation budget would drift apart — but turns into a '<dropped>'
    // marker.
    String obj2str(int index, Object? obj) {
      final value = _sanitizeChild(index, null, obj);

      return _withSegment(
        index,
        () => objectToString(
          _isDropped(value) ? '<dropped>' : value,
          theme: theme,
          depth: depth + 1,
          config: config,
        ),
      );
    }

    String index2str(int index) =>
        depthTheme.description(theme.formatIndex(index));

    String indexedObj2str(int index, Object? obj) =>
        '${index2str(index)}${obj2str(index, obj)}';

    bool hasSpaceFor(int len) => maxLength == null || len <= maxLength;

    const delimiterStr = ', ';
    late final delimiter = depthTheme.punctuation(delimiterStr);

    // This path needs neither the collection's length nor access to its
    // last element.
    if (maxLength == null && maxCount == null) {
      _addAllIterableItemsToBuf(
        buf,
        iterable,
        theme: theme,
        depth: depth,
        depthTheme: depthTheme,
        config: config,
        showIndexes: showIndexes,
      );
      return;
    }

    if (count == 0) {
      return;
    }

    final ellipsisStr = theme.main.ellipsis;
    late final ellipsis = depthTheme.punctuation(ellipsisStr);
    final ellipsisSize = ellipsisStr.length;

    // When not a single element fits, print the ellipsis: (₌ₙ …)
    if (maxCount != null && maxCount <= 0) {
      buf.write(ellipsis);
      return;
    }

    const delimiterSize = delimiterStr.length;
    final delimiterAndEllipsis =
        depthTheme.punctuation('$delimiterStr$ellipsisStr');

    // In the abbreviated form the first and last elements take priority.
    // The elements in between need only one buffer: it makes it possible to
    // replace the last one added with an ellipsis when the string turns out
    // longer than the limit.
    final iterator = iterable.iterator..moveNext();

    final first = showIndexes
        ? indexedObj2str(0, iterator.current)
        : obj2str(0, iterator.current);
    final firstSize = first.lengthWithoutEscapeCodes;
    // When the first element does not fit, print the ellipsis: (₌ₙ …) —
    // but only when the element is larger than the ellipsis, otherwise the
    // element itself is the better thing to print.
    if (!hasSpaceFor(firstSize) && firstSize > ellipsisSize) {
      buf.write(ellipsis);
      return;
    }

    // (₌₁ ₀:a)
    if (count == 1) {
      buf.write(first);
      return;
    }

    // The last element is rendered lazily: with collectionMaxCount == 1 it
    // never reaches the output, and rendering is also sanitizing — the rule
    // would be offered a value the limit had already cut off. The spec
    // allows that effect for the LENGTH budget only (there a candidate's
    // size cannot be measured otherwise), not for the count limit.
    late final last = showIndexes
        ? indexedObj2str(count - 1, iterable.last)
        : obj2str(count - 1, iterable.last);
    late final lastSize = last.lengthWithoutEscapeCodes;

    if (count == 2) {
      // (₌₂ ₀:a, ₁:b). The limit is checked first: otherwise `lastSize`
      // would be computed for maxCount == 1 as well, where the last element
      // is not in the output at all.
      if ((maxCount == null || maxCount > 1) &&
          hasSpaceFor(firstSize + delimiterSize + lastSize)) {
        buf
          ..write(first)
          ..write(delimiter)
          ..write(last);
        return;
      }

      // (₌₂ ₀:a, …)
      if (hasSpaceFor(firstSize + delimiterSize + ellipsisSize)) {
        buf
          ..write(first)
          ..write(delimiterAndEllipsis);
        return;
      }

      // (₌₂ …)
      buf.write(ellipsis);
      return;
    }

    // When the first element plus the ellipsis does not fit, print the
    // ellipsis alone: (₌ₙ …)
    if (!hasSpaceFor(firstSize + delimiterSize + ellipsisSize)) {
      buf.write(ellipsis);
      return;
    }

    buf.write(first);

    // When only one element fits, the ellipsis goes at the end.
    if (maxCount != null && maxCount == 1) {
      buf.write(delimiterAndEllipsis);
      return;
    }

    final displayedCount = math.min(maxCount ?? count, count);

    // Reserve room for the separator and the last element, and — when
    // truncating by count — for the ellipsis that will follow them.
    var usedSize = firstSize + delimiterSize + lastSize;
    if (displayedCount < count) {
      usedSize += delimiterSize + ellipsisSize;
    }

    // When the last element does not fit, print an ellipsis in its place:
    // (₌ₙ ₀:a, …)
    if (!hasSpaceFor(usedSize)) {
      buf.write(delimiterAndEllipsis);
      return;
    }

    String? bufferedItem;

    void writeBufferedItem() {
      if (bufferedItem case final item?) {
        buf
          ..write(delimiter)
          ..write(item);
      }
    }

    for (var i = 1; i < displayedCount - 1; i++) {
      iterator.moveNext();
      final item = showIndexes
          ? indexedObj2str(i, iterator.current)
          : obj2str(i, iterator.current);
      final itemSize = delimiterSize + item.lengthWithoutEscapeCodes;

      // When the next element does not fit, try to put an ellipsis in its
      // place.
      if (!hasSpaceFor(usedSize + itemSize)) {
        // (₌₄ ₀:1, ₁:2, …, ₃:4)
        if (hasSpaceFor(usedSize + delimiterSize + ellipsisSize)) {
          writeBufferedItem();
          buf
            ..write(delimiterAndEllipsis)
            ..write(delimiter)
            ..write(last);
          return;
        }

        // When even the ellipsis does not fit, take the last added element
        // out: (₌₄ ₀:1, …, ₃:4). With nothing to take out, put the ellipsis
        // in place of the last element instead — only possible for a list
        // of three: (₌₃ ₀:1, …)
        if (bufferedItem == null) {
          buf.write(delimiterAndEllipsis);
          return;
        }

        buf
          ..write(delimiterAndEllipsis)
          ..write(delimiter)
          ..write(last);

        return;
      }

      writeBufferedItem();
      bufferedItem = item;
      usedSize += itemSize;
    }

    writeBufferedItem();
    if (count != displayedCount) {
      buf.write(delimiterAndEllipsis);
    }
    buf
      ..write(delimiter)
      ..write(last);
  }

  static void _addAllIterableItemsToBuf(
    StringBuffer buf,
    Iterable<Object?> iterable, {
    required LogTheme theme,
    required int depth,
    required LogDepthTheme depthTheme,
    required LoggableConfig config,
    required bool showIndexes,
  }) {
    // See the comment in [_addEfficientLengthIterableItemsToBuf]: the index
    // is the position in the original collection, and a drop is a marker
    // rather than a removal.
    String obj2str(int index, Object? obj) {
      final value = _sanitizeChild(index, null, obj);

      return _withSegment(
        index,
        () => objectToString(
          _isDropped(value) ? '<dropped>' : value,
          theme: theme,
          depth: depth + 1,
          config: config,
        ),
      );
    }

    String indexedObj2str(int index, Object? obj) =>
        '${depthTheme.description(theme.formatIndex(index))}'
        '${obj2str(index, obj)}';

    final delimiter = depthTheme.punctuation(', ');
    buf.write(
      iterable.indexed
          .map(
            (item) => showIndexes
                ? indexedObj2str(item.$1, item.$2)
                : obj2str(item.$1, item.$2),
          )
          .join(delimiter),
    );
  }

  /// Converts a collection to a [Map] for further conversion to JSON.
  ///
  /// When the collection is a [List], is kept whole and carries no extra
  /// data, the result comes back as a [List]:
  /// `[a, b, c, d]`.
  ///
  /// In every other case the result comes back as a [Map]:
  ///
  /// ```
  /// {
  ///   ":k": "iterable"/"list"/"set",
  ///   ":l": 4,
  ///   ":v": [a, d],
  ///   ":u": "m"
  /// }
  /// ```
  ///
  /// There the last element of the ":v" list (when ":v" holds more than
  /// one) is the last element of the original collection. That is what lets
  /// an abbreviated collection be shown as:
  /// (₌₄ ₀:a, …, ₃:d),
  ///
  /// Only for collections with an efficient length (a [List] or a [Set],
  /// for instance) and efficient access to the last element. Use
  /// [iterableToJson] for the rest.
  @visibleForTesting
  static Object? efficientLengthIterableToJson(
    Iterable<Object?> iterable, {
    LoggableJsonConfig config = const LoggableJsonConfig(),
  }) =>
      _efficientLengthIterableToJson(iterable, 'iterable', config: config);

  static Object _efficientLengthIterableToJson(
    Iterable<Object?> iterable,
    String type, {
    bool isList = false,
    required LoggableJsonConfig config,
  }) {
    // Units are not passed down to children.
    late final itemConfig = config.copyWith(units: null);

    // Sanitizing an element: the index is the position in the original
    // collection. Sanitize.drop becomes a marker rather than removing the
    // element — otherwise ':l' (the length) and the actual number of
    // elements in ':v' would drift apart.
    Object? obj2json(int index, Object? obj) {
      final value = _sanitizeChild(index, null, obj);

      return _withSegment(
        index,
        () => objectToJson(
          _isDropped(value) ? '<dropped>' : value,
          config: itemConfig,
        ),
      );
    }

    var maxCount = config.resolvedCollectionMaxCount;
    assert(maxCount == null || maxCount >= 0);
    if (maxCount != null && maxCount < 0) {
      maxCount = 0;
    }

    if (maxCount == null || iterable.length <= maxCount) {
      final values =
          iterable.indexed.map((item) => obj2json(item.$1, item.$2)).toList();
      return isList && config.resolvedUnits == null
          ? values
          : {
              _kindKey: type,
              _valueKey: values,
              if (config.resolvedUnits case final units?) _unitsKey: units,
            };
    }

    return {
      _kindKey: type,
      _lengthKey: iterable.length,
      _valueKey: switch (maxCount) {
        0 => <Object>[],
        1 => [obj2json(0, iterable.first)],
        _ => [
            ...iterable
                .take(maxCount - 1)
                .indexed
                .map((item) => obj2json(item.$1, item.$2)),
            obj2json(iterable.length - 1, iterable.last),
          ],
      },
      if (config.resolvedUnits case final units?) _unitsKey: units,
    };
  }

  /// Converts a collection to a string of the form `(₀:first, …)`.
  ///
  /// When the collection holds more elements than
  /// [LoggableConfig.collectionMaxCount], or the string is longer than
  /// [LoggableConfig.collectionMaxStringLength], the result is truncated.
  ///
  /// The method neither computes the collection's length nor touches its
  /// last element, so it suits single-pass [Iterable]s too. Truncation
  /// keeps the leading elements only, followed by an ellipsis. Where the
  /// length and the last element are cheap, use
  /// [efficientLengthIterableToString].
  ///
  /// Throws [ArgumentError] when the count limit is negative, the length
  /// limit is not positive, or the delimiters contain control codes.
  @visibleForTesting
  static String iterableToString(
    Iterable<Object?> iterable, {
    LogTheme theme = LogTheme.noColors,
    int depth = 0,
    String start = '(',
    String end = ')',
    LoggableConfig config = const LoggableConfig(),
  }) {
    final maxCount = config.resolvedCollectionMaxCount;
    final maxLength = config.resolvedCollectionMaxStringLength;

    _validateIterableToStringArguments(
      maxCount: maxCount,
      maxLength: maxLength,
      start: start,
      end: end,
    );

    final depthTheme = theme.depthTheme(depth);

    final buf = StringBuffer(depthTheme.brackets(start));
    final reservedLength = start.length + end.length;

    _addIterableItemsToBuf(
      buf,
      iterable,
      theme: theme,
      depth: depth,
      depthTheme: depthTheme,
      config: config,
      maxCount: maxCount,
      maxLength:
          maxLength == null ? null : math.max(maxLength - reservedLength, 0),
      showIndexes: config.resolvedCollectionShowIndexes,
    );

    buf.write(depthTheme.brackets(end));

    return buf.toString();
  }

  static void _addIterableItemsToBuf(
    StringBuffer buf,
    Iterable<Object?> iterable, {
    required LogTheme theme,
    required int depth,
    required LogDepthTheme depthTheme,
    required LoggableConfig config,
    required int? maxCount,
    required int? maxLength,
    required bool showIndexes,
  }) {
    // See the comment in [_addEfficientLengthIterableItemsToBuf]: the index
    // is the position in the original collection, and a drop is a marker
    // rather than a removal.
    String obj2str(int index, Object? obj) {
      final value = _sanitizeChild(index, null, obj);

      return _withSegment(
        index,
        () => objectToString(
          _isDropped(value) ? '<dropped>' : value,
          theme: theme,
          depth: depth + 1,
          config: config,
        ),
      );
    }

    String index2str(int index) =>
        depthTheme.description(theme.formatIndex(index));

    String indexedObj2str(int index, Object? obj) =>
        '${index2str(index)}${obj2str(index, obj)}';

    bool hasSpaceFor(int len) => maxLength == null || len <= maxLength;

    final ellipsisStr = theme.main.ellipsis;
    late final ellipsis = depthTheme.punctuation(ellipsisStr);
    final ellipsisSize = ellipsisStr.length;

    const delimiterStr = ', ';
    late final delimiter = depthTheme.punctuation(delimiterStr);
    const delimiterSize = delimiterStr.length;

    // With no limits, print every element.
    if (maxLength == null && maxCount == null) {
      _addAllIterableItemsToBuf(
        buf,
        iterable,
        theme: theme,
        depth: depth,
        depthTheme: depthTheme,
        config: config,
        showIndexes: showIndexes,
      );
      return;
    }

    late final delimiterAndEllipsis =
        depthTheme.punctuation('$delimiterStr$ellipsisStr');

    final bufferedItems = <(String, int)>[];
    var isFirst = true;

    void writeBufferedItems() {
      for (final item in bufferedItems) {
        buf.write(item.$1);
        isFirst = false;
      }
      bufferedItems.clear();
    }

    var i = 0;
    var l = 0;
    for (final e in iterable) {
      if (maxCount != null && maxCount <= i) {
        // The count-truncation ellipsis has to fit the length budget as
        // well — take the trailing elements out if need be.
        while (!hasSpaceFor(l + delimiterSize + ellipsisSize) &&
            bufferedItems.isNotEmpty) {
          final lastItem = bufferedItems.removeLast();
          l -= lastItem.$2;
        }

        writeBufferedItems();
        buf.write(isFirst ? ellipsis : delimiterAndEllipsis);
        break;
      }

      var item = showIndexes ? indexedObj2str(i, e) : obj2str(i, e);
      var itemSize = item.lengthWithoutEscapeCodes;
      if (i != 0) {
        item = '$delimiter$item';
        itemSize += delimiterSize;
      }

      // When the next element does not fit, try to put an ellipsis in its
      // place.
      if (!hasSpaceFor(l + itemSize) && itemSize > ellipsisSize) {
        // Keep taking the last element out until the ellipsis fits
        while (!hasSpaceFor(l + delimiterSize + ellipsisSize) &&
            bufferedItems.isNotEmpty) {
          final lstItem = bufferedItems.removeLast();
          l -= lstItem.$2;
        }

        writeBufferedItems();
        buf.write(isFirst ? ellipsis : delimiterAndEllipsis);
        return;
      }

      if (bufferedItems.isNotEmpty && bufferedItems.first.$2 >= ellipsisSize) {
        writeBufferedItems();
      }
      bufferedItems.add((item, itemSize));

      l += itemSize;
      i++;
    }

    if (bufferedItems.isNotEmpty) {
      if (bufferedItems.first.$2 <= ellipsisSize || hasSpaceFor(l)) {
        writeBufferedItems();
      } else {
        buf.write(i == 1 ? ellipsis : delimiterAndEllipsis);
      }
    }
  }

  /// Converts a collection to a [Map] for further conversion to JSON.
  ///
  /// The result comes back as a [Map]:
  /// `{":k": "iterable", ":v": [a, b], ":trim": true, ":u": "m"}`.
  ///
  /// The ":trim" field is present when the collection was truncated; then
  /// the ":v" list holds its leading elements. ":trim" is always `true`, and
  /// it is absent from an untruncated collection.
  ///
  /// Note the difference from [efficientLengthIterableToJson]. Both return a
  /// collection of type "iterable", and for a complete collection the
  /// results match — but for a truncated one
  /// [efficientLengthIterableToJson] returns:
  /// `{":k": "iterable", ":l": 4, ":v": [a, b, d]}`.
  ///
  /// while [iterableToJson] returns:
  /// `{":k": "iterable", ":v": [a, b, c], ":trim": true}`.
  ///
  /// In the first the last item of ":v" is the last element of the original
  /// collection (₌₄ ₀:a, ₁:b, …, ₃:d) and ":l" is that collection's size. In
  /// the second the items of ":v" are the collection's leading elements
  /// (₀:a, ₁:b, ₂:c, …) and ":trim" says the list is not complete.
  /// [iterableToJson] does not compute the collection's length.
  @visibleForTesting
  static Object iterableToJson(
    Iterable<Object?> iterable, {
    LoggableJsonConfig config = const LoggableJsonConfig(),
  }) {
    // Units are not passed down to children.
    late final itemConfig = config.copyWith(units: null);

    // Sanitizing an element: the index is the position in [values]. The
    // method truncates the tail only — it never skips elements from the
    // middle — so that position always matches the one in the original
    // collection.
    Object? obj2json(int index, Object? obj) {
      final value = _sanitizeChild(index, null, obj);

      return _withSegment(
        index,
        () => objectToJson(
          _isDropped(value) ? '<dropped>' : value,
          config: itemConfig,
        ),
      );
    }

    var maxCount = config.resolvedCollectionMaxCount;
    assert(maxCount == null || maxCount >= 0);
    if (maxCount != null && maxCount < 0) {
      maxCount = 0;
    }

    Iterable<Object?> values;
    bool? trimmed;

    if (maxCount == null) {
      values = iterable;
    } else {
      final iterator = iterable.iterator;
      final list = <Object?>[];
      for (var i = 0; i < maxCount; i++) {
        if (!iterator.moveNext()) {
          trimmed = false;
          break;
        }

        list.add(iterator.current);
      }
      values = list;
      trimmed ??= iterator.moveNext();
    }

    return {
      _kindKey: 'iterable',
      _valueKey:
          values.indexed.map((item) => obj2json(item.$1, item.$2)).toList(),
      if (trimmed ?? false) _trimKey: true,
      if (config.resolvedUnits case final units?) _unitsKey: units,
    };
  }

  /// Sanitizes an entry's value by its key; on [Sanitize.drop] it returns
  /// `null` so that [_mapToString] skips the entry entirely.
  ///
  /// The key is rendered EXACTLY once: the resulting text is both what goes
  /// into the output and the path segment carrying the name for the rule.
  /// It used to be drawn twice — a draft `entry.key.toString()` for the
  /// name and once more for the output — and the properties of a
  /// [Loggable] key were offered to the rule under two different paths,
  /// with the SECOND render reaching the output while a path-based rule
  /// masked the first. The draft was also computed unconditionally, before
  /// [_sanitizeChild]'s early exit: with no rule installed the key was
  /// rendered twice, and `toString()` was called where before 0.6.0 it was
  /// not called at all.
  static String? _mapEntryToString(
    MapEntry<Object?, Object?> entry, {
    LogTheme theme = LogTheme.noColors,
    int depth = 0,
    LoggableConfig config = const LoggableConfig(),
  }) {
    final depthTheme = theme.depthTheme(depth);

    final String key;
    final String? name;
    if (entry.key case final String stringKey) {
      key = theme.formatValue(
        stringKey,
        escapeAnsiCodes: config.resolvedEscapeAnsiCodes,
      );
      name = stringKey;
    } else {
      final objectKey = entry.key;
      // The key itself is not offered to the rule (see the [sanitizer]
      // dartdoc), but its contents do pass through the walkers: it is
      // rendered under the guard, or with an empty segment stack the key
      // would enter the walker as a ROOT — and be offered. The guard counts
      // towards neither the path nor the depth, so the key's properties are
      // visible to the rule under the entry's own path.
      key = _withSegment(
        _rootGuardSegment,
        () => objectToString(
          objectKey,
          theme: theme,
          depth: depth + 1,
          config: config,
        ),
      );
      // The name and the segment are data for the rule, not output: the
      // theme's styling is stripped from them. With no rule they are not
      // needed and are not computed.
      name =
          _sanitizing && objectKey != null ? key.ansiRemoveEscapeCodes() : null;
    }

    // The key is rendered in full even when the entry is about to be
    // dropped: the name the rule sees IS the printed key, and the drop
    // decision is made from that name. The order is unavoidable, not an
    // optimization left for later.
    final segment = name ?? 'null';
    final value = _sanitizeChild(segment, name, entry.value);
    if (_isDropped(value)) return null;

    final valueStr = _withSegment(
      segment,
      () => objectToString(
        value,
        depth: depth + 1,
        theme: theme,
        config: config,
      ),
    );

    return '${theme.data.keyStyle(key)}${depthTheme.punctuation(':')}'
        ' ${theme.data.valueStyle(valueStr)}';
  }

  static String _mapToString(
    Map<Object?, Object?> map, {
    LogTheme theme = LogTheme.noColors,
    int depth = 0,
    String start = '{',
    String end = '}',
    LoggableConfig config = const LoggableConfig(),
  }) {
    final maxCount = config.resolvedCollectionMaxCount;
    final maxLength = config.resolvedCollectionMaxStringLength;

    _validateIterableToStringArguments(
      maxCount: maxCount,
      maxLength: maxLength,
      start: start,
      end: end,
    );

    final depthTheme = theme.depthTheme(depth);
    final showCount = config.resolvedCollectionShowCount;

    final buf = StringBuffer(depthTheme.brackets(start));

    // In this mode neither the length nor the last entry is needed.
    if (!showCount && maxCount == null && maxLength == null) {
      var isFirst = true;
      for (final entry in map.entries) {
        final item = _mapEntryToString(
          entry,
          theme: theme,
          depth: depth,
          config: config,
        );
        if (item == null) continue;

        if (!isFirst) buf.write(depthTheme.punctuation(', '));
        buf.write(item);
        isFirst = false;
      }
      buf.write(depthTheme.brackets(end));

      return buf.toString();
    }

    final count = map.length;
    var reservedLength = start.length + end.length;

    if (showCount) {
      final countText = '${theme.formatCount(count)}${count > 0 ? ' ' : ''}';
      reservedLength += countText.length;
      buf.write(depthTheme.description(countText));
    }

    _addMapEntriesToBuf(
      buf,
      map,
      theme: theme,
      depth: depth,
      depthTheme: depthTheme,
      config: config,
      count: count,
      maxCount: maxCount,
      maxLength:
          maxLength == null ? null : math.max(maxLength - reservedLength, 0),
    );

    buf.write(depthTheme.brackets(end));

    return buf.toString();
  }

  /// Writes `Map` entries with the same truncation rules a list follows:
  /// the first entries and the last one take priority, and what is taken
  /// out becomes an ellipsis.
  ///
  /// A separate implementation rather than sharing
  /// [_addEfficientLengthIterableItemsToBuf], because of the sanitizer: in
  /// a list `Sanitize.drop` leaves a `<dropped>` marker and the position is
  /// kept, while in a `Map` the entry disappears completely. So the limit
  /// here counts the **surviving** entries, and the reported length stays
  /// the length of the original `Map` — otherwise entries the rule removed
  /// would leave no trace at all.
  static void _addMapEntriesToBuf(
    StringBuffer buf,
    Map<Object?, Object?> map, {
    required LogTheme theme,
    required int depth,
    required LogDepthTheme depthTheme,
    required LoggableConfig config,
    required int count,
    required int? maxCount,
    required int? maxLength,
  }) {
    String? entry2str(MapEntry<Object?, Object?> entry) => _mapEntryToString(
          entry,
          theme: theme,
          depth: depth,
          config: config,
        );

    bool hasSpaceFor(int len) => maxLength == null || len <= maxLength;

    const delimiterStr = ', ';
    const delimiterSize = delimiterStr.length;
    late final delimiter = depthTheme.punctuation(delimiterStr);

    final ellipsisStr = theme.main.ellipsis;
    final ellipsisSize = ellipsisStr.length;
    late final ellipsis = depthTheme.punctuation(ellipsisStr);
    late final delimiterAndEllipsis =
        depthTheme.punctuation('$delimiterStr$ellipsisStr');

    if (count == 0) return;

    // Not a single entry can be shown: {₌ₙ …}
    if (maxCount != null && maxCount <= 0) {
      buf.write(ellipsis);

      return;
    }

    final iterator = map.entries.iterator;

    /// The next surviving entry, or `null` when there are no more.
    String? nextItem() {
      while (iterator.moveNext()) {
        if (entry2str(iterator.current) case final item?) return item;
      }

      return null;
    }

    final first = nextItem();
    // Everything was struck out by the rule: {₌ₙ}
    if (first == null) return;

    final firstSize = first.lengthWithoutEscapeCodes;
    // The first entry does not fit — show the ellipsis alone, but only
    // when the entry is longer than the ellipsis itself.
    if (!hasSpaceFor(firstSize) && firstSize > ellipsisSize) {
      buf.write(ellipsis);

      return;
    }

    final displayedCount = maxCount == null ? count : math.min(maxCount, count);
    final truncated = displayedCount < count;

    // The tail is rendered lazily: with displayedCount == 1 it is not in
    // the output, and rendering is also sanitizing — the rule would be
    // offered an entry the count limit had already cut off.
    late final last = truncated ? entry2str(map.entries.last) : null;

    if (!truncated) {
      // Show everything that survived, while there is room.
      buf.write(first);
      var usedSize = firstSize;
      for (var item = nextItem(); item != null; item = nextItem()) {
        final itemSize = delimiterSize + item.lengthWithoutEscapeCodes;
        if (!hasSpaceFor(usedSize + itemSize)) {
          if (hasSpaceFor(usedSize + delimiterSize + ellipsisSize)) {
            buf.write(delimiterAndEllipsis);
          }

          return;
        }

        buf
          ..write(delimiter)
          ..write(item);
        usedSize += itemSize;
      }

      return;
    }

    // Room for the ellipsis and the tail is reserved up front: they matter
    // more than the middle.
    var tailSize = delimiterSize + ellipsisSize;
    if (last case final item?) {
      tailSize += delimiterSize + item.lengthWithoutEscapeCodes;
    }

    if (!hasSpaceFor(firstSize + delimiterSize + ellipsisSize)) {
      buf.write(ellipsis);

      return;
    }

    buf.write(first);

    void writeTail() {
      buf.write(delimiterAndEllipsis);
      if (last case final item?) {
        buf
          ..write(delimiter)
          ..write(item);
      }
    }

    // One entry plus an ellipsis: {₌ₙ a: 1, …}
    if (displayedCount == 1 || !hasSpaceFor(firstSize + tailSize)) {
      buf.write(delimiterAndEllipsis);

      return;
    }

    var usedSize = firstSize + tailSize;
    // The middle: the entries between the first one and the tail, while
    // there is room.
    for (var shown = 1; shown < displayedCount - 1; shown++) {
      final item = nextItem();
      if (item == null) break;

      final itemSize = delimiterSize + item.lengthWithoutEscapeCodes;
      if (!hasSpaceFor(usedSize + itemSize)) break;

      buf
        ..write(delimiter)
        ..write(item);
      usedSize += itemSize;
    }

    writeTail();
  }

  static Map<String, Object?> _mapToJson(
    Map<Object?, Object?> map, {
    LoggableJsonConfig config = const LoggableJsonConfig(),
  }) {
    // Units are not passed down to children.
    late final itemConfig = config.copyWith(units: null);

    // Collected with a loop rather than map.map, so that entries sanitized
    // down to Sanitize.drop can be skipped.
    final result = <String, Object?>{};

    /// Puts an entry into [result]; `false` means the rule struck it
    /// out.
    bool addEntry(MapEntry<Object?, Object?> entry) {
      // The key is rendered once (see [_mapEntryToString]): its text is
      // both the JSON key and the path segment carrying the name for the
      // rule.
      final String? name;
      if (entry.key case final String stringKey) {
        name = stringKey;
      } else if (entry.key case final objectKey?) {
        // A key's `toString` may enter the walkers ([Loggable],
        // [LoggableData], [LoggableWrapper], [LoggableMultiData]): under
        // the guard the key will not be offered to the rule as a root.
        name = _withSegment(_rootGuardSegment, objectKey.toString);
      } else {
        name = null;
      }

      final segment = name ?? 'null';
      final value = _sanitizeChild(segment, name, entry.value);
      if (_isDropped(value)) return false;

      final jsonKey = _escapeServiceKey(segment);
      if (result.containsKey(jsonKey)) {
        throw ArgumentError('Map keys must have unique JSON representations');
      }

      result[jsonKey] = _withSegment(
        segment,
        () => objectToJson(value, config: itemConfig),
      );

      return true;
    }

    final count = map.length;
    final maxCount = config.resolvedCollectionMaxCount;

    // A whole `Map` stays an ordinary JSON object — only truncation
    // changes the shape, exactly as for a list (see [listToJson]).
    if (maxCount == null || count <= maxCount) {
      map.entries.forEach(addEntry);

      return switch (config.resolvedUnits) {
        null => result,
        final units => {...result, _unitsKey: units}
      };
    }

    // The same priority as in the string output: the first entries and the
    // last one. The limit counts the surviving entries, and `:l` stays the
    // length of the original `Map`.
    if (maxCount > 0) {
      final iterator = map.entries.iterator;
      var shown = 0;
      while (shown < maxCount - 1 && iterator.moveNext()) {
        if (addEntry(iterator.current)) shown++;
      }

      if (maxCount > 1) addEntry(map.entries.last);
    }

    return {
      _kindKey: 'map',
      _lengthKey: count,
      _valueKey: result,
      if (config.resolvedUnits case final units?) _unitsKey: units,
    };
  }

  static String _enumToString(
    Enum obj, {
    LogTheme theme = LogTheme.noColors,
    LoggableConfig config = const LoggableConfig(),
  }) {
    final dotShorthand = '.${theme.formatValue(
      obj.name,
      escapeAnsiCodes: config.resolvedEscapeAnsiCodes,
    )}';
    return config.resolvedEnumDotShorthand
        ? dotShorthand
        : '${obj.runtimeType}${theme.data.emphasis(dotShorthand)}';
  }

  /// Converts an Enum to a [Map] for further conversion to JSON.
  ///
  /// The result comes back as:

  static Map<String, Object?> _enumToJson(
    Enum obj, {
    LoggableJsonConfig config = const LoggableJsonConfig(),
  }) =>
      {
        _classKey: obj.runtimeType.toString(),
        _valueKey: obj.name,
      };

  static Map<String, Object?> _dateTimeToJson(DateTime obj) => {
        _kindKey: 'datetime',
        _valueKey: obj.toIso8601String(),
      };

  static Map<String, Object?> _durationToJson(Duration obj) => {
        _kindKey: 'duration',
        _valueKey: obj.toString(),
      };

  static String _intToString(
    int obj, {
    LogTheme theme = LogTheme.noColors,
    LoggableConfig config = const LoggableConfig(),
  }) =>
      '${switch (config.resolvedIntFormat) {
        null => obj.toString(),
        final f => theme.formatNumber(obj, f),
      }}'
      '${unitsToString(config.resolvedUnits, theme)}';

  static String _doubleToString(
    double obj, {
    LogTheme theme = LogTheme.noColors,
    LoggableConfig config = const LoggableConfig(),
  }) {
    if (obj.isFinite) {
      return '${switch (config.resolvedDoubleFormat) {
        null => obj.toString(),
        final f => theme.formatNumber(obj, f),
      }}'
          '${unitsToString(config.resolvedUnits, theme)}';
    }

    // See the comment in [_doubleToJson]: units are not shown for
    // nan/inf.
    return obj.isNaN
        ? 'nan'
        : obj.isNegative
            ? '-inf'
            : 'inf';
  }

  static Object _intToJson(
    int obj, {
    LoggableJsonConfig config = const LoggableJsonConfig(),
  }) =>
      switch (config.resolvedUnits) {
        null => obj,
        final units => {
            _valueKey: obj,
            _unitsKey: units,
          },
      };

  static Object _doubleToJson(
    double obj, {
    LoggableJsonConfig config = const LoggableJsonConfig(),
  }) {
    if (obj.isFinite) {
      if (config.resolvedUnits case final units?) {
        return {_valueKey: obj, _unitsKey: units};
      }

      return obj;
    }

    // Units are a purely visual thing: for nan/inf they are shown neither
    // in the string nor in JSON.
    return {
      _kindKey: 'double',
      _valueKey: obj.isNaN
          ? 'nan'
          : obj.isNegative
              ? '-inf'
              : 'inf',
    };
  }

  static String _stringToString(
    String obj, {
    LogTheme theme = LogTheme.noColors,
    LoggableConfig config = const LoggableConfig(),
  }) {
    final stringInQuotes = config.resolvedStringInQuotes;
    final escapeAnsiCodes = config.resolvedEscapeAnsiCodes;

    return stringInQuotes
        ? '${theme.styledOpeningQuote}'
            '${theme.formatValue(obj, escapeAnsiCodes: escapeAnsiCodes)}'
            '${theme.styledClosingQuote}'
        : theme.formatValue(obj, escapeAnsiCodes: escapeAnsiCodes);
  }

  static String _dateTimeToString(
    DateTime obj, {
    LogTheme theme = LogTheme.noColors,
  }) =>
      theme.formatValue(
        obj.toIso8601String(),
        // The date is assembled by the package and holds no untrusted
        // text; the application layers are still asked, so that there is
        // one policy.
        escapeAnsiCodes: LoggableConfig.appEscapeAnsiCodes,
      );

  static String unitsToString(
    String? units,
    LogTheme theme,
  ) =>
      units == null
          ? ''
          : theme.data.unitsStyle(
              theme.formatValue(
                units,
                // Units are written by the developer in the config, not
                // by outside input.
                escapeAnsiCodes: LoggableConfig.appEscapeAnsiCodes,
              ),
            );
}

final class LoggableWrapper {
  final Object? data;
  final LoggableConfig config;

  LoggableWrapper(
    this.data, {
    this.config = const LoggableConfig(),
  });

  Object? toJson({
    LoggableJsonConfig config = const LoggableJsonConfig(),
  }) =>
      Loggable.objectToJson(
        data,
        config: this.config.mergeWithJsonConfig(config),
      );

  @override
  String toString() => Loggable.objectToString(data, config: config);
}

/// A converter from a third-party type [T] to [LoggableData].
///
/// The library calls only [convertToData]; the [LoggableData] it returns
/// knows how to render itself both as a string and as JSON. A converter is
/// matched strictly by `runtimeType` — it does not apply to subtypes of
/// [T].
abstract interface class LoggableTypeConverter<T extends Object?> {
  LoggableData convertToData(T obj);
}

abstract interface class LoggableView {
  const factory LoggableView(Object? value, {String? units}) = _LoggableView;

  static LoggableView convert<T extends Object>(
    Object Function(T value, LogTheme theme, int depth) converter, {
    String? units,
  }) =>
      _LoggableViewConvert<T>(converter, units);

  Object? toJson(Object? value);

  String toLogString(
    Object? value, {
    LogTheme theme = LogTheme.noColors,
    int depth = 0,
  });
}

final class _LoggableView implements LoggableView {
  final Object? value;
  final String? units;

  const _LoggableView(this.value, {this.units});

  /// The passed value is ignored; the one set earlier is used.
  @override
  Object? toJson(Object? _) {
    final v = value;

    return switch (v) {
      null => null,
      bool() || num() => switch (units) {
          null => v,
          final units => {
              Loggable._valueKey: v,
              Loggable._unitsKey: units,
            }
        },
      _ => {
          Loggable._viewKey: v.toString(),
          if (units case final units?) Loggable._unitsKey: units,
        },
    };
  }

  /// The passed value is ignored; the one set earlier is used.
  @override
  String toLogString(
    Object? value, {
    LogTheme theme = LogTheme.noColors,
    int depth = 0,
  }) =>
      switch (this.value) {
        null => 'null',
        // The package interpolates the value, so the package disarms it
        // too: the text a view assembles counts as already rendered, and
        // the mode is off there (see `Prop.toLogString`).
        final value => '${theme.formatValue(
            '$value',
            escapeAnsiCodes: LoggableConfig.appEscapeAnsiCodes,
          )}${Loggable.unitsToString(units, theme)}',
      };
}

final class _LoggableViewConvert<T extends Object> implements LoggableView {
  final Object Function(T value, LogTheme theme, int depth) converter;
  final String? units;

  _LoggableViewConvert(this.converter, this.units);

  @override
  Object? toJson(Object? value) {
    switch (value) {
      case null:
        return null;

      case T():
        final v = converter(value, LogTheme.noColors, 0);

        return switch (v) {
          bool() || num() => switch (units) {
              null => v,
              final units => {
                  Loggable._valueKey: v,
                  Loggable._unitsKey: units,
                },
            },
          final _ => {
              Loggable._viewKey: v.toString(),
              if (units case final units?) Loggable._unitsKey: units,
            },
        };

      default:
        throw ArgumentError.value(value, 'value');
    }
  }

  @override
  String toLogString(
    Object? value, {
    LogTheme theme = LogTheme.noColors,
    int depth = 0,
  }) =>
      switch (value) {
        null => 'null',
        T() => '${converter(value, theme, depth)}'
            '${Loggable.unitsToString(units, theme)}',
        _ => throw ArgumentError.value(value, 'value'),
      };
}

final class LoggableMultiView implements LoggableView {
  final List<LoggableView> views;
  final String separator;

  const LoggableMultiView(this.views, {this.separator = '/'});

  @override
  Object? toJson(Object? value) => {
        Loggable._kindKey: 'multi-view',
        Loggable._valueKey: [for (final view in views) view.toJson(value)],
      };

  @override
  String toLogString(
    Object? value, {
    LogTheme theme = LogTheme.noColors,
    int depth = 0,
  }) {
    final depthTheme = theme.depthTheme(depth);

    return views
        .map(
          (e) => e.toLogString(
            value,
            theme: theme,
            depth: depth,
          ),
        )
        .join(depthTheme.punctuation(separator));
  }
}

void _validateIterableToStringArguments({
  required int? maxCount,
  required int? maxLength,
  required String start,
  required String end,
}) {
  if (maxCount != null && maxCount < 0) {
    throw ArgumentError.value(
      maxCount,
      'config.collectionMaxCount',
      'Must not be negative',
    );
  }
  if (maxLength != null && maxLength <= 0) {
    throw ArgumentError.value(
      maxLength,
      'config.collectionMaxStringLength',
      'Must be positive',
    );
  }
  if (_hasControlCode(start)) {
    throw ArgumentError.value(
      start,
      'start',
      'Must not contain ANSI escape or control codes',
    );
  }
  if (_hasControlCode(end)) {
    throw ArgumentError.value(
      end,
      'end',
      'Must not contain ANSI escape or control codes',
    );
  }
}

bool _hasControlCode(String value) {
  for (var i = 0; i < value.length; i++) {
    final codeUnit = value.codeUnitAt(i);
    if (codeUnit <= 0x1F || codeUnit >= 0x7F && codeUnit <= 0x9F) {
      return true;
    }
  }

  return false;
}
