import '../loggable/loggable.dart';
import '../logger/log.dart';
import '../theme/log_theme.dart';
import 'constraints.dart';
import 'log_formatter.dart';
import 'text_align.dart';

abstract interface class LogMessageFormatter implements LogFormatter {
  const factory LogMessageFormatter({
    Constraints constraints,
    TextAlign textAlign,
    VerticalAlign verticalAlign,
  }) = _LogMessageFormatter;
}

final class _LogMessageFormatter implements LogMessageFormatter {
  final Constraints constraints;
  final TextAlign textAlign;
  final VerticalAlign verticalAlign;

  const _LogMessageFormatter({
    this.constraints = const Constraints.unlimited(),
    this.textAlign = TextAlign.left,
    this.verticalAlign = VerticalAlign.top,
  });

  @override
  int get priority => 9999;

  @override
  LogFormatterBox call(
    Log log,
    LogLevelTheme theme,
    int? maxLength,
    int? maxLines,
  ) {
    final message = theme.formatMessage(theme.formatValue(log.message));

    var error = '';
    if (log.error case final err?) {
      final errorStr = theme.formatValue(err.toString());
      final styledStr = theme.formatMessage('[error]$errorStr[/error]');

      error = '${theme.styledColon} $styledStr';
    }

    final data = switch (log.data) {
      null => '',
      final data =>
        '${theme.styledColon} ${Loggable.objectToString(data, theme: theme)}',
    };

    return LogFormatterBox.fromText(
      log,
      theme,
      '$message$error$data',
      maxLines: maxLength,
      constraints: constraints.restrict(maxLength),
      textAlign: textAlign,
      verticalAlign: verticalAlign,
    );
  }
}
