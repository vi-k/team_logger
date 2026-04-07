import '../logger/log.dart';
import '../publishers/log_style.dart';
import '../publishers/log_theme.dart';
import 'constraints.dart';
import 'log_formatter.dart';
import 'text_align.dart';

abstract interface class LogSystemTagsFormatter implements LogFormatter {
  const factory LogSystemTagsFormatter({
    LogStyle? style,
    Constraints constraints,
    TextAlign textAlign,
    VerticalAlign verticalAlign,
    String open,
    String close,
  }) = _LogSystemTagsFormatter;
}

final class _LogSystemTagsFormatter implements LogSystemTagsFormatter {
  final LogStyle? style;
  final Constraints constraints;
  final TextAlign textAlign;
  final VerticalAlign verticalAlign;
  final String open;
  final String close;

  const _LogSystemTagsFormatter({
    this.style,
    this.constraints = const Constraints.unlimited(),
    this.textAlign = TextAlign.left,
    this.verticalAlign = VerticalAlign.stretch,
    this.open = '',
    this.close = '',
  });

  @override
  LogFormatterBox call(Log log, LogTheme theme, int? maxWidth) {
    final style = (this.style ?? theme.tags)[log.level];
    final tags = {'log'};
    final tagsStr = tags.map((tag) => '#$tag').join(' ');

    return LogFormatterBox(
      log,
      theme,
      [style('$open$tagsStr$close')],
      constraints: constraints.restrict(maxWidth),
      textAlign: textAlign,
      verticalAlign: verticalAlign,
    );
  }
}
