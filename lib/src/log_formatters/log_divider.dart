import '../logger/log.dart';
import '../theme/log_theme.dart';
import 'constraints.dart';
import 'log_formatter.dart';
import 'text_align.dart';

final class LogDivider implements LogFormatter {
  final LogStyle style;
  final Constraints constraints;
  final TextAlign textAlign;
  final VerticalAlign verticalAlign;
  final String divider;
  final bool stretch;

  const LogDivider(
    this.divider, {
    this.style = LogStyle.noColors,
    this.constraints = const Constraints.unlimited(),
    this.textAlign = TextAlign.left,
    this.verticalAlign = VerticalAlign.top,
    this.stretch = true,
  });

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
        debugName: 'divider',
      );
}
