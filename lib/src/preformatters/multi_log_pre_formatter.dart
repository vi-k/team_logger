import '../loggable/loggable.dart';
import '../theme/log_theme.dart';
import 'log_pre_formatter.dart';

final class MultiLogPreFormatter with Loggable implements LogPreFormatter {
  final List<LogPreFormatter> formatters;

  const MultiLogPreFormatter(this.formatters);

  @override
  String call(LogLevelTheme theme, String text) =>
      formatters.fold(text, (text, formatter) => formatter(theme, text));

  @override
  void collectLoggableData(LoggableData data) {
    data.prop('formatters', formatters);
  }
}
