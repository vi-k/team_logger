import 'package:logger_builder/logger_builder.dart';

// ignore: avoid_classes_with_only_static_members
abstract final class LogLevels {
  static const int all = Levels.all;

  static const int verbose = Levels.verbose;
  static const int debug = Levels.debug;
  static const int info = Levels.info;
  static const int warning = Levels.warning;
  static const int error = Levels.error;
  static const int critical = Levels.critical;

  static const int off = Levels.off;

  static const List<int> values = [
    verbose,
    debug,
    info,
    warning,
    error,
    critical,
  ];

  static String name(int level) => switch (level) {
        all => 'all',
        verbose => 'verbose',
        debug => 'debug',
        info => 'info',
        warning => 'warning',
        error => 'error',
        critical => 'critical',
        off => 'off',
        _ => '$level',
      };

  static String shortName(int level) => switch (level) {
        all => 'all',
        verbose => 'v',
        debug => 'd',
        info => 'i',
        warning => 'w',
        error => 'e',
        critical => '!',
        off => 'off',
        _ => '$level',
      };
}
