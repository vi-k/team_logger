import '../logger/logger.dart';
import '../theme/log_main_theme.dart';
import 'constraints.dart';
import 'log_block.dart';
import 'log_row.dart';
import 'log_text_align.dart';
import 'log_vertical_align.dart';

final class LogNum implements LogBlock {
  final LogStyles? styles;
  final Constraints constraints;
  final LogTextAlign textAlign;
  final LogVerticalAlign verticalAlign;
  final String open;
  final String close;
  final bool stretch;
  final bool hidden;

  const LogNum({
    this.styles,
    this.constraints = const Constraints.unlimited(),
    this.textAlign = LogTextAlign.left,
    this.verticalAlign = LogVerticalAlign.top,
    this.open = '(',
    this.close = ')',
    this.stretch = true,
    this.hidden = false,
  });

  @override
  LogBox call(Log log, LogTheme theme, LogRow row, int? remainingLength) {
    final numStr = '$open${log.num}$close';
    final style = hidden
        ? theme.main.hiddenStyle
        : styles?[log.level] ?? theme.data.numStyle;

    return LogBox(
      log,
      theme,
      [style(numStr)],
      constraints: constraints.restrict(remainingLength),
      textAlign: textAlign,
      verticalAlign: verticalAlign,
      verticalFiller: stretch ? theme.main.hiddenStyle(numStr) : null,
      debugName: 'num',
    );
  }
}
