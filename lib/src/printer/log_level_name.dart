import '../logger/log.dart';
import '../theme/log_theme.dart';
import 'constraints.dart';
import 'log_block.dart';
import 'log_row.dart';
import 'log_text_align.dart';
import 'log_vertical_align.dart';

abstract interface class LogLevelName implements LogBlock {
  const factory LogLevelName.full({
    LogStyle? style,
    Constraints constraints,
    LogTextAlign textAlign,
    LogVerticalAlign verticalAlign,
    String open,
    String close,
    bool upperCase,
    bool stretch,
  }) = _FullLevelName;

  const factory LogLevelName.short({
    LogStyle? style,
    Constraints constraints,
    LogTextAlign textAlign,
    LogVerticalAlign verticalAlign,
    String open,
    String close,
    bool upperCase,
    bool stretch,
  }) = _ShortLevelName;
}

final class _FullLevelName implements LogLevelName {
  final LogStyle? style;
  final Constraints constraints;
  final LogTextAlign textAlign;
  final LogVerticalAlign verticalAlign;
  final String open;
  final String close;
  final bool upperCase;
  final bool stretch;

  const _FullLevelName({
    this.style,
    this.constraints = const Constraints.unlimited(),
    this.textAlign = LogTextAlign.left,
    this.verticalAlign = LogVerticalAlign.top,
    this.open = '[',
    this.close = ']',
    this.upperCase = true,
    this.stretch = true,
  });

  @override
  LogBox call(
    Log log,
    LogLevelTheme theme,
    LogRow row,
    int? remainingLength,
  ) {
    final style = this.style?[log.level] ?? theme.levelNameStyle;
    final levelName = upperCase ? log.levelName.toUpperCase() : log.levelName;
    final levelNameStr = '$open$levelName$close';

    return LogBox(
      log,
      theme,
      [style(levelNameStr)],
      constraints: constraints.restrict(remainingLength),
      textAlign: textAlign,
      verticalFiller: stretch ? theme.common.hiddenStyle(levelNameStr) : null,
      verticalAlign: verticalAlign,
      debugName: 'level_name',
    );
  }
}

final class _ShortLevelName implements LogLevelName {
  final LogStyle? style;
  final Constraints constraints;
  final LogTextAlign textAlign;
  final LogVerticalAlign verticalAlign;
  final String open;
  final String close;
  final bool upperCase;
  final bool stretch;

  const _ShortLevelName({
    this.style,
    this.constraints = const Constraints.unlimited(),
    this.textAlign = LogTextAlign.left,
    this.verticalAlign = LogVerticalAlign.top,
    this.open = '[',
    this.close = ']',
    this.upperCase = false,
    this.stretch = true,
  });

  @override
  LogBox call(
    Log log,
    LogLevelTheme theme,
    LogRow row,
    int? remainingLength,
  ) {
    final style = this.style?[log.level] ?? theme.levelNameStyle;
    final levelName =
        upperCase ? log.shortLevelName.toUpperCase() : log.shortLevelName;
    final levelNameStr = '$open$levelName$close';

    return LogBox(
      log,
      theme,
      [style(levelNameStr)],
      constraints: constraints.restrict(remainingLength),
      textAlign: textAlign,
      verticalFiller: stretch ? theme.common.hiddenStyle(levelNameStr) : null,
      verticalAlign: verticalAlign,
      debugName: 'level_name',
    );
  }
}
