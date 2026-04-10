import '../loggable/loggable.dart';
import '../theme/log_theme.dart';
import 'log_pre_formatter.dart';

final class CustomLogPreFormatter with Loggable implements LogPreFormatter {
  final String Function(LogLevelTheme theme, String text) format;

  const CustomLogPreFormatter(this.format);

  @override
  String call(LogLevelTheme theme, String text) => format(theme, text);

  @override
  void collectLoggableData(LoggableData data) {}
}
