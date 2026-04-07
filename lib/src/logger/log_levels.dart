import 'package:logger_builder/logger_builder.dart';

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
}
