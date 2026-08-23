part of 'logger.dart';

final class LogNoData {
  const LogNoData._();

  @override
  String toString() => '<no data>';
}

final class _Unset {
  const _Unset._();
}

/// An immutable record of a single log call: sequence number, timestamp,
/// namespace path, message, resolved data, tags, trace ids, error and
/// stack trace.
///
/// [tags] and [traceIds] are unmodifiable snapshots. Mutating collections
/// passed to the constructor or [copyWith] cannot change an existing log.
///
/// [num] grows monotonically per isolate; logs filtered out by publishers
/// still consume numbers, so gaps are normal.
final class Log extends CustomLog with Loggable {
  @visibleForTesting
  static int lastNum = 0;
  static const noData = LogNoData._();

  final DateTime time;
  final int num;
  final String path;
  final List<TraceId> traceIds;
  final String message;
  final Object? data;
  final Set<String> tags;

  Log(
    super.levelLogger, {
    required this.path,
    required List<TraceId> traceIds,
    required this.message,
    required this.data,
    required Set<String> tags,
    super.error,
    super.stackTrace,
    super.zone,
  })  : traceIds = List<TraceId>.unmodifiable(traceIds),
        tags = Set<String>.unmodifiable(tags),
        num = ++lastNum,
        time = clock.now();

  /// Takes exclusive ownership of collections built for one log event.
  ///
  /// The normal logger path creates fresh collections and retains no mutable
  /// aliases, so unmodifiable views avoid an additional element-by-element
  /// copy. Empty collections reuse canonical constants.
  Log._owned(
    super.levelLogger, {
    required this.path,
    required List<TraceId> traceIds,
    required this.message,
    required this.data,
    required Set<String> tags,
    super.error,
    super.stackTrace,
    super.zone,
  })  : traceIds = traceIds.isEmpty
            ? const <TraceId>[]
            : UnmodifiableListView<TraceId>(traceIds),
        tags =
            tags.isEmpty ? const <String>{} : UnmodifiableSetView<String>(tags),
        num = ++lastNum,
        time = clock.now();

  static const _unset = _Unset._();

  // `original` must stay typed as `Log` (for `.num`/`.time` below), so it
  // can't become a super parameter without widening to `CustomLog`.
  // ignore: use_super_parameters
  Log._copy(
    Log original, {
    required this.path,
    required this.traceIds,
    required this.message,
    required this.data,
    required this.tags,
    required Object? error,
    required StackTrace? stackTrace,
  })  : num = original.num,
        time = original.time,
        super.copy(original, error: error, stackTrace: stackTrace);

  /// Creates a copy of this log with the given fields replaced.
  ///
  /// The copy keeps the log's identity: [num], [time], the level and
  /// [zone] are always preserved — no new sequence number is consumed.
  /// This is the intended building block for [LogTransformer]s (masking
  /// secrets/PII); constructing a `Log` with the main constructor inside
  /// a transformer would mint a new number and time instead.
  ///
  /// Omitted parameters keep the original values. Fields where `null` is
  /// a meaningful value use an internal sentinel as the default, so
  /// `copyWith(error: null)` really clears the error (and
  /// `stackTrace: null` — the stack trace, which is NOT re-derived from
  /// [error]); `data: Log.noData` clears the data. Collections are
  /// cleared with empty values (`tags: {}`, `traceIds: []`).
  /// Replaced collections are snapshotted once; omitted collections reuse
  /// the existing immutable snapshots without copying.
  /// [stackTrace], when passed, must be a [StackTrace] or `null`.
  Log copyWith({
    String? message,
    Object? data = _unset,
    Set<String>? tags,
    Object? error = _unset,
    Object? stackTrace = _unset,
    String? path,
    List<TraceId>? traceIds,
  }) =>
      Log._copy(
        this,
        path: path ?? this.path,
        traceIds: traceIds == null || identical(traceIds, this.traceIds)
            ? this.traceIds
            : List<TraceId>.unmodifiable(traceIds),
        message: message ?? this.message,
        data: identical(data, _unset) ? this.data : data,
        tags: tags == null || identical(tags, this.tags)
            ? this.tags
            : Set<String>.unmodifiable(tags),
        error: identical(error, _unset) ? this.error : error,
        stackTrace: identical(stackTrace, _unset)
            ? this.stackTrace
            : stackTrace as StackTrace?,
      );

  bool get hasData => data is! LogNoData;

  Set<String?> get traceIdGroups => traceIds.map((e) => e.group).toSet();

  @override
  void collectLoggableData(LoggableData data) {
    data
      ..prop('num', num)
      ..prop('level', level, view: levelName)
      ..prop('time', time)
      ..prop('path', path);

    if (traceIds.isNotEmpty) {
      data.prop('traceIds', traceIds);
    }
    data.prop('message', message);

    if (tags.isNotEmpty) {
      data.prop('tags', tags);
    }
    if (hasData) {
      data.computed('hasData', true);
    }
    if (error != null) {
      data.computed('hasError', true);
    }
    if (stackTrace != null) {
      data.computed('hasStackTrace', true);
    }
  }
}

final class LazyTags extends TypedLazy<Set<String>> {
  LazyTags(super.unresolved);

  LazyTags.resolved(super.resolved) : super.resolved();

  /// The whole conversion runs outside the sanitizer's scope.
  ///
  /// Tags are not in that scope (it covers values inside `data` only), and
  /// [Log.tags] is not a render at all: the set is cached in the log, feeds
  /// the `activeTags` filter, and is what publishers that draw nothing see.
  /// Diagnosing an invalid value belongs here too: a rule must not mask the
  /// very value an exception is complaining about.
  ///
  /// A lazy value has already been resolved by this point (`TypedLazy.value`
  /// does it), so the user's closure runs OUTSIDE the suppression — only the
  /// library's own `toString()` is suppressed.
  @override
  Set<String> convert(Object? resolved) => Loggable.renderOutsideSanitizerScope(
        () => switch (resolved) {
          null => const {},
          String() => {resolved},
          // Element types are checked one by one: Iterable<String>()
          // matches only collections typed as strings, and a List<Object>
          // holding strings would then break the logging call.
          Iterable<Object?>() => {
              for (final tag in resolved)
                if (tag != null) tag.toString(),
            },
          _ => throw Exception('Invalid tags: $resolved'),
        },
      );
}

/// A `LazyString` whose `toString()` runs OUTSIDE the sanitizer's scope.
///
/// Needed for values the library turns into strings itself but which are
/// not part of `data`: the log message and the namespace name (see
/// [Loggable.sanitizer]). Without it a `depth == 0` rule would erase the
/// log's text, and the path — memoized in [Logger] and used by the
/// `activeNamespaces` filter — would stay masked for the rest of the
/// process.
///
/// The suppression sits in [convert] rather than around reading `value`:
/// by then the value is already resolved (`TypedLazy.value` reads
/// `resolved` first), so the user's closure runs outside it — if that
/// closure renders something itself, the sanitizer works there as usual.
/// [convert] never sees an already-built string: `TypedLazy` calls it only
/// when the type did not match.
final class _GuardedLazyString extends TypedLazy<String> {
  final String fallbackValue;

  _GuardedLazyString(super.unresolved, [this.fallbackValue = 'null']);

  @override
  String convert(Object? resolved) => Loggable.renderOutsideSanitizerScope(
        () => resolved?.toString() ?? fallbackValue,
      );
}
