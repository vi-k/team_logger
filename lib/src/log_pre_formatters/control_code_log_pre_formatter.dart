import 'package:ansi_escape_codes/extensions.dart';

import '../logger/log.dart';
import '../theme/log_theme.dart';
import 'log_pre_formatter.dart';

final class ControlCodeLogPreFormatter implements LogPreFormatter {
  final LogStyle? style;

  const ControlCodeLogPreFormatter({this.style});

  @override
  String call(Log log, LogTheme theme, String text) {
    final style = (this.style ?? theme.punctuation)[log.level];

    return text.ansiShowControlCodes(
      open: style.open,
      close: style.close,
    );
  }
}
