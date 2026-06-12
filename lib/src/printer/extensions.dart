import 'package:ansi_escape_codes/ansi_escape_codes.dart' as ansi;

import '../logger/logger.dart';
import '../theme/log_main_theme.dart';
import 'constraints.dart';
import 'log_text_align.dart';

extension AnsiStringExtensions on String {
  String applyConstraints(
    Log log,
    LogTheme theme,
    Constraints constraints, {
    LogTextAlign textAlign = LogTextAlign.left,
    bool showEllipsis = true,
  }) =>
      ansi.Parser(this).applyConstraints(
        log,
        theme,
        constraints,
        textAlign: textAlign,
        showEllipsis: showEllipsis,
      );
}

extension AnsiParserExtensions on ansi.Parser {
  String applyConstraints(
    Log log,
    LogTheme theme,
    Constraints constraints, {
    LogTextAlign textAlign = LogTextAlign.left,
    bool showEllipsis = true,
  }) {
    var newLength = length;

    newLength = constraints.apply(newLength);
    if (newLength == length) {
      return input;
    }

    if (newLength > length) {
      switch (textAlign) {
        case LogTextAlign.left:
          return '$input${theme.styledPadding(newLength - length)}';

        case LogTextAlign.right:
          return '${theme.styledPadding(newLength - length)}$input';

        case LogTextAlign.center:
          final needToAdd = newLength - length;
          final left = needToAdd ~/ 2;
          final right = needToAdd - left;
          return '${theme.styledPadding(left)}'
              '$input'
              '${theme.styledPadding(right)}';
      }
    }

    if (newLength == 0) {
      return '';
    }

    return showEllipsis
        ? terminatedSubstring(
            theme.main.ellipsis,
            theme.data.ellipsisStyle,
            0,
            maxLength: newLength,
          )
        : substring(0, maxLength: newLength);
  }

  String terminatedSubstring(
    String terminator,
    ansi.Style terminatorStyle,
    int start, {
    required int maxLength,
  }) {
    if (terminator.isEmpty ||
        maxLength < terminator.length ||
        length - start <= maxLength) {
      return substring(start, maxLength: maxLength);
    }

    return '${substring(start, maxLength: maxLength - terminator.length)}'
        '${terminatorStyle(terminator)}';
  }
}
