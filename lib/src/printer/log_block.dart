import 'dart:math' as math;

import '../loggable/loggable.dart';
import '../logger/logger.dart';
import '../theme/log_main_theme.dart';
import 'constraints.dart';
import 'display_width.dart';
import 'extensions.dart';
import 'log_row.dart';
import 'log_text_align.dart';
import 'log_vertical_align.dart';
import 'measured_line.dart';

abstract interface class LogBlock {
  LogBox call(Log log, LogTheme theme, LogRow row, int? remainingLength);
}

final class LogBox with Loggable {
  final String? debugName;
  final int width;
  final List<String> lines;
  final LogVerticalAlign verticalAlign;
  final String? verticalFiller;

  factory LogBox(
    Log log,
    LogTheme theme,
    List<String> lines, {
    LogConstraints constraints = const LogConstraints.unlimited(),
    LogTextAlign textAlign = LogTextAlign.left,
    LogVerticalAlign verticalAlign = LogVerticalAlign.top,
    String? verticalFiller,
    bool showEllipsis = true,
    String? debugName,
  }) {
    assert(lines.isNotEmpty, 'lines must not be empty');

    final measured = lines.map(MeasuredLine.new).toList(growable: false);
    var width = measured.fold(0, (w, line) => math.max(w, line.width));
    width = constraints.apply(width);

    if (width <= 0) {
      return LogBox.empty();
    }

    final boxLines = measured
        .map(
          (line) => line.applyConstraints(
            log,
            theme,
            LogConstraints.exact(width),
            textAlign: textAlign,
            showEllipsis: showEllipsis,
          ),
        )
        .toList();

    String? boxVerticalFiller;
    if (verticalFiller != null) {
      boxVerticalFiller = MeasuredLine(verticalFiller).applyConstraints(
        log,
        theme,
        LogConstraints.exact(width),
        textAlign: textAlign,
        // Truncation ellipsis is not shown on fillers: it would stay
        // visible on the hidden continuation lines.
        showEllipsis: false,
      );
    }

    return LogBox.raw(
      width,
      boxLines,
      verticalFiller: boxVerticalFiller,
      verticalAlign: verticalAlign,
      debugName: debugName,
    );
  }

  LogBox.empty({this.debugName})
      : width = 0,
        lines = [],
        verticalFiller = null,
        verticalAlign = LogVerticalAlign.top;

  LogBox.raw(
    this.width,
    this.lines, {
    this.verticalFiller,
    this.verticalAlign = LogVerticalAlign.top,
    this.debugName,
  });

  factory LogBox.fromText(
    Log log,
    LogTheme theme,
    String text, {
    required int? maxLines,
    String? verticalFiller,
    LogConstraints constraints = const LogConstraints.unlimited(),
    LogTextAlign textAlign = LogTextAlign.left,
    LogVerticalAlign verticalAlign = LogVerticalAlign.top,
    String? debugName,
  }) {
    final lines = text.split('\n');
    final measured = lines.map(MeasuredLine.new).toList(growable: false);
    var boxWidth = measured.fold(0, (w, line) => math.max(w, line.width));
    boxWidth = constraints.apply(boxWidth);

    if (boxWidth == 0) {
      return LogBox.empty(debugName: debugName);
    }

    // Room for the wrap character is only needed by lines that actually
    // wrap — otherwise a one-character message would degenerate into a
    // space.
    final needsWrap = measured.any((line) => line.width > boxWidth);
    final textWidth = boxWidth - displayWidth(theme.main.lineBreak);
    if (needsWrap && textWidth <= 0) {
      return LogBox.raw(
        boxWidth,
        [' ' * boxWidth],
        debugName: debugName,
      );
    }

    final lineBreakColumns = displayWidth(theme.main.lineBreak);
    final boxLines = <String>[];
    for (final line in measured) {
      if (line.width <= boxWidth) {
        boxLines.add(
          line.applyConstraints(
            log,
            theme,
            LogConstraints.exact(boxWidth),
            textAlign: textAlign,
          ),
        );
        continue;
      }

      // The position counts code units — what the parser slices by — while
      // the line budget counts columns. MeasuredLine converts between them,
      // and a cut always lands on a cluster boundary.
      var start = 0;
      final end = line.codeUnits;
      while (start < end) {
        if (line.columnsFrom(start) <= textWidth) {
          final rest = line.rest(start);
          boxLines.add(
            '${rest.text.applyConstraints(
              log,
              theme,
              LogConstraints.exact(textWidth),
              textAlign: textAlign,
            )}${' ' * lineBreakColumns}',
          );
          start = end;
        } else if (maxLines == null || maxLines > boxLines.length + 1) {
          // atLeastOne: a character wider than the whole budget would
          // otherwise stall this loop forever. It goes out whole and
          // overflows by a column — half a wide glyph is not a glyph.
          final head = line.slice(start, textWidth, atLeastOne: true);
          boxLines.add(
            '${head.text}'
            '${theme.styledPadding(textWidth - head.columns)}'
            '${theme.styledLineBreak}',
          );
          start += line.index.codeUnitsForColumnsAtLeastOne(start, textWidth);
        } else {
          // The last (truncated) line carries no wrap character and takes
          // the full width of the box — otherwise it would be one column
          // narrower.
          final tail = line.terminatedSlice(
            theme.main.ellipsis,
            theme.data.ellipsisStyle,
            start,
            maxColumns: boxWidth,
          );
          boxLines.add(
            '${tail.text}${theme.styledPadding(boxWidth - tail.columns)}',
          );
          break;
        }
      }
    }

    String? boxVerticalFiller;
    if (verticalFiller != null) {
      boxVerticalFiller = MeasuredLine(verticalFiller).applyConstraints(
        log,
        theme,
        LogConstraints.exact(boxWidth),
        textAlign: textAlign,
        // See the comment in the LogBox factory: no ellipsis on fillers.
        showEllipsis: false,
      );
    }

    return LogBox(
      log,
      theme,
      boxLines,
      constraints: constraints,
      textAlign: textAlign,
      verticalFiller: boxVerticalFiller,
      verticalAlign: verticalAlign,
      debugName: debugName,
    );
  }

  void applyHeight(int linesCount) {
    if (lines.length == linesCount) {
      return;
    }

    switch (verticalAlign) {
      case LogVerticalAlign.top:
        if (lines.length > linesCount) {
          lines.removeRange(linesCount, lines.length);
        } else {
          lines.addAll(
            List.filled(
              linesCount - lines.length,
              verticalFiller ?? ' ' * width,
            ),
          );
        }

      case LogVerticalAlign.bottom:
        if (lines.length > linesCount) {
          lines.removeRange(0, lines.length - linesCount);
        } else {
          lines.insertAll(
            0,
            List.filled(
              linesCount - lines.length,
              verticalFiller ?? ' ' * width,
            ),
          );
        }

      case LogVerticalAlign.center:
        if (lines.length > linesCount) {
          final removeCount = lines.length - linesCount;
          final removeTop = removeCount ~/ 2;
          final removeBottom = removeCount - removeTop;
          lines
            ..removeRange(0, removeTop)
            ..removeRange(lines.length - removeBottom, lines.length);
        } else {
          final addCount = linesCount - lines.length;
          final addTop = addCount ~/ 2;
          final addBottom = addCount - addTop;
          final filler = verticalFiller ?? ' ' * width;
          lines
            ..insertAll(0, List.filled(addTop, filler))
            ..addAll(List.filled(addBottom, filler));
        }
    }
  }

  @override
  void collectLoggableData(LoggableData data) {
    data
      ..prop('debugName', debugName, showName: false, hidden: debugName == null)
      ..prop('width', width)
      ..prop('lines', lines, view: lines.length)
      ..prop('verticalAlign', verticalAlign);
  }
}
