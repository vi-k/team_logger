import '../loggable/loggable.dart';
import '../theme/log_main_theme.dart';
import 'log_pre_formatter.dart';

final class NullFormatter with Loggable implements LogPreFormatter {
  const NullFormatter();

  @override
  String call(LogTheme theme, String text) => text;

  @override
  void collectLoggableData(LoggableData data) {}
}
