import 'package:ansi_escape_codes/style.dart' as ansi;

import '../loggable/loggable.dart';
import '../theme/log_main_theme.dart';
import 'log_pre_formatter.dart';

/// Escapes C0 control characters into visible symbols.
///
/// With [excludeEscCode] (default) ESC is passed through, so ANSI codes
/// survive; note this also lets user data inject its own ANSI sequences
/// into the output.
final class ControlCodeFormatter with Loggable implements LogPreFormatter {
  final bool excludeEscCode;

  const ControlCodeFormatter({this.excludeEscCode = true});

  @override
  String call(LogTheme theme, String text) {
    final buf = StringBuffer();
    // Стиль применяется вызовом, а не парой open/close: `Style.close` — это
    // безусловный reset, который просачивался бы даже в noColors-вывод.
    final style = theme.data.paddingStyle;

    for (final charCode in text.codeUnits) {
      final controlCode = ansi.ControlFunctionsC0.byIndex(charCode);

      if (controlCode == null ||
          excludeEscCode && controlCode == ansi.ControlFunctionsC0.ESC) {
        buf.writeCharCode(charCode);
      } else {
        if (controlCode.escapeSymbol case final escapeSymbol?) {
          buf.write(style(escapeSymbol));
        } else {
          buf.write(
            style(
              '\\x${charCode.toRadixString(16).toUpperCase().padLeft(2, '0')}',
            ),
          );
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
