import '../logger/logger.dart';
import '../theme/log_theme.dart';
import 'constraints.dart';
import 'log_block.dart';
import 'log_row.dart';
import 'log_text_align.dart';
import 'log_vertical_align.dart';

final class LogCustomText implements LogBlock {
  final LogStyle style;
  final Constraints constraints;
  final LogTextAlign textAlign;
  final LogVerticalAlign verticalAlign;
  final String text;

  const LogCustomText(
    this.text, {
    this.style = LogStyle.noColors,
    this.constraints = const Constraints.unlimited(),
    this.textAlign = LogTextAlign.left,
    this.verticalAlign = LogVerticalAlign.top,
  });

  @override
  LogBox call(Log log, LogLevelTheme theme, LogRow row, int? remainingLength) =>
      LogBox.fromText(
        log,
        theme,
        style[log.level].call(text),
        maxLines: row.maxLines,
        constraints: constraints.restrict(remainingLength),
        textAlign: textAlign,
        verticalAlign: verticalAlign,
        debugName: 'custom_text',
      );
}
