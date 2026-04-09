import '../logger/log.dart';
import '../theme/log_theme.dart';
import 'log_formatter.dart';

final class NoFormatter implements LogFormatter {
  @override
  int get priority => 0;

  @override
  LogFormatterBox call(
    Log log,
    LogLevelTheme theme,
    int? maxLength,
    int? maxLines,
  ) =>
      LogFormatterBox.raw(0, ['']);
}
