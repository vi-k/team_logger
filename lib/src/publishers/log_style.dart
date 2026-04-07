import 'package:ansi_escape_codes/style.dart' as ansi;

import '../logger/log_levels.dart';

final class LogStyle {
  final ansi.Style verbose;
  final ansi.Style debug;
  final ansi.Style info;
  final ansi.Style warning;
  final ansi.Style error;
  final ansi.Style critical;

  const LogStyle({
    required this.verbose,
    required this.debug,
    required this.info,
    required this.warning,
    required this.error,
    required this.critical,
  });

  const LogStyle.oneForAll(ansi.Style style)
      : this(
          verbose: style,
          debug: style,
          info: style,
          warning: style,
          error: style,
          critical: style,
        );

  static const LogStyle defaultStyle = LogStyle.oneForAll(ansi.Style.defaults);

  ansi.Style operator [](int level) => switch (level) {
        LogLevels.verbose => verbose,
        LogLevels.debug => debug,
        LogLevels.info => info,
        LogLevels.warning => warning,
        LogLevels.error => error,
        LogLevels.critical => critical,
        _ => throw Exception('Unknown log level: $level'),
      };

  LogStyle copyWith({
    ansi.Style? verbose,
    ansi.Style? debug,
    ansi.Style? info,
    ansi.Style? warning,
    ansi.Style? error,
    ansi.Style? critical,
  }) =>
      LogStyle(
        verbose: verbose ?? this.verbose,
        debug: debug ?? this.debug,
        info: info ?? this.info,
        warning: warning ?? this.warning,
        error: error ?? this.error,
        critical: critical ?? this.critical,
      );

  @override
  String toString() => 'LogStyle('
      'verbose: $verbose'
      ', debug: $debug'
      ', info: $info'
      ', warning: $warning'
      ', error: $error'
      ', critical: $critical'
      ')';
}
