import 'package:stack_trace/stack_trace.dart';

import '../logger/log.dart';
import '../theme/log_theme.dart';
import 'constraints.dart';
import 'log_block.dart';
import 'log_row.dart';
import 'log_text_align.dart';
import 'log_vertical_align.dart';

final class LogStackTrace implements LogBlock {
  final Constraints constraints;
  final LogTextAlign textAlign;
  final LogVerticalAlign verticalAlign;
  final bool terse;
  final bool showTitle;
  final String title;
  final bool showIndexes;

  const LogStackTrace({
    this.constraints = const Constraints.unlimited(),
    this.textAlign = LogTextAlign.left,
    this.verticalAlign = LogVerticalAlign.top,
    this.terse = true,
    this.showTitle = true,
    this.title = 'STACKTRACE',
    this.showIndexes = false,
  });

  @override
  LogBox call(
    Log log,
    LogLevelTheme theme,
    LogRow row,
    int? remainingLength,
  ) {
    final stackTrace = log.stackTrace;
    if (stackTrace == null || stackTrace == StackTrace.empty) {
      return LogBox.empty();
    }

    var trace = Trace.from(stackTrace);
    if (terse) {
      trace = trace.terse;
    }

    var lines = trace.frames.indexed.map(
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
        return '${showIndexes ? '${theme.dimStyle('#$index')} ' : ''}'
            '${theme.boldStyle(member ?? '')}'
            ' (${frame.library}$position)';
      },
    ).toList();

    if (row.singleLine) {
      lines = [lines.join(theme.punctuationStyle(', '))];
    }

    if (showTitle) {
      lines.insert(0, theme.dataSectionStyle('$title${theme.common.colon}'));
      if (row.singleLine) {
        lines = [lines.join(theme.punctuationStyle(' '))];
      }
    }

    return LogBox(
      log,
      theme,
      lines,
      constraints: constraints.restrict(remainingLength),
      textAlign: textAlign,
      verticalAlign: verticalAlign,
      debugName: 'stack_trace',
    );
  }
}
