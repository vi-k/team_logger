import '../logger/log.dart';
import '../theme/log_theme.dart';
import 'constraints.dart';
import 'log_formatter.dart';
import 'text_align.dart';

abstract interface class LogDivider implements LogFormatter {
  const factory LogDivider(
    String divider, {
    LogStyle style,
    Constraints constraints,
    TextAlign textAlign,
    VerticalAlign verticalAlign,
  }) = _SingleLineLogDivider;

  const factory LogDivider.fullHeight(
    String divider, {
    LogStyle style,
    Constraints constraints,
    TextAlign textAlign,
  }) = _FulHeightLogDivider;
}

final class _SingleLineLogDivider implements LogDivider {
  final LogStyle style;
  final Constraints constraints;
  final TextAlign textAlign;
  final VerticalAlign verticalAlign;
  final String divider;

  const _SingleLineLogDivider(
    this.divider, {
    this.style = LogStyle.noColors,
    this.constraints = const Constraints.unlimited(),
    this.textAlign = TextAlign.left,
    this.verticalAlign = VerticalAlign.top,
  }) : assert(
          verticalAlign != VerticalAlign.stretch,
          'Use `LogDivider.fullHeight` instead of `verticalAlign = VerticalAlign.stretch`',
        );

  @override
  int get priority => 0;

  @override
  LogFormatterBox call(Log log, LogLevelTheme theme, int? remainingLength) =>
      LogFormatterBox(
        log,
        theme,
        [style[log.level](divider)],
        constraints: constraints.restrict(remainingLength),
        showEllipsis: false,
        textAlign: textAlign,
        verticalAlign: verticalAlign,
      );
}

final class _FulHeightLogDivider implements LogDivider {
  final LogStyle style;
  final Constraints constraints;
  final TextAlign textAlign;
  final String divider;

  const _FulHeightLogDivider(
    this.divider, {
    this.style = LogStyle.noColors,
    this.constraints = const Constraints.unlimited(),
    this.textAlign = TextAlign.left,
  });

  @override
  int get priority => 0;

  @override
  LogFormatterBox call(Log log, LogLevelTheme theme, int? remainingLength) =>
      LogFormatterBox(
        log,
        theme,
        [style[log.level](divider)],
        constraints: constraints.restrict(remainingLength),
        showEllipsis: false,
        verticalAlign: VerticalAlign.stretch,
      );
}
