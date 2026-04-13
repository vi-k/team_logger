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
  final List<LogFormatter> formatters;
  final List<LogFormatter> stackTraceFormatters;
  final List<LogFormatter> tagsFormatters;
  final LogDivider defaultDivider;
  void Function(int linesCount)? beforeOutput;
  void Function(String) output;
  void Function(int linesCount)? afterOutput;

  final Map<int, ansi.StackedPrinter> _printers;

  ConsoleLogPrinter({
    this.theme = LogTheme.defaultActiveTheme,
    this.defaultDivider = const LogDivider(' '),
    required this.formatters,
    required this.stackTraceFormatters,
    required this.tagsFormatters,
    this.beforeOutput,
    this.output = print,
    this.afterOutput,
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
    theme.registerLevelThemes();
  }

  @override
  void publish(Log log) {
    printLog(log, formatters, alignTags: true);

    if (log.stackTrace != null) {
      printLog(log, stackTraceFormatters, alignTags: false);
    }
  }

  void printLog(
    Log log,
    List<LogFormatter> formatters, {
    required bool alignTags,
  }) {
    final levelTheme = theme[log.level];
    late final defaultDividerBox = defaultDivider(log, levelTheme, null);

    // tags always a top priority

    final tagsBoxes = <LogFormatterBox>[];
    var tagsLength = 0;
    LogFormatter? lastFormatter;

    for (final formatter in tagsFormatters) {
      final box = formatter(log, levelTheme, null);
      if (box.width > 0) {
        if (lastFormatter != null &&
            lastFormatter is! LogDivider &&
            formatter is! LogDivider) {
          tagsBoxes.add(defaultDividerBox);
          tagsLength += defaultDividerBox.width;
        }
        tagsBoxes.add(box);
        tagsLength += box.width;
        lastFormatter = formatter;
      }
    }
    if (tagsLength > 0) {
      tagsLength++; // for divider
    }

    // other formatters

    final boxes = <LogFormatterBox>[];
    var remainingLength = switch (theme.maxLength) {
      null => null,
      final maxLength => maxLength - tagsLength,
    };
    var linesCount = 0;
    lastFormatter = null;

    for (final formatter in formatters) {
      final innerBoxes = <LogFormatterBox>[];
      if (lastFormatter != null &&
          lastFormatter is! LogDivider &&
          formatter is! LogDivider) {
        innerBoxes.add(defaultDividerBox);

        if (remainingLength != null) {
          if (remainingLength < defaultDividerBox.width) {
            break;
          }
          remainingLength -= defaultDividerBox.width;
        }
      }

      final box = formatter(log, levelTheme, remainingLength);
      if (box.width > 0) {
        innerBoxes.add(box);
        if (remainingLength != null) {
          if (remainingLength < box.width) {
            break;
          }
          remainingLength -= box.width;
        }
        boxes.addAll(innerBoxes);
        linesCount = math.max(linesCount, box.lines.length);
        lastFormatter = formatter;
      }
    }

    if (theme.maxLines case final maxLines? when maxLines < linesCount) {
      linesCount = maxLines;
    }

    for (final box in boxes) {
      box.applyHeight(linesCount);
    }

    for (final box in tagsBoxes) {
      box.applyHeight(linesCount);
    }

    beforeOutput?.call(linesCount);
    final printer = _printers[log.level]!;
    for (var i = 0; i < linesCount; i++) {
      for (final box in boxes) {
        printer.write(box.lines[i]);
      }
      if (remainingLength != null && alignTags) {
        printer.write(theme.padding * (remainingLength + 1));
      } else {
        printer.write(theme.padding);
      }
      for (final box in tagsBoxes) {
        printer.write(box.lines[i]);
      }
      printer.writeln();
    }
    afterOutput?.call(linesCount);
  }
}
