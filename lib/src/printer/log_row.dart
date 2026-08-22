import '../logger/logger.dart';
import 'log_block.dart';
import 'log_divider.dart';

/// One output row of `ConsoleLogPrinter`: [children] form the body,
/// [tail] is right-aligned (typically tags). [maxLength] limits the width
/// (long content wraps or truncates), [maxLines] limits the height,
/// [when] makes the row conditional.
///
/// [maxLength] counts **terminal columns**, not characters: a CJK ideograph
/// or an emoji takes two, a combining sequence takes one however many code
/// points it is made of, and a row is never cut inside a grapheme cluster.
/// A cluster too wide for the room left is moved to the next line whole, so
/// a row can come out a column short of [maxLength].
final class LogRow {
  final int? maxLength;
  final int? maxLines;
  final List<LogBlock> children;
  final List<LogBlock> tail;
  final bool Function(Log log)? when;
  final LogDivider defaultDivider;
  final bool alignTail;

  const LogRow({
    required this.children,
    this.tail = const [],
    required int this.maxLength,
    this.maxLines,
    this.when,
    this.defaultDivider = const LogDivider(' '),
    this.alignTail = true,
  });

  const LogRow.singleLine({
    required this.children,
    this.tail = const [],
    this.when,
    this.defaultDivider = const LogDivider(' '),
    this.alignTail = true,
  })  : maxLength = null,
        maxLines = 1;

  bool get singleLine => maxLines == 1 && maxLength == null;
}
