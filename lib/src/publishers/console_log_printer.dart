import 'dart:math' as math;

import 'package:ansi_escape_codes/ansi_escape_codes.dart' as ansi;
import 'package:logger_builder/logger_builder.dart';

import '../log_formatters/log_divider.dart';
import '../log_formatters/log_formatter.dart';
import '../logger/log.dart';
import '../logger/log_levels.dart';
import 'log_theme.dart';

final class ConsoleLogPrinter implements CustomLogPublisher<Log> {
  final LogTheme theme;
  final List<LogFormatter> _formatters = [];
  final LogDivider defaultDivider;
  void Function(String) output;

  final Map<int, ansi.StackedPrinter> _printers;

  ConsoleLogPrinter({
    this.theme = LogTheme.defaultTheme,
    this.defaultDivider = const LogDivider(' '),
    required List<LogFormatter> formatters,
    this.output = print,
  }) : _printers = {
          LogLevels.verbose: ansi.StackedPrinter(
            defaultStyle: theme.normal.verbose,
            output: output,
          ),
          LogLevels.debug: ansi.StackedPrinter(
            defaultStyle: theme.normal.debug,
            output: output,
          ),
          LogLevels.info: ansi.StackedPrinter(
            defaultStyle: theme.normal.info,
            output: output,
          ),
          LogLevels.warning: ansi.StackedPrinter(
            defaultStyle: theme.normal.warning,
            output: output,
          ),
          LogLevels.error: ansi.StackedPrinter(
            defaultStyle: theme.normal.error,
            output: output,
          ),
          LogLevels.critical: ansi.StackedPrinter(
            defaultStyle: theme.normal.critical,
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
  }

  @override
  void publish(Log log) {
    var remainingWidth = theme.maxLength;
    final boxes = <LogFormatterBox>[];
    var linesCount = 0;

    for (final formatter in _formatters) {
      final box = formatter(log, theme, remainingWidth);
      boxes.add(box);
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
      box.applyHeight(linesCount);
    }

    final printer = _printers[log.level]!;
    for (var i = 0; i < linesCount; i++) {
      for (final box in boxes) {
        printer.write(box.lines[i]);
      }
      printer.writeln();
    }
  }
}
