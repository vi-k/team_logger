import 'package:ansi_escape_codes/style.dart' as ansi;

import '../loggable/loggable.dart';
import '../theme/log_main_theme.dart';
import 'log_pre_formatter.dart';

/// Escapes C0 control characters into visible symbols.
///
/// With [excludeEscCode] (the default) ESC is passed through so that ANSI
/// codes survive the render. That is safe here because the sequences are
/// already gone by the time this runs: `LoggableConfig.escapeAnsiCodes`,
/// on by default, shows them rather than sending them. See "Untrusted Text
/// and Terminal Output" in the README for where the trust boundary runs.
///
/// `excludeEscCode: false` escapes ESC into `\\x1B` text everywhere,
/// properties included. It is not the way to reach for: `escapeAnsiCodes`
/// in `LoggableConfig` — on by default — shows the sequence as its parts
/// instead, is readable, and takes the config layers, so a policy set in
/// `Loggable.forceConfig` cannot be lifted at a call site.
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
