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
  final LogTheme? inactiveTheme;
  final bool Function(Log log)? isActive;
  final int activeLevel;
  final Set<String> activeLoggers;
  final Set<String> activeTraceGroups;
  final Set<String> activeTags;
  final List<LogRow> rows;
  void Function(String) output;

  final _printers = <(bool, int), ansi.StackedPrinter>{};

  ConsoleLogPrinter({
    LogTheme? theme,
    this.inactiveTheme,
    this.activeLevel = LogLevels.off,
    this.activeLoggers = const {},
    this.activeTraceGroups = const {},
    this.activeTags = const {},
    this.isActive,
    required this.rows,
    this.output = print,
  })  : assert(
          inactiveTheme != null ||
              activeLoggers.isEmpty &&
                  activeTraceGroups.isEmpty &&
                  activeTags.isEmpty &&
                  isActive == null,
          'inactiveTheme must be set first',
        ),
        theme = theme ?? LogTheme.defaultActiveTheme {
    this.theme.registerLevelThemes();
    inactiveTheme?.registerLevelThemes();
  }

  bool _isActive(Log log) =>
      inactiveTheme == null ||
      log.level >= activeLevel ||
      (isActive?.call(log) ?? false) ||
      activeLoggers.contains(log.path) ||
      log.traceIds.any((e) => activeTraceGroups.contains(e.group)) ||
      log.tags.any(activeTags.contains);

  @override
  void publish(Log log) {
    final isActive = _isActive(log);
    final theme = (isActive ? this.theme : inactiveTheme ?? this.theme);
    if (log.level < theme.minLevel) {
      return;
    }

    for (final row in rows) {
      if (row.when?.call(log) ?? true) {
        printRow(log, row, isActive, theme);
      }
    }
  }

  void printRow(Log log, LogRow row, bool isActive, LogTheme theme) {
    final levelTheme = theme[log.level];
    final printer = _printers[(isActive, log.level)] ??= ansi.StackedPrinter(
      defaultStyle: levelTheme.normal,
      output: output,
    );

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
  }
}
