import '../loggable/loggable.dart';
import '../loggable/loggable_multi_data.dart';
import '../logger/logger.dart';
import '../theme/log_theme.dart';
import 'constraints.dart';
import 'log_block.dart';
import 'log_row.dart';
import 'log_stack_trace.dart';
import 'log_text_align.dart';
import 'log_vertical_align.dart';

final class LogMessage implements LogBlock {
  static final _stackTracerExpando = Expando<LogStackTrace>();

  final Constraints constraints;
  final LogTextAlign textAlign;
  final LogVerticalAlign verticalAlign;
  final bool showStackTrace;
  final bool stackTraceTerse;
  final bool stackTraceShowIndexes;
  final Set<String> controlledPackages;

  const LogMessage({
    this.constraints = const Constraints.unlimited(),
    this.textAlign = LogTextAlign.left,
    this.verticalAlign = LogVerticalAlign.top,
    this.showStackTrace = false,
    this.stackTraceTerse = true,
    this.stackTraceShowIndexes = false,
    this.controlledPackages = const {},
  });

  @override
  LogBox call(Log log, LogLevelTheme theme, LogRow row, int? remainingLength) {
    final messageStr = switch (log.message) {
      '' => '',
      final message => theme.formatMessage(theme.formatValue(message)),
    };

    var dataStr = '';
    if (log.hasData) {
      var dataOnNewLine = false;
      final data = log.data;
      if (data is! LoggableMultiData) {
        dataStr = Loggable.objectToString(log.data, theme: theme);
      } else {
        dataOnNewLine = !row.singleLine;
        dataStr = data.data.entries.map((e) {
          final value = Loggable.objectToString(
            e.value,
            theme: theme,
            config: data.config,
          );

          return switch (e.key) {
            '' => value,
            final key =>
              '${theme.sectionStyle(key)}${theme.styledColon} $value',
          };
        }).join(row.singleLine ? theme.punctuation(', ') : '\n');
      }

      if (messageStr.isNotEmpty) {
        dataStr =
            dataOnNewLine ? '\n$dataStr' : '${theme.styledColon} $dataStr';
      }
    }

    var errorStr = '';
    if (log.error case final error?) {
      final errorTheme = theme.common.error;
      errorStr = errorTheme
          .normal(theme.formatMessage(theme.formatValue(error.toString())));
      if (messageStr.isNotEmpty || log.hasData) {
        final colon = errorTheme.styledColon;
        final newLine = !row.singleLine &&
            (theme.common.errorAlwaysOnNewLine || log.hasData);
        errorStr = switch (newLine) {
          true when theme.common.errorTitle.isNotEmpty =>
            '\n${errorTheme.sectionStyle(theme.common.errorTitle)}'
                '$colon $errorStr',
          true => '\n$errorStr',
          false => '$colon $errorStr',
        };
      }
    }

    var messageBox = LogBox.fromText(
      log,
      theme,
      '$messageStr$dataStr$errorStr',
      maxLines: row.maxLines,
      constraints: constraints.restrict(remainingLength),
      textAlign: textAlign,
      verticalAlign: verticalAlign,
      debugName: 'message',
    );

    final stackTrace = log.stackTrace;
    if (showStackTrace &&
        stackTrace != null &&
        stackTrace != StackTrace.empty) {
      final stackTracer = _stackTracerExpando[this] ??= LogStackTrace(
        constraints: constraints,
        textAlign: textAlign,
        terse: stackTraceTerse,
        showIndexes: stackTraceShowIndexes,
        controlledPackages: controlledPackages,
      );
      final stackTraceBox = stackTracer(log, theme, row, remainingLength);

      messageBox = LogBox(
        log,
        theme,
        [...messageBox.lines, ...stackTraceBox.lines],
        constraints: constraints,
        textAlign: textAlign,
        verticalAlign: verticalAlign,
        debugName: 'message',
      );
    }

    return messageBox;
  }
}
