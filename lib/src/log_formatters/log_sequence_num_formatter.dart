import '../logger/log.dart';
import '../theme/log_theme.dart';
import 'constraints.dart';
import 'log_formatter.dart';
import 'text_align.dart';

final class LogSequenceNumFormatter implements LogFormatter {
  final LogStyle? style;
  final Constraints constraints;
  final TextAlign textAlign;
  final VerticalAlign verticalAlign;
  final String open;
  final String close;
  final bool stretch;

  const LogSequenceNumFormatter({
    this.style,
    this.constraints = const Constraints.unlimited(),
    this.textAlign = TextAlign.left,
    this.verticalAlign = VerticalAlign.top,
    this.open = '(',
    this.close = ')',
    this.stretch = true,
  });

  @override
  LogFormatterBox call(Log log, LogLevelTheme theme, int? remainingLength) {
    final style = this.style?[log.level] ?? theme.sequenceNumStyle;
    final sequenceNumStr = '$open${log.sequenceNum}$close';

    return LogFormatterBox(
      log,
      theme,
      [style(sequenceNumStr)],
      constraints: constraints.restrict(remainingLength),
      textAlign: textAlign,
      verticalFiller: stretch ? theme.common.hiddenStyle(sequenceNumStr) : null,
      verticalAlign: verticalAlign,
      debugName: 'sequence_num',
    );
  }
}
