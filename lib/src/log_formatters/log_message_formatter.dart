import '../log_pre_formatters/log_pre_formatter.dart';
import '../loggable/loggable.dart';
import '../loggable/multi_data.dart';
import '../logger/log.dart';
import '../publishers/log_theme.dart';
import 'constraints.dart';
import 'log_formatter.dart';
import 'text_align.dart';

abstract interface class LogMessageFormatter implements LogFormatter {
  const factory LogMessageFormatter({
    LogPreFormatter? messagePreFormatter,
    LogPreFormatter? dataPreFormatter,
    Constraints constraints,
    TextAlign textAlign,
    VerticalAlign verticalAlign,
  }) = _LogMessageFormatter;
}

final class _LogMessageFormatter implements LogMessageFormatter {
  final LogPreFormatter? messagePreFormatter;
  final LogPreFormatter? dataPreFormatter;
  final Constraints constraints;
  final TextAlign textAlign;
  final VerticalAlign verticalAlign;

  const _LogMessageFormatter({
    this.messagePreFormatter,
    this.dataPreFormatter,
    this.constraints = const Constraints.unlimited(),
    this.textAlign = TextAlign.left,
    this.verticalAlign = VerticalAlign.top,
  });

  @override
  LogFormatterBox call(Log log, LogTheme theme, int? maxWidth) {
    final message =
        messagePreFormatter?.call(log, theme, log.message) ?? log.message;

    final format = switch (dataPreFormatter?.call) {
      null => null,
      final format => (String text) => format(log, theme, text),
    };

    final dataTheme = theme.toDataTheme(log.level);
    final data = switch (log.data) {
      null => '',
      MultiData(:final data) => '${theme.colon(log)} ${data.entries.map((e) {
          final value = Loggable.objectToString(
            e.value,
            theme: dataTheme,
            preformat: format,
          );
          return '${dataTheme.title('[${e.key}]')} $value';
        }).join(', ')}',
      final Object data => '${theme.colon(log)} ${Loggable.objectToString(
          data,
          theme: dataTheme,
          preformat: format,
        )}',
    };

    return LogFormatterBox.fromText(
      log,
      theme,
      '$message$data',
      constraints: constraints.restrict(maxWidth),
      textAlign: textAlign,
      verticalAlign: verticalAlign,
    );
  }
}
