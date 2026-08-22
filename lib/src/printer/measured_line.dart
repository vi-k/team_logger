import 'package:ansi_escape_codes/ansi_escape_codes.dart' as ansi;
import 'package:ansi_escape_codes/extensions.dart';

import 'display_width.dart';

/// One line of output, measured in terminal columns.
///
/// [ansi.Parser] answers in UTF-16 code units of the plain text — the string
/// with the escape codes taken out — and slices by those same positions. This
/// pairs it with a [ClusterIndex] over exactly that plain text, so layout can
/// ask in columns and the parser still be told code units.
///
/// The two agree by construction: `ansiRemoveEscapeCodes()` is documented as
/// reading by the same pattern the parser does, and a test pins that their
/// lengths match. Not exported.
final class MeasuredLine {
  final ansi.Parser parser;
  final ClusterIndex index;

  MeasuredLine(String input)
      : parser = ansi.Parser(input),
        index = ClusterIndex(input.ansiRemoveEscapeCodes());

  /// The line as it was given, escape codes included.
  String get input => parser.input;

  /// Width of the whole line in columns.
  int get width => index.width;

  /// Length of the plain text in code units — the positions [slice] takes.
  int get codeUnits => index.codeUnits;

  /// Columns from the plain-text code-unit offset [start] to the end.
  int columnsFrom(int start) => index.columnsFrom(start);

  /// At most [columns] columns starting at code-unit offset [start], cut on
  /// cluster boundaries.
  ///
  /// The result can be narrower than asked for: a cluster that does not fit
  /// is left for the next slice rather than halved, so the caller has to pad
  /// by what the returned `columns` says rather than assume the budget was
  /// used up. With [atLeastOne] a cluster too wide for the whole budget is
  /// taken anyway, which is what keeps a wrapping loop moving.
  ({String text, int columns}) slice(
    int start,
    int columns, {
    bool atLeastOne = false,
  }) {
    final take = atLeastOne
        ? index.codeUnitsForColumnsAtLeastOne(start, columns)
        : index.codeUnitsForColumns(start, columns);

    if (take <= 0) return (text: '', columns: 0);

    return (
      text: parser.substring(start, maxLength: take),
      columns: index.columnsBetween(start, start + take),
    );
  }

  /// The rest of the line from code-unit offset [start].
  ({String text, int columns}) rest(int start) => (
        text: parser.substring(start),
        columns: index.columnsFrom(start),
      );
}
