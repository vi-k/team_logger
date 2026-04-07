import '../logger/log.dart';
import '../publishers/log_theme.dart';

abstract interface class LogPreFormatter {
  String call(Log log, LogTheme theme, String text);
}
