import '../logger/log.dart';
import '../theme/log_theme.dart';
import 'constraints.dart';
import 'log_block.dart';
import 'log_row.dart';
import 'log_text_align.dart';
import 'log_vertical_align.dart';

final class LogTags implements LogBlock {
  final LogStyle? style;
  final Constraints constraints;
  final LogTextAlign textAlign;
  final LogVerticalAlign verticalAlign;
  final String open;
  final String close;
  final Set<String> tags;
  final bool stretch;
  final bool hidden;

  const LogTags({
    this.style,
    this.constraints = const Constraints.unlimited(),
    this.textAlign = LogTextAlign.left,
    this.verticalAlign = LogVerticalAlign.top,
    this.open = '',
    this.close = '',
    this.tags = const {},
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
    final tags = theme.allTags(log);
    if (this.tags.isNotEmpty) {
      tags.addAll(this.tags);
    }
    final tagsStr = '$open${tags.map((tag) => '#$tag').join(' ')}$close';
    final style = hidden
        ? theme.common.hiddenStyle
        : this.style?[log.level] ?? theme.tagsStyle;

    return LogBox(
      log,
      theme,
      [style(tagsStr)],
      constraints: constraints.restrict(remainingLength),
      textAlign: textAlign,
      verticalAlign: verticalAlign,
      verticalFiller: stretch ? theme.common.hiddenStyle(tagsStr) : null,
      debugName: 'tags',
    );
  }
}
