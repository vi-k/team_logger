import '../logger/logger.dart';
import '../theme/log_theme.dart';
import 'constraints.dart';
import 'log_block.dart';
import 'log_row.dart';
import 'log_text_align.dart';
import 'log_vertical_align.dart';

abstract interface class LogTime implements LogBlock {
  const factory LogTime.dateTime({
    DateTime Function(Log log)? getTime,
    LogStyle? style,
    Constraints constraints,
    LogTextAlign textAlign,
    LogVerticalAlign verticalAlign,
    String open,
    String close,
    bool microseconds,
    bool utc,
    bool stretch,
    bool hidden,
  }) = _DateTime;

  const factory LogTime.iso8601({
    DateTime Function(Log log)? getTime,
    LogStyle? style,
    Constraints constraints,
    LogTextAlign textAlign,
    LogVerticalAlign verticalAlign,
    String open,
    String close,
    bool utc,
    bool stretch,
    bool hidden,
  }) = _Iso8601;

  const factory LogTime.onlyTime({
    DateTime Function(Log log)? getTime,
    LogStyle? style,
    Constraints constraints,
    LogTextAlign textAlign,
    LogVerticalAlign verticalAlign,
    String open,
    String close,
    bool microseconds,
    bool utc,
    bool stretch,
    bool hidden,
  }) = _OnlyTime;

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

final class _DateTime implements LogTime {
  final DateTime Function(Log log)? getTime;
  final LogStyle? style;
  final Constraints constraints;
  final LogTextAlign textAlign;
  final LogVerticalAlign verticalAlign;
  final String open;
  final String close;
  final bool microseconds;
  final bool utc;
  final bool stretch;
  final bool hidden;

  const _DateTime({
    this.getTime,
    this.style,
    this.constraints = const Constraints.unlimited(),
    this.textAlign = LogTextAlign.left,
    this.verticalAlign = LogVerticalAlign.top,
    this.open = '',
    this.close = '',
    this.microseconds = false,
    this.utc = false,
    this.stretch = true,
    this.hidden = false,
  });

  @override
  LogBox call(Log log, LogLevelTheme theme, LogRow row, int? remainingLength) {
    final style = hidden
        ? theme.common.hiddenStyle
        : this.style?[log.level] ?? theme.timeStyle;
    var time = getTime?.call(log) ?? log.time;
    if (utc) {
      time = time.toUtc();
    }
    final timeStr = microseconds
        ? '$open$time$close'
        : '$open'
            '${LogTime.dateToString(time)}'
            ' ${LogTime.timeToString(time, microseconds: microseconds)}'
            '$close';

    return LogBox(
      log,
      theme,
      [style(timeStr)],
      constraints: constraints.restrict(remainingLength),
      textAlign: textAlign,
      verticalFiller: stretch ? theme.common.hiddenStyle(timeStr) : null,
      verticalAlign: verticalAlign,
    );
  }
}

final class _Iso8601 implements LogTime {
  final DateTime Function(Log log)? getTime;
  final LogStyle? style;
  final Constraints constraints;
  final LogTextAlign textAlign;
  final LogVerticalAlign verticalAlign;
  final String open;
  final String close;
  final bool utc;
  final bool stretch;
  final bool hidden;

  const _Iso8601({
    this.getTime,
    this.style,
    this.constraints = const Constraints.unlimited(),
    this.textAlign = LogTextAlign.left,
    this.verticalAlign = LogVerticalAlign.top,
    this.open = '',
    this.close = '',
    this.utc = false,
    this.stretch = true,
    this.hidden = false,
  });

  @override
  LogBox call(Log log, LogLevelTheme theme, LogRow row, int? remainingLength) {
    final style = hidden
        ? theme.common.hiddenStyle
        : this.style?[log.level] ?? theme.timeStyle;
    var time = getTime?.call(log) ?? log.time;
    if (utc) {
      time = time.toUtc();
    }
    final timeStr = '$open${time.toIso8601String()}$close';

    return LogBox(
      log,
      theme,
      [style(timeStr)],
      constraints: constraints.restrict(remainingLength),
      textAlign: textAlign,
      verticalFiller: stretch ? theme.common.hiddenStyle(timeStr) : null,
      verticalAlign: verticalAlign,
    );
  }
}

final class _OnlyTime implements LogTime {
  final DateTime Function(Log log)? getTime;
  final LogStyle? style;
  final Constraints constraints;
  final LogTextAlign textAlign;
  final LogVerticalAlign verticalAlign;
  final String open;
  final String close;
  final bool microseconds;
  final bool utc;
  final bool stretch;
  final bool hidden;

  const _OnlyTime({
    this.getTime,
    this.style,
    this.constraints = const Constraints.unlimited(),
    this.textAlign = LogTextAlign.left,
    this.verticalAlign = LogVerticalAlign.top,
    this.open = '',
    this.close = '',
    this.microseconds = false,
    this.utc = false,
    this.stretch = true,
    this.hidden = false,
  });

  @override
  LogBox call(Log log, LogLevelTheme theme, LogRow row, int? remainingLength) {
    final style = hidden
        ? theme.common.hiddenStyle
        : this.style?[log.level] ?? theme.timeStyle;
    var time = getTime?.call(log) ?? log.time;
    if (utc) {
      time = time.toUtc();
    }
    final timeStr = '$open'
        '${LogTime.timeToString(time, microseconds: microseconds)}'
        '$close';

    return LogBox(
      log,
      theme,
      [style(timeStr)],
      constraints: constraints.restrict(remainingLength),
      textAlign: textAlign,
      verticalFiller: stretch ? theme.common.hiddenStyle(timeStr) : null,
      verticalAlign: verticalAlign,
      debugName: 'time',
    );
  }
}
