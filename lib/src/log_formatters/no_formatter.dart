import '../logger/log.dart';
import '../theme/log_theme.dart';
import 'log_formatter.dart';

final class NoFormatter implements LogFormatter {
  @override
  LogFormatterBox call(Log log, LogLevelTheme theme, int? remainingLength) =>
      LogFormatterBox.raw(0, [''], debugName: 'none');
}
