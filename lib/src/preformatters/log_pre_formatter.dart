import '../theme/log_main_theme.dart';

abstract interface class LogPreFormatter {
  String call(LogTheme theme, String text);
}
