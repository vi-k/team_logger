import '../theme/log_main_theme.dart';

abstract interface class LogPreFormatter {
  String call(LogThemeData theme, String text);
}
