import 'package:stack_trace/stack_trace.dart';

import '../logger/log.dart';
import '../theme/log_theme.dart';
import 'constraints.dart';
import 'log_formatter.dart';
import 'text_align.dart';

abstract interface class LogStackTraceFormatter implements LogFormatter {
  const factory LogStackTraceFormatter({
    Constraints constraints,
    TextAlign textAlign,
    VerticalAlign verticalAlign,
    bool terse,
  }) = _LogStackTraceFormatter;
}

final class _LogStackTraceFormatter implements LogStackTraceFormatter {
  final Constraints constraints;
  final TextAlign textAlign;
  final VerticalAlign verticalAlign;
  final bool terse;

  const _LogStackTraceFormatter({
    this.constraints = const Constraints.unlimited(),
    this.textAlign = TextAlign.left,
    this.verticalAlign = VerticalAlign.top,
    this.terse = true,
  });

  @override
  LogFormatterBox call(Log log, LogLevelTheme theme, int? remainingLength) {
    final stackTrace = log.stackTrace;
    if (stackTrace == null || stackTrace == StackTrace.empty) {
      return LogFormatterBox.empty();
    }

    // final tags = theme.allTags(log);
    // final tagsStr = tags.isEmpty
    //     ? ''
    //     : ' ${theme.tagsStyle(tags.map((tag) => '#$tag').join(' '))}';

    var trace = Trace.from(stackTrace);
    if (terse) {
      trace = trace.terse;
    }
    // final traceList = trace.frames.map((e) => '$e$tagsStr').toList();
    final traceList = trace.frames.indexed.map(
      (e) {
        final (index, frame) = e;
        final member = frame.member;
        var position = '';
        if (frame.line case final line?) {
          position = ':$line';
          if (frame.column case final column?) {
            position = '$position:$column';
          }
        }
        return '${theme.dimStyle('#$index')}'
            ' ${theme.boldStyle(member ?? '')}'
            ' (${frame.library}$position)';
      },
    ).toList();

    return LogFormatterBox(
      log,
      theme,
      traceList,
      constraints: constraints.restrict(remainingLength),
      textAlign: textAlign,
      verticalAlign: verticalAlign,
      debugName: 'stack_trace',
    );
  }
}
