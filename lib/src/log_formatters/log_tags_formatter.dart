import '../logger/log.dart';
import '../theme/log_theme.dart';
import 'constraints.dart';
import 'log_formatter.dart';
import 'text_align.dart';

abstract interface class LogTagsFormatter implements LogFormatter {
  const factory LogTagsFormatter({
    LogStyle? style,
    Constraints constraints,
    TextAlign textAlign,
    VerticalAlign verticalAlign,
    String open,
    String close,
  }) = _LogTagsFormatter;
}

final class _LogTagsFormatter implements LogTagsFormatter {
  final LogStyle? style;
  final Constraints constraints;
  final TextAlign textAlign;
  final VerticalAlign verticalAlign;
  final String open;
  final String close;

  const _LogTagsFormatter({
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
    final tags = log.tags.map((tag) => '#$tag').join(' ');

    return LogFormatterBox(
      log,
      theme,
      [style('$open$tags$close')],
      constraints: constraints.restrict(maxWidth),
      textAlign: textAlign,
      verticalAlign: verticalAlign,
    );
  }
}
