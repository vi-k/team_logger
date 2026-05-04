import '../logger/logger.dart';
import '../theme/log_theme.dart';
import 'constraints.dart';
import 'log_block.dart';
import 'log_row.dart';
import 'log_text_align.dart';
import 'log_vertical_align.dart';

final class LogDivider implements LogBlock {
  final LogStyle style;
  final Constraints constraints;
  final LogTextAlign textAlign;
  final LogVerticalAlign verticalAlign;
  final String divider;
  final bool stretch;

  const LogDivider(
    this.divider, {
    this.style = LogStyle.noColors,
    this.constraints = const Constraints.unlimited(),
    this.textAlign = LogTextAlign.left,
    this.verticalAlign = LogVerticalAlign.top,
    this.stretch = true,
  });

  @override
  LogBox call(Log log, LogLevelTheme theme, LogRow row, int? remainingLength) =>
      LogBox(
        log,
        theme,
        [style[log.level](divider)],
        constraints: constraints.restrict(remainingLength),
        showEllipsis: false,
        textAlign: textAlign,
        verticalAlign: verticalAlign,
        verticalFiller: stretch ? theme.common.hiddenStyle(divider) : null,
        debugName: 'divider',
      );
}
