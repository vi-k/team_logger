import 'dart:async';

import 'package:logger_builder/logger_builder.dart';

import 'log.dart';
import 'log_levels.dart';

typedef LogFn = bool Function(
  Object message, {
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
            data,
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
        data,
        tags,
        overridePath,
        error,
        stackTrace,
        zone,
      }) {
        publisher.publish(
          Log(
            this,
            path: overridePath == null
                ? logger._lazyPath
                : LazyString(overridePath),
            message: message,
            data: data,
            tags: tags,
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

  Logger(Object name, {this.pathSeparator = '/'})
      : _lazyPath = LazyString(name);

  Logger._sub(super.parent, Object name, {required bool copyPath})
      : _lazyPath = copyPath
            ? LazyString(
                () => '${parent.path}'
                    '${parent.pathSeparator}'
                    '${LazyString(name).value}',
              )
            : LazyString(name),
        pathSeparator = parent.pathSeparator,
        super.sub();

  String get path => _lazyPath.value;

  Logger withAddedName(Object name) => Logger._sub(this, name, copyPath: true);

  Logger withChangedName(Object name) =>
      Logger._sub(this, name, copyPath: false);

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
  );

  LogFn get v => _v.log;
  LogFn get d => _d.log;
  LogFn get i => _i.log;
  LogFn get w => _w.log;
  LogFn get e => _e.log;
  LogFn get critical => _critical.log;
}
