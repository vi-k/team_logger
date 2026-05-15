import '../loggable/loggable.dart';
import '../theme/log_main_theme.dart';
import 'log_pre_formatter.dart';

final class CustomLogPreFormatter with Loggable implements LogPreFormatter {
  final String Function(LogThemeData theme, String text) format;

  const CustomLogPreFormatter(this.format);

  @override
  String call(LogThemeData theme, String text) => format(theme, text);

  @override
  void collectLoggableData(LoggableData data) {}
}
