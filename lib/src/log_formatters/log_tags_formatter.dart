import '../logger/log.dart';
import '../theme/log_theme.dart';
import 'constraints.dart';
import 'log_formatter.dart';
import 'text_align.dart';

final class LogTagsFormatter implements LogFormatter {
  final LogStyle? style;
  final Constraints constraints;
  final TextAlign textAlign;
  final VerticalAlign verticalAlign;
  final String open;
  final String close;
  final bool stretch;
  final bool hideTags;

  const LogTagsFormatter({
    this.style,
    this.constraints = const Constraints.unlimited(),
    this.textAlign = TextAlign.left,
    this.verticalAlign = VerticalAlign.top,
    this.open = '',
    this.close = '',
    this.stretch = true,
    this.hideTags = true,
  });

  @override
  LogFormatterBox call(Log log, LogLevelTheme theme, int? remainingLength) {
    final style = this.style?[log.level] ?? theme.tagsStyle;
    final tags = theme.allTags(log);
    final tagsStr = '$open${tags.map((tag) => '#$tag').join(' ')}$close';

    return LogFormatterBox(
      log,
      theme,
      [if (hideTags) theme.common.hiddenStyle(tagsStr) else style(tagsStr)],
      constraints: constraints.restrict(remainingLength),
      textAlign: textAlign,
      verticalFiller: stretch ? theme.common.hiddenStyle(tagsStr) : null,
      verticalAlign: verticalAlign,
      debugName: 'tags',
    );
  }
}
