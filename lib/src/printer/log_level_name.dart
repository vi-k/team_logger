import '../logger/logger.dart';
import '../theme/log_main_theme.dart';
import 'constraints.dart';
import 'log_block.dart';
import 'log_row.dart';
import 'log_text_align.dart';
import 'log_vertical_align.dart';

abstract interface class LogLevelName implements LogBlock {
  const factory LogLevelName.full({
    LogStyles? styles,
    LogConstraints constraints,
    LogTextAlign textAlign,
    LogVerticalAlign verticalAlign,
    String open,
    String close,
    bool upperCase,
    bool stretch,
    bool hidden,
  }) = _FullLevelName;

  const factory LogLevelName.short({
    LogStyles? styles,
    LogConstraints constraints,
    LogTextAlign textAlign,
    LogVerticalAlign verticalAlign,
    String open,
    String close,
    bool upperCase,
    bool stretch,
    bool hidden,
  }) = _ShortLevelName;
}

final class _FullLevelName implements LogLevelName {
  final LogStyles? styles;
  final LogConstraints constraints;
  final LogTextAlign textAlign;
  final LogVerticalAlign verticalAlign;
  final String open;
  final String close;
  final bool upperCase;
  final bool stretch;
  final bool hidden;

  const _FullLevelName({
    this.styles,
    this.constraints = const LogConstraints.unlimited(),
    this.textAlign = LogTextAlign.left,
    this.verticalAlign = LogVerticalAlign.top,
    this.open = '[',
    this.close = ']',
    this.upperCase = true,
    this.stretch = true,
    this.hidden = false,
  });

  @override
  LogBox call(Log log, LogTheme theme, LogRow row, int? remainingLength) {
    final style = hidden
        ? theme.main.hiddenStyle
        : styles?[log.level] ?? theme.data.levelNameStyle;
    final levelName = upperCase ? log.levelName.toUpperCase() : log.levelName;
    final levelNameStr = '$open$levelName$close';

    return LogBox(
      log,
      theme,
      [style(levelNameStr)],
      constraints: constraints.restrict(remainingLength),
      textAlign: textAlign,
      verticalFiller: stretch ? theme.main.hiddenStyle(levelNameStr) : null,
      verticalAlign: verticalAlign,
      debugName: 'level_name',
    );
  }
}

final class _ShortLevelName implements LogLevelName {
  final LogStyles? styles;
  final LogConstraints constraints;
  final LogTextAlign textAlign;
  final LogVerticalAlign verticalAlign;
  final String open;
  final String close;
  final bool upperCase;
  final bool stretch;
  final bool hidden;

  const _ShortLevelName({
    this.styles,
    this.constraints = const LogConstraints.unlimited(),
    this.textAlign = LogTextAlign.left,
    this.verticalAlign = LogVerticalAlign.top,
    this.open = '[',
    this.close = ']',
    this.upperCase = false,
    this.stretch = true,
    this.hidden = false,
  });

  @override
  LogBox call(Log log, LogTheme theme, LogRow row, int? remainingLength) {
    final style = hidden
        ? theme.main.hiddenStyle
        : styles?[log.level] ?? theme.data.levelNameStyle;
    final levelName =
        upperCase ? log.shortLevelName.toUpperCase() : log.shortLevelName;
    final levelNameStr = '$open$levelName$close';

    return LogBox(
      log,
      theme,
      [style(levelNameStr)],
      constraints: constraints.restrict(remainingLength),
      textAlign: textAlign,
      verticalFiller: stretch ? theme.main.hiddenStyle(levelNameStr) : null,
      verticalAlign: verticalAlign,
      debugName: 'level_name',
    );
  }
}
