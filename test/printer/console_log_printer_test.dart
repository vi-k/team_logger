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

    test('level themes are cached per LogMainTheme', () {
      final theme = LogMainTheme.defaultActiveTheme;

      expect(identical(theme.info, theme.info), isTrue);
      expect(identical(theme[LogLevels.info], theme.info), isTrue);
      expect(
        identical(LogMainTheme.noColors.error, LogMainTheme.noColors.error),
        isTrue,
      );
    });

    test('colorless theme variants and their copies emit no ANSI', () {
      for (final theme in [
        LogMainTheme.noColorsNoTags,
        LogMainTheme.noColors.copyWith(),
      ]) {
        final (log, out) = _setup(
          theme: theme,
          rows: const [
            LogRow(maxLength: 40, children: [LogMessage()]),
          ],
        );

        log.i('hello');

        expect(out.join(), isNot(contains('\x1B')));
      }
    });

    test('active logs are not suppressed below the inactive minLevel', () {
      final lines = <String>[];
      final log = Logger('app')
        ..level = LogLevels.all
        ..publisher = ConsoleLogPrinter(
          theme: LogMainTheme.noColors.copyWith(minLevel: LogLevels.warning),
          inactiveTheme: LogMainTheme.noColors,
          activeTags: const {'imp'},
          rows: const [
            LogRow(maxLength: 40, children: [LogMessage()]),
          ],
          output: lines.add,
        );

      log.i('important', tags: 'imp');
      log.i('background');

      expect(lines, hasLength(2));
    });

    test('activeNamespaces matches child namespaces by prefix', () {
      final lines = <String>[];
      final printer = ConsoleLogPrinter(
        theme: LogMainTheme.defaultActiveTheme,
        inactiveTheme: LogMainTheme.noColors,
        activeNamespaces: const {'app'},
        rows: const [
          LogRow(maxLength: 40, children: [LogMessage()]),
        ],
        output: lines.add,
      );

      final app = Logger('app')
        ..level = LogLevels.all
        ..publisher = printer;
      final net = app.createChild(name: 'net');
      final other = Logger('application')
        ..level = LogLevels.all
        ..publisher = printer;

      net.i('from app/net');
      expect(lines.last, contains('\x1B'), reason: 'app/net must be active');

      other.i('from application');
      expect(
        lines.last,
        isNot(contains('\x1B')),
        reason: 'application must stay inactive',
      );
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
