import 'dart:async';
import 'dart:collection';

import 'package:clock/clock.dart';
import 'package:logger_builder/logger_builder.dart';
import 'package:meta/meta.dart';

import '../loggable/loggable.dart';
import '../loggable/loggable_config.dart';
import 'log_levels.dart';
import 'trace_id.dart';

part 'log.dart';

typedef LogFn = bool Function(
  Object message, {
  TraceId? traceId,
  Object? data,
  LoggableConfig? config,
  Object? tags,
  String? overridePath,
  Object? error,
  StackTrace? stackTrace,
  Zone? zone,
});

/// A single level of a [Logger] (verbose/debug/info/warning/error/critical).
///
/// The call always returns `true`, whether the log was published or
/// filtered out.
final class LevelLogger
    extends CustomLevelLogger<Logger, LevelLogger, LogFn, Log> {
  LevelLogger({required super.level, required super.name, super.shortName})
      : super(
          noLog: (
            _, {
            traceId,
            data = Log.noData,
            config,
            tags,
            overridePath,
            error,
            stackTrace,
            zone,
          }) =>
              true,
        );

  @override
  LogFn get processLog => (
        message, {
        traceId,
        data = Log.noData,
        config,
        tags,
        overridePath,
        error,
        stackTrace,
        zone,
      }) {
        final zonedTraceIds = Logger.zonedTraceIds(zone);
        final logTraceIds = [...zonedTraceIds, if (traceId != null) traceId];
        for (final traceId in logTraceIds) {
          traceId.resolve();
        }

        var resolvedData = Lazy(data).resolved;
        if (config != null && resolvedData is! LogNoData) {
          resolvedData = Loggable.from(resolvedData, config: config);
        }

        publishLog(
          Log(
            this,
            path: overridePath ?? logger._lazyPath.value,
            traceIds: logTraceIds,
            // The message is outside the sanitizer's documented scope,
            // so the library's own `toString()` on it is suppressed (see
            // [_GuardedLazyString]). Interpolation the CALLER did —
            // `log.i('$obj')` — happened before this point and stays
            // affected: it is not our `toString()` call.
            message: _GuardedLazyString(message, '').value,
            data: resolvedData,
            tags: {
              ...Logger.zonedTags(zone),
              ...logger.tags,
              ...LazyTags(tags).value,
            },
            error: error,
            stackTrace: stackTrace,
            zone: zone,
          ),
        );

        return true;
      };
}

/// A namespace logger.
///
/// Use [createChild] to build path hierarchies (`app/network`), [copyWith]
/// to clone the logger without extending the path. Each level is exposed as
/// a call: [v]/[d]/[i]/[w]/[e]/[critical]. Sub-loggers stay linked to the
/// parent: changing the parent's `level` or `publisher` affects children
/// until they override it; the [tags] set is shared by reference.
///
/// [trace] runs a callback inside a Dart [Zone] whose values accumulate
/// trace ids and tags — any log emitted in that async scope picks them up.
///
/// Contract notes: message/data/tags closures are resolved lazily and only
/// for enabled levels; an exception thrown by such a closure propagates to
/// the log call site. Every constructed log consumes a global [Log.num]
/// (isolates have independent counters).
///
/// [transformer] is applied to every log right before publishing —
/// mask secrets/PII or drop logs entirely (see [LogTransformer]); it is
/// inherited by subloggers the same way as `level` and `publisher`.
/// Write transformers with [Log.copyWith] — it preserves the log's
/// number and time. Do not log through the same logger from inside a
/// transformer: the reentrancy guard drops the nested log and reports a
/// [StateError] to `onError` (or to the current zone, with no handler set).
///
/// For per-value redaction inside `data` — nested objects, maps,
/// collections — use [Loggable.sanitizer] instead: it is offered every
/// value on its way to the output, each with its own name and path,
/// rather than the log as a whole.
final class Logger extends CustomLogger<Logger, LevelLogger, LogFn, Log> {
  static const _tagsKey = #team_logger_tags;

  // The namespace name is outside the sanitizer's documented scope, and
  // the resolved path is memoized here and used for `activeNamespaces`
  // filtering — so the library's `toString()` on the name is suppressed
  // (see [_GuardedLazyString]). The outer lazy of a kept path stays a
  // plain LazyString: its own closure always returns a String, so it
  // never converts anything — the name inside it does.
  final TypedLazy<String> _lazyPath;
  final String pathSeparator;
  final Set<String> tags;

  Logger(
    Object name, {
    this.pathSeparator = '/',
    this.tags = const {},
  }) : _lazyPath = _GuardedLazyString(name);

  Logger._sub(
    super.parent,
    Object name, {
    required bool keepPath,
    this.tags = const {},
  })  : _lazyPath = keepPath
            ? LazyString(
                () => '${parent.path}'
                    '${parent.pathSeparator}'
                    '${_GuardedLazyString(name).value}',
              )
            : _GuardedLazyString(name, ''),
        pathSeparator = parent.pathSeparator,
        super.sub();

  String get path => _lazyPath.value;

  Logger copyWith({
    Object? name,
    Set<String>? tags,
  }) =>
      Logger._sub(
        this,
        name ?? path,
        keepPath: false,
        tags: tags ?? this.tags,
      );

  Logger createChild({
    required Object name,
    Set<String> tags = const {},
  }) =>
      Logger._sub(
        this,
        name,
        keepPath: true,
        tags: {...this.tags, ...tags},
      );

  @override
  void registerLevels() {
    registerLevel(_v);
    registerLevel(_d);
    registerLevel(_i);
    registerLevel(_w);
    registerLevel(_e);
    registerLevel(_critical);
  }

  final LevelLogger _v = LevelLogger(
    level: LogLevels.verbose,
    name: LogLevels.name(LogLevels.verbose),
    shortName: LogLevels.shortName(LogLevels.verbose),
  );
  final LevelLogger _d = LevelLogger(
    level: LogLevels.debug,
    name: LogLevels.name(LogLevels.debug),
    shortName: LogLevels.shortName(LogLevels.debug),
  );
  final LevelLogger _i = LevelLogger(
    level: LogLevels.info,
    name: LogLevels.name(LogLevels.info),
    shortName: LogLevels.shortName(LogLevels.info),
  );
  final LevelLogger _w = LevelLogger(
    level: LogLevels.warning,
    name: LogLevels.name(LogLevels.warning),
    shortName: LogLevels.shortName(LogLevels.warning),
  );
  final LevelLogger _e = LevelLogger(
    level: LogLevels.error,
    name: LogLevels.name(LogLevels.error),
    shortName: LogLevels.shortName(LogLevels.error),
  );
  final LevelLogger _critical = LevelLogger(
    level: LogLevels.critical,
    name: LogLevels.name(LogLevels.critical),
    shortName: LogLevels.shortName(LogLevels.critical),
  );

  LogFn get v => _v.log;
  LogFn get d => _d.log;
  LogFn get i => _i.log;
  LogFn get w => _w.log;
  LogFn get e => _e.log;
  LogFn get critical => _critical.log;

  T trace<T extends Object?>(
    TraceId traceId,
    T Function() fn, {
    Zone? zone,
    Set<String> tags = const {},
  }) =>
      (zone ?? Zone.current).run(
        () => runZoned(
          fn,
          zoneValues: {
            TraceId: [...zonedTraceIds(), traceId],
            _tagsKey: {...zonedTags(), ...tags},
          },
        ),
      );

  static List<TraceId> zonedTraceIds([Zone? zone]) =>
      switch ((zone ?? Zone.current)[TraceId]) {
        // Отдаём view, а не сам список зоны: мутация снаружи ломала бы
        // трассировку всех логов этой зоны.
        final List<TraceId> list => UnmodifiableListView(list),
        _ => const <TraceId>[],
      };

  static Set<String> zonedTags([Zone? zone]) =>
      switch ((zone ?? Zone.current)[_tagsKey]) {
        final Set<String> list => list,
        _ => const <String>{},
      };
}
