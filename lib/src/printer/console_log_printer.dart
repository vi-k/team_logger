import 'dart:math' as math;

import 'package:ansi_escape_codes/ansi_escape_codes.dart' as ansi;
import 'package:logger_builder/logger_builder.dart';

import '../logger/log_levels.dart';
import '../logger/logger.dart';
import '../theme/log_main_theme.dart';
import 'log_block.dart';
import 'log_divider.dart';
import 'log_row.dart';

/// The main console publisher: prints logs using a data-driven row layout.
///
/// Pass `rows: [LogRow(children: [...], tail: [...])]` where each child is
/// a [LogBlock] element (`LogNum`, `LogLevelName`, `LogTime`, `LogPath`,
/// `LogTraceId`, `LogMessage`, `LogTags`, ...).
///
/// Active vs. inactive styling: pass [inactiveTheme] plus filters
/// ([activeLevels]/`activeMinLevel`, [activeNamespaces] — prefix matching
/// by [pathSeparator], [activeTraceGroups], [activeTags] or [isLogActive],
/// combined with OR) to dim background logs while emphasizing matching
/// ones. Supplying any active filter without [inactiveTheme] throws
/// [ArgumentError]. [output] defaults to `print` and is injectable.
///
/// Note: a `\n` inside a message is escaped by the theme's value
/// formatter; multi-line output comes from data, wrapping and stack
/// traces, not from raw newlines.
final class ConsoleLogPrinter implements CustomLogPublisher<Log> {
  final LogMainTheme theme;
  final LogMainTheme? inactiveTheme;
  final bool Function(Log log)? isLogActive;
  final Set<int> activeLevels;
  final Set<String> activeNamespaces;
  final Set<String> activeTraceGroups;
  final Set<String> activeTags;

  /// Namespace path separator for prefix matching of [activeNamespaces]
  /// (see `Logger.pathSeparator`).
  final String pathSeparator;

  final List<LogRow> rows;

  /// Deliver a log in one [output] call instead of one call per line.
  ///
  /// `false` by default: the printer is line-oriented, and a line is a unit
  /// of its own — each repeats the number, level and time so it can stand
  /// alone in a console or an IDE filter (see the README). A sink whose
  /// unit is an event instead — `dart:developer`, forwarding, grouping —
  /// then has to reassemble the log, and [output] gives it no signal for
  /// where the lines of one log end.
  ///
  /// With `true` the lines of one log — every line of every one of its
  /// [rows], wrapped lines included — are joined with `\n` and sent in a
  /// single call. The text is the same; only the number of calls changes. A
  /// log that prints nothing makes no call at all.
  final bool oneCallPerLog;

  /// The sink every rendered line goes to; defaults to `print`.
  ///
  /// Replacing it takes effect on the next line, including for levels that
  /// have already been printed: the cached [ansi.StackedPrinter] of each
  /// level writes through this field rather than through the function that
  /// was installed when it was built.
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
    this.oneCallPerLog = false,
  })  : theme = theme ?? LogMainTheme.defaultActiveTheme,
        activeLevels = _buildLevels(activeLevels, activeMinLevel),
        activeNamespaces = activeNamespaces ?? {},
        activeTraceGroups = activeTraceGroups ?? {},
        activeTags = activeTags ?? {} {
    if (inactiveTheme == null &&
        (activeMinLevel != null ||
            activeLevels != null ||
            activeNamespaces != null ||
            activeTraceGroups != null ||
            activeTags != null ||
            isLogActive != null)) {
      throw ArgumentError.value(
        inactiveTheme,
        'inactiveTheme',
        'Must be set when active filters are configured',
      );
    }
  }

  bool _isLogActive(Log log) =>
      inactiveTheme == null ||
      (isLogActive?.call(log) ?? false) ||
      activeLevels.contains(log.level) ||
      // A namespace activates itself and its children: 'app' matches
      // 'app' and 'app/...', but not 'application'.
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
    // The threshold is the lower of the two themes: an active log must not
    // be suppressed harder than a background one of the same level.
    final minLevel = switch (inactiveTheme) {
      null => theme.minLevel,
      final inactive => math.min(this.theme.minLevel, inactive.minLevel),
    };
    if (log.level < minLevel) {
      return;
    }

    if (!oneCallPerLog) {
      for (final row in rows) {
        if (row.when?.call(log) ?? true) {
          printRow(log, row, isActive, theme);
        }
      }

      return;
    }

    // The buffer lives only for this log's render: _write puts lines into
    // it rather than into output. The finally is required — a throwing
    // render must not leave the printer buffering forever.
    final buffer = _buffer = <String>[];
    try {
      for (final row in rows) {
        if (row.when?.call(log) ?? true) {
          printRow(log, row, isActive, theme);
        }
      }
    } finally {
      _buffer = null;
    }

    if (buffer.isNotEmpty) output(buffer.join('\n'));
  }

  /// Where lines go while one log is being assembled (see [oneCallPerLog]).
  List<String>? _buffer;

  void _write(String line) {
    final buffer = _buffer;
    if (buffer != null) {
      buffer.add(line);

      return;
    }

    output(line);
  }

  void printRow(Log log, LogRow row, bool isActive, LogMainTheme main) {
    final theme = main[log.level];
    final printer = _printers[(isActive, log.level)] ??= ansi.StackedPrinter(
      defaultStyle: theme.data.normal,
      ansiCodesEnabled: main.ansiCodesEnabled,
      // Not a tear-off: the printer of a level outlives any number of
      // `output` replacements, and a tear-off would pin it to the sink
      // installed when the level was first printed.
      output: _write,
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
      // The tail is bounded by maxLength: otherwise a wide tail would give
      // every child a negative limit and the log line would vanish
      // silently.
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
    // The row height accounts for the tail as well: the row is printed
    // even when every child is empty.
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
