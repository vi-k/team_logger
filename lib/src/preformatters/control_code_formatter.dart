import 'package:ansi_escape_codes/parsing.dart' as ansi;

import '../loggable/loggable.dart';
import '../theme/log_theme.dart';
import 'log_pre_formatter.dart';

final class ControlCodeFormatter with Loggable implements LogPreFormatter {
  final bool excludeEscCode;

  const ControlCodeFormatter({this.excludeEscCode = true});

  @override
  String call(LogLevelTheme theme, String text) {
    final buf = StringBuffer();
    final open = theme.paddingStyle.open;
    final close = theme.paddingStyle.close;

    for (final charCode in text.codeUnits) {
      final controlCode = ansi.ControlFunctionsC0.byIndex(charCode);

      if (controlCode == null ||
          excludeEscCode && controlCode == ansi.ControlFunctionsC0.ESC) {
        buf.writeCharCode(charCode);
      } else {
        if (controlCode.escapeSymbol case final escapeSymbol?) {
          buf
            ..write(open)
            ..write(escapeSymbol)
            ..write(close);
        } else {
          buf
            ..write(open)
            ..write(r'\x')
            ..write(charCode.toRadixString(16).toUpperCase().padLeft(2, '0'))
            ..write(close);
        }
      }
    }

    return buf.toString();
  }

  @override
  void collectLoggableData(LoggableData data) {
    data.prop('excludeEscCode', excludeEscCode);
  }
}
