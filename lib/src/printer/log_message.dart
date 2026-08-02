import '../loggable/loggable.dart';
import '../loggable/loggable_multi_data.dart';
import '../logger/logger.dart';
import '../theme/log_main_theme.dart';
import 'constraints.dart';
import 'log_block.dart';
import 'log_row.dart';
import 'log_stack_trace.dart';
import 'log_text_align.dart';
import 'log_vertical_align.dart';

final class LogMessage implements LogBlock {
  static final _stackTracerExpando = Expando<LogStackTrace>();

  final LogConstraints constraints;
  final LogTextAlign textAlign;
  final LogVerticalAlign verticalAlign;
  final bool showStackTrace;
  final bool stackTraceTerse;
  final bool stackTraceShowIndexes;
  final Set<String> controlledPackages;

  const LogMessage({
    this.constraints = const LogConstraints.unlimited(),
    this.textAlign = LogTextAlign.left,
    this.verticalAlign = LogVerticalAlign.top,
    this.showStackTrace = true,
    this.stackTraceTerse = true,
    this.stackTraceShowIndexes = false,
    this.controlledPackages = const {},
  });

  @override
  LogBox call(Log log, LogTheme theme, LogRow row, int? remainingLength) {
    final messageStr = switch (log.message) {
      '' => '',
      final message => theme.formatMessage(theme.formatValue(message)),
    };

    var dataStr = '';
    if (log.hasData) {
      var dataOnNewLine = false;
      // An empty rendering means nothing by itself: an empty
      // LoggableMultiData and a builder without props both render empty
      // legitimately, and so may a replacement the rule returned. Only
      // Sanitize.drop removes the data block, and that signal comes out
      // of band from whoever offered the value — never from the emptiness
      // of the text nor from the mere presence of an installed rule.
      var dropped = false;
      final data = log.data;
      if (data is! LoggableMultiData) {
        final rendered = Loggable.renderRoot(data, theme: theme);
        dataStr = rendered.text;
        dropped = rendered.dropped;
      } else if (Loggable.sanitizeRootToString(
        data,
        theme: theme,
        config: data.config,
      )
          case final rendered?) {
        // The rule was offered the whole data object and dropped or
        // replaced it. Both the sanitize and the rendering of the result
        // live in that one helper — the same one Loggable.objectToString
        // uses — because this branch never reaches the walker: it goes
        // straight into the section loop below, and a root offered
        // nowhere is a root that leaks.
        dataStr = rendered.text;
        dropped = rendered.dropped;
      } else {
        dataOnNewLine = !row.singleLine &&
            (data.data.isEmpty || data.data.keys.first.isNotEmpty);

        // The section layout is duplicated here (the printer needs the
        // per-section line split), but the per-entry sanitize is not:
        // it lives in Loggable.forEachMultiDataEntry. Walking
        // `data.data.entries` directly would hand every section value to
        // the walker as a ROOT — unnamed, with an empty path — so
        // name-based rules would never fire on a section.
        final parts = <String>[];
        final anyDropped = Loggable.forEachMultiDataEntry(data, (key, value) {
          final text = Loggable.objectToString(
            value,
            theme: theme,
            config: data.config,
          );

          parts.add(
            key.isEmpty
                ? text
                : '${theme.data.sectionStyle(key)}${theme.styledColon} $text',
          );
        });
        dataStr =
            parts.join(row.singleLine ? theme.data.punctuation(', ') : '\n');
        // Every section was dropped: the label would be left dangling
        // over nothing. A multi-data that is empty on its own keeps its
        // colon — nothing was dropped there, so this stays false.
        dropped = parts.isEmpty && anyDropped;
      }

      // A dropped value leaves no data block: a colon with nothing after
      // it would be noise. Anything else is printed exactly as before —
      // an empty data object still gets its colon.
      if (messageStr.isNotEmpty && !dropped) {
        dataStr =
            dataOnNewLine ? '\n$dataStr' : '${theme.styledColon} $dataStr';
      }
    }

    var errorStr = '';
    if (log.error case final error?) {
      final errorTheme = theme.main.error;
      errorStr = errorTheme.data
          .normal(theme.formatMessage(theme.formatValue(error.toString())));
      if (messageStr.isNotEmpty || log.hasData) {
        final colon = errorTheme.styledColon;
        final newLine =
            !row.singleLine && (theme.main.errorAlwaysOnNewLine || log.hasData);
        errorStr = switch (newLine) {
          true when theme.main.errorTitle.isNotEmpty =>
            '\n${errorTheme.data.sectionStyle(theme.main.errorTitle)}'
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
