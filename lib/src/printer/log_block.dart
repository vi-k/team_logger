import 'dart:math' as math;

import 'package:ansi_escape_codes/parsing.dart' as ansi;

import '../loggable/loggable.dart';
import '../logger/logger.dart';
import '../theme/log_theme.dart';
import 'constraints.dart';
import 'extensions.dart';
import 'log_row.dart';
import 'log_text_align.dart';
import 'log_vertical_align.dart';

abstract interface class LogBlock {
  LogBox call(
    Log log,
    LogLevelTheme theme,
    LogRow row,
    int? remainingLength,
  );
}

final class LogBox with Loggable {
  final String? debugName;
  final int width;
  final List<String> lines;
  final LogVerticalAlign verticalAlign;
  final String? verticalFiller;

  factory LogBox(
    Log log,
    LogLevelTheme theme,
    List<String> lines, {
    Constraints constraints = const Constraints.unlimited(),
    LogTextAlign textAlign = LogTextAlign.left,
    LogVerticalAlign verticalAlign = LogVerticalAlign.top,
    String? verticalFiller,
    bool showEllipsis = true,
    String? debugName,
  }) {
    assert(lines.isNotEmpty, 'lines must not be empty');

    final parsers = lines.map(ansi.Parser.new).toList(growable: false);
    var width = parsers.fold(0, (w, parser) => math.max(w, parser.length));
    width = constraints.apply(width);

    if (width <= 0) {
      return LogBox.empty();
    }

    final boxLines = parsers
        .map(
          (parser) => parser.applyConstraints(
            log,
            theme,
            Constraints.exact(width),
            textAlign: textAlign,
            showEllipsis: showEllipsis,
          ),
        )
        .toList();

    String? boxVerticalFiller;
    if (verticalFiller != null) {
      final parser = ansi.Parser(verticalFiller);
      boxVerticalFiller = parser.applyConstraints(
        log,
        theme,
        Constraints.exact(width),
        textAlign: textAlign,
        showEllipsis: showEllipsis,
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
    LogLevelTheme theme,
    String text, {
    required int? maxLines,
    String? verticalFiller,
    Constraints constraints = const Constraints.unlimited(),
    LogTextAlign textAlign = LogTextAlign.left,
    LogVerticalAlign verticalAlign = LogVerticalAlign.top,
    String? debugName,
  }) {
    final lines = text.split('\n');
    final parsers = lines.map(ansi.Parser.new).toList(growable: false);
    var boxWidth = parsers.fold(0, (w, parser) => math.max(w, parser.length));
    boxWidth = constraints.apply(boxWidth);

    if (boxWidth == 0) {
      return LogBox.empty(debugName: debugName);
    }

    final textWidth = boxWidth - theme.common.lineBreak.length;
    if (textWidth <= 0) {
      return LogBox.raw(
        boxWidth,
        [' ' * boxWidth],
        debugName: debugName,
      );
    }

    final boxLines = <String>[];
    for (final parser in parsers) {
      if (parser.length <= boxWidth) {
        boxLines.add(
          parser.applyConstraints(
            log,
            theme,
            Constraints.exact(boxWidth),
            textAlign: textAlign,
          ),
        );
        continue;
      }

      var start = 0;
      final end = parser.length;
      while (start < end) {
        final remaining = end - start;
        if (remaining <= textWidth) {
          boxLines.add(
            '${parser.substring(start).applyConstraints(
                  log,
                  theme,
                  Constraints.exact(textWidth),
                  textAlign: textAlign,
                )}${' ' * theme.common.lineBreak.length}',
          );
          start = end;
        } else if (maxLines == null || maxLines > boxLines.length + 1) {
          boxLines.add(
            '${parser.substring(start, maxLength: textWidth)}'
            '${theme.styledLineBreak}',
          );
          start += textWidth;
        } else {
          boxLines.add(
            parser.terminatedSubstring(
              theme.ellipsisAnsiPair,
              start,
              maxLength: textWidth,
            ),
          );
          start += textWidth;
          break;
        }
      }
    }

    String? boxVerticalFiller;
    if (verticalFiller != null) {
      final parser = ansi.Parser(verticalFiller);
      boxVerticalFiller = parser.applyConstraints(
        log,
        theme,
        Constraints.exact(boxWidth),
        textAlign: textAlign,
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
      ..prop('lines', lines, view: lines.length.toString())
      ..prop('verticalAlign', verticalAlign);
  }
}
