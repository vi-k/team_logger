import 'dart:async';

import 'package:clock/clock.dart';
import 'package:logger_builder/logger_builder.dart';

import 'log_levels.dart';
import 'trace_id.dart';

part 'log.dart';

typedef LogFn = bool Function(
  Object message, {
  TraceId? traceId,
  Object? data,
  Object? tags,
  String? overridePath,
  Object? error,
  StackTrace? stackTrace,
  Zone? zone,
});

final class LevelLogger
    extends CustomLevelLogger<Logger, LevelLogger, LogFn, Log> {
  LevelLogger({required super.level, required super.name, super.shortName})
      : super(
          noLog: (
            _, {
            traceId,
            data = _noData,
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
        data = _noData,
        tags,
        overridePath,
        error,
        stackTrace,
        zone,
      }) {
        final currentTraceIds = logger.currentTraceIds;
        final newTraceIds =
            traceId == null ? currentTraceIds : [...currentTraceIds, traceId];
        for (final traceId in newTraceIds) {
          traceId.resolve();
        }

        publisher.publish(
          Log(
            this,
            path: overridePath ?? logger._lazyPath.value,
            traceIds: traceId == null
                ? currentTraceIds
                : [...currentTraceIds, traceId],
            message: LazyString(message, '').value,
            data: Lazy(data).resolved,
            tags: {...logger.tags, ...LazyTags(tags).value},
            error: error,
            stackTrace: stackTrace,
            zone: zone,
          ),
        );

        return true;
      };
}

final class Logger extends CustomLogger<Logger, LevelLogger, LogFn, Log> {
  final LazyString _lazyPath;
  final String pathSeparator;
  final Set<String> tags;

  Logger(
    Object name, {
    this.pathSeparator = '/',
    this.tags = const {},
  }) : _lazyPath = LazyString(name);

  Logger._sub(
    super.parent,
    Object name, {
    required bool keepPath,
    this.tags = const {},
  })  : _lazyPath = keepPath
            ? LazyString(
                () => '${parent.path}'
                    '${parent.pathSeparator}'
                    '${LazyString(name).value}',
              )
            : LazyString(name, ''),
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

  final LevelLogger _v = LevelLogger(level: LogLevels.verbose, name: 'verbose');
  final LevelLogger _d = LevelLogger(level: LogLevels.debug, name: 'debug');
  final LevelLogger _i = LevelLogger(level: LogLevels.info, name: 'info');
  final LevelLogger _w = LevelLogger(level: LogLevels.warning, name: 'warning');
  final LevelLogger _e = LevelLogger(level: LogLevels.error, name: 'error');
  final LevelLogger _critical = LevelLogger(
    level: LogLevels.critical,
    name: 'critical',
    shortName: '!',
  );

  LogFn get v => _v.log;
  LogFn get d => _d.log;
  LogFn get i => _i.log;
  LogFn get w => _w.log;
  LogFn get e => _e.log;
  LogFn get critical => _critical.log;

  T trace<T extends Object?>(TraceId traceId, T Function() fn) => runZoned(
        fn,
        zoneValues: {
          TraceId: [...currentTraceIds, traceId],
        },
      );

  List<TraceId> get currentTraceIds => switch (Zone.current[TraceId]) {
        final List<TraceId> list => list,
        _ => const <TraceId>[],
      };
}
