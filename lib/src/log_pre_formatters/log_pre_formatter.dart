import '../logger/log.dart';
import '../theme/log_theme.dart';

abstract interface class LogPreFormatter {
  String call(Log log, LogTheme theme, String text);
}
