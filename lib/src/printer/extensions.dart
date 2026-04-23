import 'package:ansi_escape_codes/ansi_escape_codes.dart' as ansi;

import '../loggable/loggable.dart';
import '../logger/logger.dart';
import '../theme/log_theme.dart';
import 'constraints.dart';
import 'log_text_align.dart';

extension AnsiStringExtensions on String {
  String applyConstraints(
    Log log,
    LogLevelTheme theme,
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
    LogLevelTheme theme,
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
          return padRight(newLength, theme.styledPadding);

        case LogTextAlign.right:
          return padLeft(newLength, theme.styledPadding);

        case LogTextAlign.center:
          final needToAdd = newLength - length;
          final left = needToAdd ~/ 2;
          final right = needToAdd - left;
          final padding = theme.styledPadding;
          return '${padding * left}$input${padding * right}';
      }
    }

    if (newLength == 0) {
      return '';
    }

    return showEllipsis
        ? terminatedSubstring(theme.ellipsisAnsiPair, 0, maxLength: newLength)
        : substring(0, maxLength: newLength);
  }

  String terminatedSubstring(
    AnsiPair terminator,
    int start, {
    required int maxLength,
  }) {
    if (terminator.isEmpty ||
        maxLength < terminator.length ||
        length - start <= maxLength) {
      return substring(start, maxLength: maxLength);
    }

    return '${substring(start, maxLength: maxLength - terminator.length)}'
        '$terminator';
  }
}

final class AnsiPair with Loggable {
  final String string;
  final ansi.Style style;

  const AnsiPair(this.string, this.style);

  bool get isEmpty => string.isEmpty;

  bool get isNotEmpty => string.isNotEmpty;

  int get length => string.length;

  @override
  String toString() => style(string);

  @override
  void collectLoggableData(LoggableData data) {
    data
      ..showName = false
      ..showBrackets = false
      ..prop('string', string, showName: false, view: '"${style(string)}"');
  }
}
