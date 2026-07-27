import 'dart:math' as math;

import 'package:ansi_escape_codes/ansi_escape_codes.dart' as ansi;
import 'package:logger_builder/logger_builder.dart';

import '../loggable/loggable.dart';
import '../logger/log_levels.dart';
import '../logger/logger.dart';
import '../theme/log_main_theme.dart';
import 'log_block.dart';
import 'log_divider.dart';
import 'log_row.dart';

final class ConsoleLogPrinter implements CustomLogPublisher<Log> {
  final LogMainTheme theme;
  final LogMainTheme? inactiveTheme;
  final bool Function(Log log)? isLogActive;
  final Set<int> activeLevels;
  final Set<String> activeNamespaces;
  final Set<String> activeTraceGroups;
  final Set<String> activeTags;
  final List<LogRow> rows;
  void Function(String) output;

  final _printers = <(bool, int), ansi.StackedPrinter>{};

  ConsoleLogPrinter({
    LogMainTheme? theme,
    this.inactiveTheme,
    int? activeMinLevel,
    Set<int>? activeLevels,
    Set<String>? activeNamespaces,
    Set<String>? activeTraceGroups,
    Set<String>? activeTags,
    this.isLogActive,
    required this.rows,
    this.output = print,
  })  : assert(
          inactiveTheme != null ||
              activeMinLevel == null &&
                  activeLevels == null &&
                  activeNamespaces == null &&
                  activeTraceGroups == null &&
                  activeTags == null &&
                  isLogActive == null,
          'inactiveTheme must be set first',
        ),
        theme = theme ?? LogMainTheme.defaultActiveTheme,
        activeLevels = _buildLevels(activeLevels, activeMinLevel),
        activeNamespaces = activeNamespaces ?? {},
        activeTraceGroups = activeTraceGroups ?? {},
        activeTags = activeTags ?? {};

  bool _isLogActive(Log log) =>
      inactiveTheme == null ||
      (isLogActive?.call(log) ?? false) ||
      activeLevels.contains(log.level) ||
      activeNamespaces.contains(log.path) ||
      log.traceIds.any((e) => activeTraceGroups.contains(e.group)) ||
      log.tags.any(activeTags.contains);

  static Set<int> _buildLevels(Set<int>? levels, int? minLevel) {
    final result = <int>{};

    if (levels != null) {
      for (final l in LogLevels.values) {
        if (levels.contains(l)) {
          result.add(l);
        }
      }
    }

    if (minLevel != null) {
      result.addAll(LogLevels.levels(minLevel));
    }

    return result;
  }

  @override
  void publish(Log log) {
    final isActive = _isLogActive(log);
    final theme = (isActive ? this.theme : inactiveTheme ?? this.theme);
    if (log.level < theme.minLevel) {
      return;
    }

    // TODO: убрать
    // print(Loggable.objectToJson(log));
    if (log.hasData) {
      print(Loggable.objectToJson(log.data));
    }

    for (final row in rows) {
      if (row.when?.call(log) ?? true) {
        printRow(log, row, isActive, theme);
      }
    }
  }

  void printRow(Log log, LogRow row, bool isActive, LogMainTheme main) {
    final theme = main[log.level];
    final printer = _printers[(isActive, log.level)] ??= ansi.StackedPrinter(
      defaultStyle: theme.data.normal,
      ansiCodesEnabled: main != LogMainTheme.noColors,
      output: output,
    );

    late final defaultDividerBox = row.defaultDivider(log, theme, row, null);

    // tail first

    final tailBoxes = <LogBox>[];
    var tailLength = 0;
    LogBlock? lastBlock;

    for (final block in row.tail) {
      final box = block(log, theme, row, null);
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
        theme,
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
        printer.write(theme.styledPadding(remainingLength));
      }
      for (final box in tailBoxes) {
        printer.write(box.lines[i]);
      }
      printer.writeln();
    }
  }
}
