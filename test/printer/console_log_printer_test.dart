import 'package:team_logger/team_logger.dart';
import 'package:test/test.dart';

(Logger, List<String>) _setup({
  LogMainTheme? theme,
  required List<LogRow> rows,
}) {
  final lines = <String>[];
  final logger = Logger('app')
    ..level = LogLevels.all
    ..publisher = ConsoleLogPrinter(
      theme: theme ?? LogMainTheme.noColors,
      rows: rows,
      output: lines.add,
    );

  return (logger, lines);
}

void main() {
  group('ConsoleLogPrinter', () {
    test('default themes do not add a #log tag to every log', () {
      final (log, out) = _setup(
        rows: const [
          LogRow(
            maxLength: 60,
            children: [LogMessage()],
            tail: [LogTags()],
          ),
        ],
      );

      log.i('hello');

      expect(out.join('\n'), isNot(contains('#log')));
    });

    test('single-character message is printed', () {
      final (log, out) = _setup(
        rows: const [
          LogRow(maxLength: 40, children: [LogMessage()]),
        ],
      );

      log.i('a');

      expect(out, hasLength(1));
      expect(out.single.trim(), 'a');
    });

    test('log line is not dropped when the tail is wider than maxLength', () {
      final (log, out) = _setup(
        rows: const [
          LogRow(
            maxLength: 10,
            children: [LogMessage()],
            tail: [LogTags()],
          ),
        ],
      );

      log.i('hi', tags: 'averyveryverylongtag');

      expect(out, isNotEmpty);
    });
  });
}
