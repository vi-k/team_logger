import '../logger/log.dart';
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
    bool singleLine = false,
    int? maxLength,
    int? maxLines,
    this.when,
    this.defaultDivider = const LogDivider(' '),
    this.alignTail = true,
  })  : maxLength = singleLine ? null : maxLength,
        maxLines = singleLine ? 1 : maxLines;

  bool get singleLine => maxLines == 1 && maxLength == null;
}
