import 'package:team_logger/team_logger.dart';
import 'package:test/test.dart';

bool _wellFormedUtf16(String s) {
  final units = s.codeUnits;
  for (var i = 0; i < units.length; i++) {
    final u = units[i];
    if (u >= 0xD800 && u <= 0xDBFF) {
      if (i + 1 >= units.length ||
          units[i + 1] < 0xDC00 ||
          units[i + 1] > 0xDFFF) {
        return false;
      }
      i++;
    } else if (u >= 0xDC00 && u <= 0xDFFF) {
      return false;
    }
  }

  return true;
}

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

bool _never(Log log) => false;

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

    test('a replaced output takes over the levels already printed', () {
      final first = <String>[];
      final second = <String>[];
      final printer = ConsoleLogPrinter(
        theme: LogMainTheme.noColors,
        rows: const [
          LogRow(maxLength: 40, children: [LogMessage()]),
        ],
        output: first.add,
      );
      final log = Logger('app')
        ..level = LogLevels.all
        ..publisher = printer;

      log.i('before');
      printer.output = second.add;
      log.i('after');

      // The printer for this level was built on the first log and must not
      // keep writing into the sink that was replaced.
      expect(first.single.trim(), 'before');
      expect(second.single.trim(), 'after');
    });

    test('a replaced output reaches a level printed for the first time', () {
      final first = <String>[];
      final second = <String>[];
      final printer = ConsoleLogPrinter(
        theme: LogMainTheme.noColors,
        rows: const [
          LogRow(maxLength: 40, children: [LogMessage()]),
        ],
        output: first.add,
      );
      final log = Logger('app')
        ..level = LogLevels.all
        ..publisher = printer;

      log.i('before');
      printer.output = second.add;
      log.w('other level');

      expect(first.single.trim(), 'before');
      expect(second.single.trim(), 'other level');
    });

    test('by default output is called once per rendered line', () {
      final lines = <String>[];
      final log = Logger('app')
        ..level = LogLevels.all
        ..publisher = ConsoleLogPrinter(
          theme: LogMainTheme.noColors,
          rows: const [
            LogRow(maxLength: 30, children: [LogMessage()]),
          ],
          output: lines.add,
        );

      log.i('a very long message that will definitely wrap across lines');

      expect(lines.length, greaterThan(1));
    });

    test('oneCallPerLog delivers the whole log in a single call', () {
      final calls = <String>[];
      final log = Logger('app')
        ..level = LogLevels.all
        ..publisher = ConsoleLogPrinter(
          theme: LogMainTheme.noColors,
          rows: const [
            LogRow(maxLength: 30, children: [LogMessage()]),
          ],
          output: calls.add,
          oneCallPerLog: true,
        );

      log.i('a very long message that will definitely wrap across lines');

      expect(calls, hasLength(1));
      // The lines are the same lines, joined rather than sent one by one.
      expect(calls.single.split('\n').length, greaterThan(1));
      expect(calls.single, isNot(endsWith('\n')));
    });

    test('oneCallPerLog joins every row of the log, not just one', () {
      final calls = <String>[];
      final log = Logger('app')
        ..level = LogLevels.all
        ..publisher = ConsoleLogPrinter(
          theme: LogMainTheme.noColors,
          rows: const [
            LogRow(maxLength: 40, children: [LogMessage()]),
            LogRow(maxLength: 40, children: [LogTags()]),
          ],
          output: calls.add,
          oneCallPerLog: true,
        );

      log.i('body', tags: 'mark');

      expect(calls, hasLength(1));
      expect(calls.single, contains('body'));
      expect(calls.single, contains('#mark'));
      expect(calls.single, contains('\n'));
    });

    test('oneCallPerLog stays quiet when the log prints nothing', () {
      final calls = <String>[];
      final log = Logger('app')
        ..level = LogLevels.all
        ..publisher = ConsoleLogPrinter(
          theme: LogMainTheme.noColors,
          rows: const [
            LogRow(maxLength: 40, children: [LogTags()], when: _never),
          ],
          output: calls.add,
          oneCallPerLog: true,
        );

      log.i('nothing to show');

      expect(calls, isEmpty);
    });

    test('the same log renders the same text either way', () {
      String render({required bool oneCall}) {
        final calls = <String>[];
        Logger('app')
          ..level = LogLevels.all
          ..publisher = ConsoleLogPrinter(
            theme: LogMainTheme.noColors,
            rows: const [
              LogRow(maxLength: 30, children: [LogMessage()]),
            ],
            output: calls.add,
            oneCallPerLog: oneCall,
          )
          ..i('a very long message that will definitely wrap across lines');

        return calls.join('\n');
      }

      expect(render(oneCall: true), render(oneCall: false));
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

    test('truncation never leaves a dangling surrogate half', () {
      final (log, out) = _setup(
        rows: const [
          LogRow(maxLength: 8, children: [LogMessage()]),
        ],
      );

      log.i('😀😀😀😀😀');

      expect(out, isNotEmpty);
      for (final line in out) {
        expect(_wellFormedUtf16(line), isTrue, reason: 'broken: $line');
      }
    });

    test('wrapping never leaves a dangling surrogate half', () {
      final (log, out) = _setup(
        rows: const [
          LogRow(maxLength: 6, children: [LogMessage()]),
        ],
      );

      log.i('😀😀😀😀😀');

      expect(out.length, greaterThan(1));
      for (final line in out) {
        expect(_wellFormedUtf16(line), isTrue, reason: 'broken: $line');
      }
    });

    test('vertical filler has no ellipsis on continuation lines', () {
      final (log, out) = _setup(
        rows: const [
          LogRow(
            maxLength: 24,
            children: [
              LogTime.onlyTime(constraints: LogConstraints.exact(8)),
              LogMessage(),
            ],
          ),
        ],
      );

      log.i('a long message that wraps over lines');

      expect(out.length, greaterThan(1));
      // Первая строка может содержать многоточие усечения времени,
      // невидимые филлеры продолжений — не должны.
      for (final line in out.skip(1)) {
        expect(line, isNot(contains('…')), reason: 'line: $line');
      }
    });

    test('long stack trace frame wraps instead of dropping the file', () {
      final (log, out) = _setup(
        rows: const [
          LogRow(maxLength: 40, children: [LogStackTrace()]),
        ],
      );

      log.e(
        'boom',
        stackTrace: StackTrace.fromString(
          '#0 VeryLongClassName.someExtremelyLongMethodNameThatDoesNotFit '
          '(package:demo/src/deep/path/file_name.dart:12:34)',
        ),
      );

      // Фрейм переносится с маркером переноса '-'; после склейки строк и
      // удаления маркеров/пробелов имя файла должно сохраниться целиком.
      final glued = out.join().replaceAll('-', '').replaceAll(' ', '');
      expect(glued, contains('file_name.dart'));
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
