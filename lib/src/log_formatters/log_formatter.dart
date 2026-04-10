import 'dart:math' as math;

import 'package:ansi_escape_codes/parsing.dart' as ansi;

import '../logger/log.dart';
import '../theme/log_theme.dart';
import 'constraints.dart';
import 'extensions.dart';
import 'text_align.dart';

abstract interface class LogFormatter {
  int get priority;

  LogFormatterBox call(Log log, LogLevelTheme theme, int? remainingLength);
}

enum VerticalAlign { top, bottom, center, stretch }

final class LogFormatterBox {
  final int width;
  final List<String> lines;
  final VerticalAlign verticalAlign;

  factory LogFormatterBox(
    Log log,
    LogLevelTheme theme,
    List<String> lines, {
    Constraints constraints = const Constraints.unlimited(),
    TextAlign textAlign = TextAlign.left,
    VerticalAlign verticalAlign = VerticalAlign.top,
    bool showEllipsis = true,
  }) {
    assert(lines.isNotEmpty, 'lines must not be empty');

    final parsers = lines.map(ansi.Parser.new).toList(growable: false);
    var width = parsers.fold(0, (w, parser) => math.max(w, parser.length));
    width = constraints.apply(width);

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

    return LogFormatterBox.raw(width, boxLines, verticalAlign);
  }

  LogFormatterBox.empty()
      : width = 0,
        lines = [],
        verticalAlign = VerticalAlign.top;

  LogFormatterBox.raw(
    this.width,
    this.lines, [
    this.verticalAlign = VerticalAlign.top,
  ]);

  factory LogFormatterBox.fromText(
    Log log,
    LogLevelTheme theme,
    String text, {
    required int? maxLines,
    Constraints constraints = const Constraints.unlimited(),
    TextAlign textAlign = TextAlign.left,
    VerticalAlign verticalAlign = VerticalAlign.top,
  }) {
    final lines = text.split('\n');
    final parsers = lines.map(ansi.Parser.new).toList(growable: false);
    var boxWidth = parsers.fold(0, (w, parser) => math.max(w, parser.length));
    boxWidth = constraints.apply(boxWidth);

    if (boxWidth == 0) {
      return LogFormatterBox.empty();
    }

    final textWidth = boxWidth - theme.common.lineBreak.length;
    if (textWidth <= 0) {
      return LogFormatterBox.raw(boxWidth, [' ' * boxWidth]);
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

    return LogFormatterBox(
      log,
      theme,
      boxLines,
      constraints: constraints,
      textAlign: textAlign,
      verticalAlign: verticalAlign,
    );
  }

  void applyHeight(int linesCount) {
    if (lines.length == linesCount) {
      return;
    }

    switch (verticalAlign) {
      case VerticalAlign.top:
        if (lines.length > linesCount) {
          lines.removeRange(linesCount, lines.length);
        } else {
          lines.addAll(List.filled(linesCount - lines.length, ' ' * width));
        }

      case VerticalAlign.bottom:
        if (lines.length > linesCount) {
          lines.removeRange(0, lines.length - linesCount);
        } else {
          lines.insertAll(
            0,
            List.filled(linesCount - lines.length, ' ' * width),
          );
        }

      case VerticalAlign.center:
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
          final emptyString = ' ' * width;
          lines
            ..insertAll(0, List.filled(addTop, emptyString))
            ..addAll(List.filled(addBottom, emptyString));
        }

      case VerticalAlign.stretch:
        if (lines.length > linesCount) {
          lines.removeRange(linesCount, lines.length);
        } else {
          lines.addAll(List.filled(linesCount - lines.length, lines.last));
        }
    }
  }
}
