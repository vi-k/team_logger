import 'dart:math' as math;

import 'package:ansi_escape_codes/ansi_escape_codes.dart' as ansi;
import 'package:logger_builder/logger_builder.dart';

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

  /// Разделитель пути неймспейсов для префикс-матчинга [activeNamespaces]
  /// (см. `Logger.pathSeparator`).
  final String pathSeparator;

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
    this.pathSeparator = '/',
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
      // Неймспейс активирует и себя, и дочерние: 'app' матчит 'app'
      // и 'app/...', но не 'application'.
      activeNamespaces.any(
        (ns) => log.path == ns || log.path.startsWith('$ns$pathSeparator'),
      ) ||
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
    // Порог — минимум из двух тем: активный лог не должен подавляться
    // сильнее фонового того же уровня.
    final minLevel = switch (inactiveTheme) {
      null => theme.minLevel,
      final inactive => math.min(this.theme.minLevel, inactive.minLevel),
    };
    if (log.level < minLevel) {
      return;
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
      ansiCodesEnabled: main.ansiCodesEnabled,
      output: output,
    );

    late final defaultDividerBox = row.defaultDivider(log, theme, row, null);

    // tail first

    final tailBoxes = <LogBox>[];
    var tailLength = 0;
    LogBlock? lastBlock;

    for (final block in row.tail) {
      final needDivider = (lastBlock == null || lastBlock is! LogDivider) &&
          block is! LogDivider;
      final dividerWidth = needDivider ? defaultDividerBox.width : 0;
      // Tail ограничен maxLength: иначе при широком tail все children
      // получили бы отрицательный лимит и строка лога молча пропадала бы.
      final available = switch (row.maxLength) {
        null => null,
        final maxLength => maxLength - tailLength - dividerWidth,
      };
      if (available != null && available <= 0) break;

      final box = block(log, theme, row, available);
      if (box.width > 0) {
        if (available != null && box.width > available) break;
        if (needDivider) {
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
    // Высота строки учитывает и tail: если все children пусты, строка
    // всё равно печатается.
    var linesCount = tailBoxes.fold(
      0,
      (count, box) => math.max(count, box.lines.length),
    );
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
