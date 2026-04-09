import '../logger/log.dart';
import '../theme/log_theme.dart';
import 'constraints.dart';
import 'log_formatter.dart';
import 'text_align.dart';

abstract interface class LogTimeFormatter implements LogFormatter {
  const factory LogTimeFormatter.dateTime({
    DateTime Function(Log log)? getTime,
    LogStyle? style,
    Constraints constraints,
    TextAlign textAlign,
    VerticalAlign verticalAlign,
    String open,
    String close,
    bool microseconds,
    bool utc,
  }) = _DateTimeLogTimeFormatter;

  const factory LogTimeFormatter.iso8601({
    DateTime Function(Log log)? getTime,
    LogStyle? style,
    Constraints constraints,
    TextAlign textAlign,
    VerticalAlign verticalAlign,
    String open,
    String close,
    bool utc,
  }) = _Iso8601LogTimeFormatter;

  const factory LogTimeFormatter.onlyTime({
    DateTime Function(Log log)? getTime,
    LogStyle? style,
    Constraints constraints,
    TextAlign textAlign,
    VerticalAlign verticalAlign,
    String open,
    String close,
    bool microseconds,
    bool utc,
  }) = _OnlyTimeLogTimeFormatter;

  static String dateToString(DateTime time) => '${time.year}'
      '-${_d2(time.month)}'
      '-${_d2(time.day)}';

  static String timeToString(DateTime time, {bool microseconds = false}) =>
      '${_d2(time.hour)}'
      ':${_d2(time.minute)}'
      ':${_d2(time.second)}'
      '.${_d3(time.millisecond)}'
      '${microseconds ? _d3(time.microsecond) : ''}'
      '${time.isUtc ? 'Z' : ''}';

  static String _d2(int n) => n.toString().padLeft(2, '0');

  static String _d3(int n) => n.toString().padLeft(3, '0');
}

final class _DateTimeLogTimeFormatter implements LogTimeFormatter {
  final DateTime Function(Log log)? getTime;
  final LogStyle? style;
  final Constraints constraints;
  final TextAlign textAlign;
  final VerticalAlign verticalAlign;
  final String open;
  final String close;
  final bool microseconds;
  final bool utc;

  const _DateTimeLogTimeFormatter({
    this.getTime,
    this.style,
    this.constraints = const Constraints.unlimited(),
    this.textAlign = TextAlign.left,
    this.verticalAlign = VerticalAlign.top,
    this.open = '',
    this.close = '',
    this.microseconds = false,
    this.utc = false,
  });

  @override
  int get priority => 0;

  @override
  LogFormatterBox call(
    Log log,
    LogLevelTheme theme,
    int? maxLength,
    int? maxLines,
  ) {
    final style = this.style?[log.level] ?? theme.timeStyle;
    var time = getTime?.call(log) ?? log.time;
    if (utc) {
      time = time.toUtc();
    }
    final timeStr = microseconds
        ? '$open$time$close'
        : '$open'
            '${LogTimeFormatter.dateToString(time)}'
            ' ${LogTimeFormatter.timeToString(time, microseconds: microseconds)}'
            '$close';

    return LogFormatterBox(
      log,
      theme,
      [style(timeStr)],
      constraints: constraints.restrict(maxLength),
      textAlign: textAlign,
      verticalAlign: verticalAlign,
    );
  }
}

final class _Iso8601LogTimeFormatter implements LogTimeFormatter {
  final DateTime Function(Log log)? getTime;
  final LogStyle? style;
  final Constraints constraints;
  final TextAlign textAlign;
  final VerticalAlign verticalAlign;
  final String open;
  final String close;
  final bool utc;

  const _Iso8601LogTimeFormatter({
    this.getTime,
    this.style,
    this.constraints = const Constraints.unlimited(),
    this.textAlign = TextAlign.left,
    this.verticalAlign = VerticalAlign.top,
    this.open = '',
    this.close = '',
    this.utc = false,
  });

  @override
  int get priority => 0;

  @override
  LogFormatterBox call(
    Log log,
    LogLevelTheme theme,
    int? maxLength,
    int? maxLines,
  ) {
    final style = this.style?[log.level] ?? theme.timeStyle;
    var time = getTime?.call(log) ?? log.time;
    if (utc) {
      time = time.toUtc();
    }

    return LogFormatterBox(
      log,
      theme,
      [style('$open${time.toIso8601String()}$close')],
      constraints: constraints.restrict(maxLength),
      textAlign: textAlign,
      verticalAlign: verticalAlign,
    );
  }
}

final class _OnlyTimeLogTimeFormatter implements LogTimeFormatter {
  final DateTime Function(Log log)? getTime;
  final LogStyle? style;
  final Constraints constraints;
  final TextAlign textAlign;
  final VerticalAlign verticalAlign;
  final String open;
  final String close;
  final bool microseconds;
  final bool utc;

  const _OnlyTimeLogTimeFormatter({
    this.getTime,
    this.style,
    this.constraints = const Constraints.unlimited(),
    this.textAlign = TextAlign.left,
    this.verticalAlign = VerticalAlign.top,
    this.open = '',
    this.close = '',
    this.microseconds = false,
    this.utc = false,
  });

  @override
  int get priority => 0;

  @override
  LogFormatterBox call(
    Log log,
    LogLevelTheme theme,
    int? maxLength,
    int? maxLines,
  ) {
    final style = this.style?[log.level] ?? theme.timeStyle;
    var time = getTime?.call(log) ?? log.time;
    if (utc) {
      time = time.toUtc();
    }
    final timeStr = '$open'
        '${LogTimeFormatter.timeToString(time, microseconds: microseconds)}'
        '$close';

    return LogFormatterBox(
      log,
      theme,
      [style(timeStr)],
      constraints: constraints.restrict(maxLength),
      textAlign: textAlign,
      verticalAlign: verticalAlign,
    );
  }
}
