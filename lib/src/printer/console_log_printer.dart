import 'dart:math' as math;

import 'package:ansi_escape_codes/ansi_escape_codes.dart' as ansi;
import 'package:logger_builder/logger_builder.dart';

import '../logger/log_levels.dart';
import '../logger/logger.dart';
import '../theme/log_theme.dart';
import 'log_block.dart';
import 'log_divider.dart';
import 'log_row.dart';

final class ConsoleLogPrinter implements CustomLogPublisher<Log> {
  final LogTheme theme;
  final List<LogRow> rows;
  void Function(int linesCount)? beforeOutput;
  void Function(String) output;
  void Function(int linesCount)? afterOutput;

  final _printers = <int, ansi.StackedPrinter>{};

  ConsoleLogPrinter({
    LogTheme? theme,
    required this.rows,
    this.beforeOutput,
    this.output = print,
    this.afterOutput,
  }) : theme = theme ?? LogTheme.defaultActiveTheme {
    _printers.addAll({
      LogLevels.verbose: ansi.StackedPrinter(
        defaultStyle: this.theme.verbose.normal,
        output: output,
      ),
      LogLevels.debug: ansi.StackedPrinter(
        defaultStyle: this.theme.debug.normal,
        output: output,
      ),
      LogLevels.info: ansi.StackedPrinter(
        defaultStyle: this.theme.info.normal,
        output: output,
      ),
      LogLevels.warning: ansi.StackedPrinter(
        defaultStyle: this.theme.warning.normal,
        output: output,
      ),
      LogLevels.error: ansi.StackedPrinter(
        defaultStyle: this.theme.error.normal,
        output: output,
      ),
      LogLevels.critical: ansi.StackedPrinter(
        defaultStyle: this.theme.critical.normal,
        output: output,
      ),
    });
    this.theme.registerLevelThemes();
  }

  @override
  void publish(Log log) {
    for (final row in rows) {
      if (row.when?.call(log) ?? true) {
        printRow(log, row);
      }
    }
  }

  void printRow(Log log, LogRow row) {
    final levelTheme = theme[log.level];
    late final defaultDividerBox =
        row.defaultDivider(log, levelTheme, row, null);

    // tail first

    final tailBoxes = <LogBox>[];
    var tailLength = 0;
    LogBlock? lastBlock;

    for (final block in row.tail) {
      final box = block(log, levelTheme, row, null);
      if (box.width > 0) {
        if ((lastBlock == null || lastBlock is! LogDivider) &&
            block is! LogDivider) {
          tailBoxes.add(defaultDividerBox);
          tailLength += defaultDividerBox.width;
        }
        tailBoxes.add(box);
        tailLength += box.width;
        lastBlock = block;
      }
    }

    // other blocks

    final boxes = <LogBox>[];
    var remainingLength = switch (row.maxLength) {
      null => null,
      final maxLength => maxLength - tailLength,
    };
    var linesCount = 0;
    lastBlock = null;

    for (final block in row.children) {
      final innerBoxes = <LogBox>[];
      var currentWidth = 0;

      if (lastBlock != null &&
          lastBlock is! LogDivider &&
          block is! LogDivider) {
        innerBoxes.add(defaultDividerBox);
        currentWidth += defaultDividerBox.width;
      }

      final box = block(
        log,
        levelTheme,
        row,
        remainingLength == null ? null : remainingLength - currentWidth,
      );
      if (box.width > 0) {
        innerBoxes.add(box);
        currentWidth += box.width;

        if (remainingLength != null) {
          if (remainingLength < currentWidth) {
            break;
          }
          remainingLength -= currentWidth;
        }
        boxes.addAll(innerBoxes);
        linesCount = math.max(linesCount, box.lines.length);
        lastBlock = block;
      }
    }

    if (row.maxLines case final maxLines? when maxLines < linesCount) {
      linesCount = maxLines;
    }

    for (final box in boxes) {
      box.applyHeight(linesCount);
    }

    for (final box in tailBoxes) {
      box.applyHeight(linesCount);
    }

    beforeOutput?.call(linesCount);
    final printer = _printers[log.level]!;
    for (var i = 0; i < linesCount; i++) {
      for (final box in boxes) {
        printer.write(box.lines[i]);
      }
      if (remainingLength != null && row.alignTail) {
        printer.write(theme.padding * remainingLength);
      }
      for (final box in tailBoxes) {
        printer.write(box.lines[i]);
      }
      printer.writeln();
    }
    afterOutput?.call(linesCount);
  }
}
