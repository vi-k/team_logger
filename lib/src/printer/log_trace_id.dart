import '../logger/logger.dart';
import '../theme/log_main_theme.dart';
import 'constraints.dart';
import 'log_block.dart';
import 'log_row.dart';
import 'log_text_align.dart';
import 'log_vertical_align.dart';

final class LogTraceId implements LogBlock {
  final LogStyles? styles;
  final LogConstraints constraints;
  final LogTextAlign textAlign;
  final LogVerticalAlign verticalAlign;
  final String open;
  final String close;
  final String separator;
  final bool stretch;
  final bool hidden;

  const LogTraceId({
    this.styles,
    this.constraints = const LogConstraints.unlimited(),
    this.textAlign = LogTextAlign.left,
    this.verticalAlign = LogVerticalAlign.top,
    this.open = '{',
    this.close = '}',
    this.separator = ' ',
    this.stretch = true,
    this.hidden = false,
  });

  @override
  LogBox call(Log log, LogTheme theme, LogRow row, int? remainingLength) {
    if (log.traceIds.isEmpty) {
      return LogBox.empty();
    }

    final traceIdsStr =
        log.traceIds.map((e) => '$open$e$close').join(separator);
    final style = hidden
        ? theme.main.hiddenStyle
        : styles?[log.level] ?? theme.main.traceIdStyle;

    return LogBox(
      log,
      theme,
      [style(traceIdsStr)],
      constraints: constraints.restrict(remainingLength),
      textAlign: textAlign,
      verticalAlign: verticalAlign,
      verticalFiller: stretch ? theme.main.hiddenStyle(traceIdsStr) : null,
      debugName: 'trace_id',
    );
  }
}
