import '../logger/log.dart';
import '../publishers/log_theme.dart';
import 'log_formatter.dart';

final class NoFormatter implements LogFormatter {
  @override
  LogFormatterBox call(Log log, LogTheme theme, int? maxWidth) =>
      const LogFormatterBox.raw(0, ['']);
}
