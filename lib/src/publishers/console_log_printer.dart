import 'dart:math' as math;

import 'package:ansi_escape_codes/ansi_escape_codes.dart' as ansi;
import 'package:logger_builder/logger_builder.dart';

import '../log_formatters/log_divider.dart';
import '../log_formatters/log_formatter.dart';
import '../logger/log.dart';
import '../logger/log_levels.dart';
import '../theme/log_theme.dart';

final class ConsoleLogPrinter implements CustomLogPublisher<Log> {
  final LogTheme theme;
  final List<LogFormatter> _formatters = [];
  final LogDivider defaultDivider;
  void Function() outputStart;
  void Function(String) output;
  void Function() outputFinish;

  final Map<int, ansi.StackedPrinter> _printers;

  ConsoleLogPrinter({
    this.theme = LogTheme.defaultActiveTheme,
    this.defaultDivider = const LogDivider(' '),
    required List<LogFormatter> formatters,
    this.outputStart = _voidCallback,
    this.output = print,
    this.outputFinish = _voidCallback,
  }) : _printers = {
          LogLevels.verbose: ansi.StackedPrinter(
            defaultStyle: theme.verbose.normalStyle,
            output: output,
          ),
          LogLevels.debug: ansi.StackedPrinter(
            defaultStyle: theme.debug.normalStyle,
            output: output,
          ),
          LogLevels.info: ansi.StackedPrinter(
            defaultStyle: theme.info.normalStyle,
            output: output,
          ),
          LogLevels.warning: ansi.StackedPrinter(
            defaultStyle: theme.warning.normalStyle,
            output: output,
          ),
          LogLevels.error: ansi.StackedPrinter(
            defaultStyle: theme.error.normalStyle,
            output: output,
          ),
          LogLevels.critical: ansi.StackedPrinter(
            defaultStyle: theme.critical.normalStyle,
            output: output,
          ),
        } {
    LogFormatter lastFormatter = defaultDivider;
    for (final formatter in formatters) {
      if (formatter is! LogDivider && lastFormatter is! LogDivider) {
        _formatters.add(defaultDivider);
      }
      _formatters.add(formatter);
      lastFormatter = formatter;
    }

    theme.registerLevelThemes();
  }

  @override
  void publish(Log log) {
    final levelTheme = theme[log.level];
    final formattersByPriority = _formatters.indexed.toList()
      ..sort((a, b) => a.$2.priority.compareTo(b.$2.priority));

    final boxes = List<LogFormatterBox?>.filled(_formatters.length, null);
    var remainingWidth = theme.maxLength;
    var linesCount = 0;

    for (final (index, formatter) in formattersByPriority) {
      final box = boxes[index] = formatter(log, levelTheme, remainingWidth);
      linesCount = math.max(linesCount, box.lines.length);
      if (remainingWidth != null) {
        remainingWidth -= box.width;
        if (remainingWidth <= 0) {
          break;
        }
      }
    }

    if (theme.maxLines case final maxLines? when maxLines < linesCount) {
      linesCount = maxLines;
    }

    for (final box in boxes) {
      box?.applyHeight(linesCount);
    }

    outputStart();
    final printer = _printers[log.level]!;
    for (var i = 0; i < linesCount; i++) {
      for (final box in boxes) {
        if (box != null) {
          printer.write(box.lines[i]);
        }
      }
      printer.writeln();
    }
    outputFinish();
  }

  static void _voidCallback() {}
}
