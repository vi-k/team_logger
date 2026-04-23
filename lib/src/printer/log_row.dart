import '../logger/logger.dart';
import 'log_block.dart';
import 'log_divider.dart';

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
