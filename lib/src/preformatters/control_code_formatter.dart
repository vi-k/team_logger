import 'package:ansi_escape_codes/style.dart' as ansi;

import '../loggable/loggable.dart';
import '../theme/log_main_theme.dart';
import 'log_pre_formatter.dart';

/// Escapes C0 control characters into visible symbols.
///
/// With [excludeEscCode] (the default) ESC is passed through so that ANSI
/// codes survive the render. That passthrough is not selective: text that
/// arrived from outside the program carries its own control sequences to
/// the terminal intact, where they can clear the screen, move the cursor,
/// overwrite lines already printed, recolor the rest of the output or forge
/// an OSC 8 hyperlink. The package does not draw that trust boundary — see
/// "Untrusted Text and Terminal Output" in the README.
///
/// `excludeEscCode: false` escapes ESC as well. It is a working strict mode
/// for the message and for values inside plain containers, but not for
/// `Loggable`/`LoggableData` properties: `Prop.toLogString` runs the value
/// formatter a second time over text the theme has already styled, so the
/// theme's own codes are escaped along with the injected ones and the
/// property output falls apart.
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
