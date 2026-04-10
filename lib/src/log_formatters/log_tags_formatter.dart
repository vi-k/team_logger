import '../logger/log.dart';
import '../theme/log_theme.dart';
import 'constraints.dart';
import 'log_divider.dart';
import 'log_formatter.dart';
import 'text_align.dart';

abstract interface class LogTagsFormatter implements LogDivider {
  const factory LogTagsFormatter({
    LogStyle? style,
    Constraints constraints,
    TextAlign textAlign,
    VerticalAlign verticalAlign,
    String open,
    String close,
    Set<String> commonTags,
    bool showLevelNameAsTag,
  }) = _LogTagsFormatter;
}

final class _LogTagsFormatter implements LogTagsFormatter {
  final LogStyle? style;
  final Constraints constraints;
  final TextAlign textAlign;
  final VerticalAlign verticalAlign;
  final String open;
  final String close;
  final Set<String> commonTags;
  final bool showLevelNameAsTag;

  const _LogTagsFormatter({
    this.style,
    this.constraints = const Constraints.unlimited(),
    this.textAlign = TextAlign.left,
    this.verticalAlign = VerticalAlign.stretch,
    this.open = '',
    this.close = '',
    this.commonTags = const {},
    this.showLevelNameAsTag = true,
  });

  @override
  int get priority => 0;

  @override
  LogFormatterBox call(Log log, LogLevelTheme theme, int? remainingLength) {
    final style = this.style?[log.level] ?? theme.tagsStyle;
    final tags = {...log.tags, ...commonTags};
    if (showLevelNameAsTag) {
      tags.add(log.levelName);
    }

    final tagsStr = tags.map((tag) => ' #$tag').join();

    return LogFormatterBox(
      log,
      theme,
      [style('$open$tagsStr$close')],
      constraints: constraints.restrict(remainingLength),
      textAlign: textAlign,
      verticalAlign: verticalAlign,
    );
  }
}
