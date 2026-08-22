import 'package:ansi_escape_codes/ansi_escape_codes.dart' as ansi;

import '../logger/logger.dart';
import '../theme/log_main_theme.dart';
import 'constraints.dart';
import 'display_width.dart';
import 'log_text_align.dart';
import 'measured_line.dart';

extension AnsiStringExtensions on String {
  String applyConstraints(
    Log log,
    LogTheme theme,
    LogConstraints constraints, {
    LogTextAlign textAlign = LogTextAlign.left,
    bool showEllipsis = true,
  }) =>
      MeasuredLine(this).applyConstraints(
        log,
        theme,
        constraints,
        textAlign: textAlign,
        showEllipsis: showEllipsis,
      );
}

extension MeasuredLineExtensions on MeasuredLine {
  /// Brings the line to the width [constraints] allow, padding or cutting it.
  ///
  /// Everything here counts in terminal columns. A cut lands on a cluster
  /// boundary, so it can come out a column short of the target — a
  /// two-column glyph does not go into one column — and the shortfall is
  /// padded like any other, which keeps the box rectangular.
  String applyConstraints(
    Log log,
    LogTheme theme,
    LogConstraints constraints, {
    LogTextAlign textAlign = LogTextAlign.left,
    bool showEllipsis = true,
  }) {
    final columns = width;
    final newColumns = constraints.apply(columns);

    if (newColumns == columns) {
      return input;
    }

    if (newColumns > columns) {
      return _align(theme, input, newColumns - columns, textAlign);
    }

    if (newColumns <= 0) {
      return '';
    }

    final cut = showEllipsis
        ? terminatedSlice(
            theme.main.ellipsis,
            theme.data.ellipsisStyle,
            0,
            maxColumns: newColumns,
          )
        : slice(0, newColumns);

    return _align(theme, cut.text, newColumns - cut.columns, textAlign);
  }

  String _align(
    LogTheme theme,
    String text,
    int missing,
    LogTextAlign textAlign,
  ) {
    if (missing <= 0) return text;

    switch (textAlign) {
      case LogTextAlign.left:
        return '$text${theme.styledPadding(missing)}';

      case LogTextAlign.right:
        return '${theme.styledPadding(missing)}$text';

      case LogTextAlign.center:
        final left = missing ~/ 2;

        return '${theme.styledPadding(left)}'
            '$text'
            '${theme.styledPadding(missing - left)}';
    }
  }

  /// At most [maxColumns] columns from [start], ending in [terminator] when
  /// there was more line than room for it.
  ({String text, int columns}) terminatedSlice(
    String terminator,
    ansi.Style terminatorStyle,
    int start, {
    required int maxColumns,
  }) {
    final terminatorColumns = displayWidth(terminator);

    if (terminator.isEmpty ||
        maxColumns < terminatorColumns ||
        columnsFrom(start) <= maxColumns) {
      return slice(start, maxColumns);
    }

    final head = slice(start, maxColumns - terminatorColumns);

    return (
      text: '${head.text}${terminatorStyle(terminator)}',
      columns: head.columns + terminatorColumns,
    );
  }
}
