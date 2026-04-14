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
  final Set<String> controlledPackages;

  const LogStackTrace({
    this.constraints = const Constraints.unlimited(),
    this.textAlign = LogTextAlign.left,
    this.verticalAlign = LogVerticalAlign.top,
    this.terse = true,
    this.showTitle = true,
    this.title = 'STACKTRACE',
    this.showIndexes = false,
    this.controlledPackages = const {},
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
        var posStr = '';
        if (frame.line case final line?) {
          posStr = ':$line';
          if (frame.column case final column?) {
            posStr = '$posStr:$column';
          }
        }

        final indexStr = showIndexes ? '#$index ' : '';
        final memberStr = member == null ? '' : '$member ';
        var fileStr = frame.library;
        var packageStr = '';

        final uri = frame.uri;
        var isActive = uri.scheme == 'file';
        if (uri.scheme == 'package') {
          isActive = controlledPackages.contains(uri.pathSegments.first);
        }

        String stackTraceLine(String file) {
          final style = isActive
              ? theme.stackTraceActiveStyle
              : theme.stackTraceInactiveStyle;
          return style('$indexStr$memberStr($packageStr$file$posStr)');
        }

        if (remainingLength == null) {
          return stackTraceLine(fileStr);
        }

        // truncate file path

        var availableWidth = remainingLength -
            indexStr.length -
            memberStr.length -
            posStr.length -
            2;
        if (fileStr.startsWith('package:') || fileStr.startsWith('dart:')) {
          final index = fileStr.indexOf('/');
          if (index != -1) {
            availableWidth -= index;
            packageStr = fileStr.substring(0, index + 1);
            fileStr = fileStr.substring(index + 1);
          }
        }
        if (fileStr.length <= availableWidth) {
          return stackTraceLine(fileStr);
        }

        final ellipsis = theme.common.ellipsis;

        var truncated = false;
        while (fileStr.length + ellipsis.length + 1 > availableWidth) {
          final index = fileStr.indexOf('/');
          if (index == -1) break;
          truncated = true;
          fileStr = fileStr.substring(index + 1);
        }
        if (truncated) {
          fileStr = '${theme.ellipsisStyle(ellipsis)}/$fileStr';
        }

        return stackTraceLine(fileStr);
      },
    ).toList();

    if (row.singleLine) {
      lines = [lines.join(theme.punctuationStyle(', '))];
    }

    if (showTitle) {
      lines.insert(0, theme.sectionStyle('$title${theme.common.colon}'));
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
