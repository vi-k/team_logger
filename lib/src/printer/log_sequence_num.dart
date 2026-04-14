import '../logger/log.dart';
import '../theme/log_theme.dart';
import 'constraints.dart';
import 'log_block.dart';
import 'log_row.dart';
import 'log_text_align.dart';
import 'log_vertical_align.dart';

final class LogSequenceNum implements LogBlock {
  final LogStyle? style;
  final Constraints constraints;
  final LogTextAlign textAlign;
  final LogVerticalAlign verticalAlign;
  final String open;
  final String close;
  final bool stretch;
  final bool hidden;

  const LogSequenceNum({
    this.style,
    this.constraints = const Constraints.unlimited(),
    this.textAlign = LogTextAlign.left,
    this.verticalAlign = LogVerticalAlign.top,
    this.open = '(',
    this.close = ')',
    this.stretch = true,
    this.hidden = false,
  });

  @override
  LogBox call(
    Log log,
    LogLevelTheme theme,
    LogRow row,
    int? remainingLength,
  ) {
    final sequenceNumStr = '$open${log.sequenceNum}$close';
    final style = hidden
        ? theme.common.hiddenStyle
        : this.style?[log.level] ?? theme.sequenceNumStyle;

    return LogBox(
      log,
      theme,
      [style(sequenceNumStr)],
      constraints: constraints.restrict(remainingLength),
      textAlign: textAlign,
      verticalAlign: verticalAlign,
      verticalFiller: stretch ? theme.common.hiddenStyle(sequenceNumStr) : null,
      debugName: 'sequence_num',
    );
  }
}
