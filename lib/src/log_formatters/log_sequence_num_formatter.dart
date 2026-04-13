import '../logger/log.dart';
import '../theme/log_theme.dart';
import 'constraints.dart';
import 'log_formatter.dart';
import 'text_align.dart';

abstract interface class LogSequenceNumFormatter implements LogFormatter {
  const factory LogSequenceNumFormatter({
    LogStyle? style,
    Constraints constraints,
    TextAlign textAlign,
    VerticalAlign verticalAlign,
    String open,
    String close,
  }) = _LogSequenceNumFormatter;
}

final class _LogSequenceNumFormatter implements LogSequenceNumFormatter {
  final LogStyle? style;
  final Constraints constraints;
  final TextAlign textAlign;
  final VerticalAlign verticalAlign;
  final String open;
  final String close;

  const _LogSequenceNumFormatter({
    this.style,
    this.constraints = const Constraints.unlimited(),
    this.textAlign = TextAlign.left,
    this.verticalAlign = VerticalAlign.stretch,
    this.open = '(',
    this.close = ')',
  });

  @override
  LogFormatterBox call(Log log, LogLevelTheme theme, int? remainingLength) {
    final style = this.style?[log.level] ?? theme.sequenceNumStyle;

    return LogFormatterBox(
      log,
      theme,
      [style('$open${log.sequenceNum}$close')],
      constraints: constraints.restrict(remainingLength),
      textAlign: textAlign,
      verticalAlign: verticalAlign,
      debugName: 'sequence_num',
    );
  }
}
