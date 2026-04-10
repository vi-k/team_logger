import '../theme/log_theme.dart';

abstract interface class LogPreFormatter {
  String call(LogLevelTheme theme, String text);
}
