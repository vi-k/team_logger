import '../logger/log.dart';
import '../theme/log_theme.dart';
import 'constraints.dart';
import 'log_formatter.dart';
import 'text_align.dart';

abstract interface class LogLevelFormatter implements LogFormatter {
  const factory LogLevelFormatter.short({
    LogStyle? style,
    Constraints constraints,
    TextAlign textAlign,
    VerticalAlign verticalAlign,
    String open,
    String close,
    bool upperCase,
  }) = _ShortLogLevelFormatter;

  const factory LogLevelFormatter.full({
    LogStyle? style,
    Constraints constraints,
    TextAlign textAlign,
    VerticalAlign verticalAlign,
    String open,
    String close,
    bool upperCase,
  }) = _FullLogLevelFormatter;
}

final class _FullLogLevelFormatter implements LogLevelFormatter {
  final LogStyle? style;
  final Constraints constraints;
  final TextAlign textAlign;
  final VerticalAlign verticalAlign;
  final String open;
  final String close;
  final bool upperCase;

  const _FullLogLevelFormatter({
    this.style,
    this.constraints = const Constraints.unlimited(),
    this.textAlign = TextAlign.left,
    this.verticalAlign = VerticalAlign.top,
    this.open = '[',
    this.close = ']',
    this.upperCase = true,
  });

  @override
  LogFormatterBox call(Log log, LogLevelTheme theme, int? remainingLength) {
    final style = this.style?[log.level] ?? theme.levelNameStyle;
    final levelName = upperCase ? log.levelName.toUpperCase() : log.levelName;

    return LogFormatterBox(
      log,
      theme,
      [style('$open$levelName$close')],
      constraints: constraints.restrict(remainingLength),
      textAlign: textAlign,
      verticalAlign: verticalAlign,
      debugName: 'level_name',
    );
  }
}

final class _ShortLogLevelFormatter implements LogLevelFormatter {
  final LogStyle? style;
  final Constraints constraints;
  final TextAlign textAlign;
  final VerticalAlign verticalAlign;
  final String open;
  final String close;
  final bool upperCase;

  const _ShortLogLevelFormatter({
    this.style,
    this.constraints = const Constraints.unlimited(),
    this.textAlign = TextAlign.left,
    this.verticalAlign = VerticalAlign.top,
    this.open = '[',
    this.close = ']',
    this.upperCase = false,
  });

  @override
  LogFormatterBox call(Log log, LogLevelTheme theme, int? remainingLength) {
    final style = this.style?[log.level] ?? theme.levelNameStyle;
    final levelName =
        upperCase ? log.shortLevelName.toUpperCase() : log.shortLevelName;

    return LogFormatterBox(
      log,
      theme,
      [style('$open$levelName$close')],
      constraints: constraints.restrict(remainingLength),
      textAlign: textAlign,
      verticalAlign: verticalAlign,
      debugName: 'level_name',
    );
  }
}
