import '../logger/log.dart';
import '../theme/log_theme.dart';
import 'constraints.dart';
import 'log_formatter.dart';
import 'text_align.dart';

abstract interface class LogPathFormatter implements LogFormatter {
  const factory LogPathFormatter({
    LogStyle? style,
    Constraints constraints,
    TextAlign textAlign,
    VerticalAlign verticalAlign,
    String open,
    String close,
  }) = _LogPathFormatter;
}

final class _LogPathFormatter implements LogPathFormatter {
  final LogStyle? style;
  final Constraints constraints;
  final TextAlign textAlign;
  final VerticalAlign verticalAlign;
  final String open;
  final String close;

  const _LogPathFormatter({
    this.style,
    this.constraints = const Constraints.unlimited(),
    this.textAlign = TextAlign.left,
    this.verticalAlign = VerticalAlign.top,
    this.open = '[',
    this.close = ']',
  });

  @override
  LogFormatterBox call(Log log, LogLevelTheme theme, int? remainingLength) {
    final style = this.style?[log.level] ?? theme.pathStyle;

    return LogFormatterBox(
      log,
      theme,
      [style('$open${log.path}$close')],
      constraints: constraints.restrict(remainingLength),
      textAlign: textAlign,
      verticalAlign: verticalAlign,
      debugName: 'path',
    );
  }
}
