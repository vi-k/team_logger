import 'package:ansi_escape_codes/ansi_escape_codes.dart' as ansi;
import 'package:team_logger/team_logger.dart';

extension AnsiStringExtensions on String {
  String applyConstraints(
    Log log,
    LogTheme theme,
    Constraints constraints, {
    TextAlign textAlign = TextAlign.left,
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
    TextAlign textAlign = TextAlign.left,
    bool showEllipsis = true,
  }) {
    var newLength = length;

    newLength = constraints.apply(newLength);
    if (newLength == length) {
      return input;
    }

    if (newLength > length) {
      switch (textAlign) {
        case TextAlign.left:
          return padRight(newLength, theme.padding(log));

        case TextAlign.right:
          return padLeft(newLength, theme.padding(log));

        case TextAlign.center:
          final needToAdd = newLength - length;
          final left = needToAdd ~/ 2;
          final right = needToAdd - left;
          final padding = theme.padding(log);
          return '${padding * left}$input${padding * right}';
      }
    }

    if (newLength == 0) {
      return '';
    }

    return showEllipsis
        ? terminatedSubstring(
            theme.ellipsis.toAnsiStyled(log.level),
            0,
            maxLength: newLength,
          )
        : substring(0, maxLength: newLength);
  }

  String terminatedSubstring(
    AnsiStyled terminator,
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

final class AnsiStyled {
  final String _string;
  final ansi.Style style;

  const AnsiStyled(this._string, this.style);

  bool get isEmpty => _string.isEmpty;

  bool get isNotEmpty => _string.isNotEmpty;

  int get length => _string.length;

  @override
  String toString() => style(_string);
}
