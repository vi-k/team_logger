import '../logger/log.dart';
import '../publishers/log_style.dart';
import '../publishers/log_theme.dart';
import 'constraints.dart';
import 'log_formatter.dart';
import 'text_align.dart';

abstract interface class LogCustomText implements LogFormatter {
  const factory LogCustomText(
    String text, {
    LogStyle style,
    Constraints constraints,
    TextAlign textAlign,
    VerticalAlign verticalAlign,
  }) = _LogCustomText;
}

final class _LogCustomText implements LogCustomText {
  final LogStyle style;
  final Constraints constraints;
  final TextAlign textAlign;
  final VerticalAlign verticalAlign;
  final String text;

  const _LogCustomText(
    this.text, {
    this.style = LogStyle.defaultStyle,
    this.constraints = const Constraints.unlimited(),
    this.textAlign = TextAlign.left,
    this.verticalAlign = VerticalAlign.top,
  });

  @override
  LogFormatterBox call(Log log, LogTheme theme, int? maxWidth) =>
      LogFormatterBox.fromText(
        log,
        theme,
        style[log.level](text),
        constraints: constraints.restrict(maxWidth),
        textAlign: textAlign,
        verticalAlign: verticalAlign,
      );
}
