import '../logger/log.dart';
import '../theme/log_theme.dart';
import 'log_pre_formatter.dart';

final class MultiLogPreFormatter implements LogPreFormatter {
  final List<LogPreFormatter> formatters;

  const MultiLogPreFormatter(this.formatters);

  @override
  String call(Log log, LogTheme theme, String text) =>
      formatters.fold(text, (text, formatter) => formatter(log, theme, text));
}
