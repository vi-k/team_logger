part of 'log_theme.dart';

final class LogStyle with Loggable {
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

  const LogStyle.only(
    ansi.Style style, {
    ansi.Style? verbose,
    ansi.Style? debug,
    ansi.Style? info,
    ansi.Style? warning,
    ansi.Style? error,
    ansi.Style? critical,
  }) : this(
          verbose: verbose ?? style,
          debug: debug ?? style,
          info: info ?? style,
          warning: warning ?? style,
          error: error ?? style,
          critical: critical ?? style,
        );

  static const LogStyle noColors = LogStyle.only(ansi.NoStyle());

  static const LogStyle terminalColors =
      LogStyle.only(ansi.Style.terminalColors);

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
  String toString() => '$LogStyle('
      'verbose: $verbose'
      ', debug: $debug'
      ', info: $info'
      ', warning: $warning'
      ', error: $error'
      ', critical: $critical'
      ')';

  @override
  void collectLoggableData(LoggableData data) {
    if (this == LogStyle.noColors) {
      data
        ..name = '$LogStyle.noColors'
        ..showBrackets = false;
      return;
    }

    final same = verbose == debug &&
        debug == info &&
        info == warning &&
        warning == error &&
        error == critical;

    if (same) {
      data
        ..name = '$LogStyle.only'
        ..prop('style', verbose, showName: false, view: verbose('style'));
      return;
    }

    data
      ..prop('verbose', verbose, showName: false, view: verbose('verbose'))
      ..prop('debug', debug, showName: false, view: debug('debug'))
      ..prop('info', info, showName: false, view: info('info'))
      ..prop('warning', warning, showName: false, view: warning('warning'))
      ..prop('error', error, showName: false, view: error('error'))
      ..prop('critical', critical, showName: false, view: critical('critical'));
  }
}
