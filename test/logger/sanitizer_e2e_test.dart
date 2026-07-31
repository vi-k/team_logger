import 'dart:convert';
import 'dart:io';

import 'package:team_logger/team_logger_io.dart';
import 'package:test/test.dart';

/// Runs a `LoggableMultiData` log through a real [ConsoleLogPrinter] on a
/// single line and returns what it printed.
String _printMultiData(LoggableMultiData data) {
  final lines = <String>[];
  Logger('app')
    ..level = LogLevels.all
    ..publisher = ConsoleLogPrinter(
      theme: LogMainTheme.noColors,
      rows: const [
        LogRow.singleLine(children: [LogMessage()]),
      ],
      output: lines.add,
    )
    ..i('login', data: data);

  return lines.join('\n').trimRight();
}

void main() {
  group('sanitizer e2e', () {
    tearDown(() => Loggable.sanitizer = null);

    test('the secret never reaches the console printer', () {
      Loggable.sanitizer =
          (ctx) => ctx.name == 'password' ? Sanitize.drop : ctx.value;

      final lines = <String>[];
      Logger('app')
        ..level = LogLevels.all
        ..publisher = ConsoleLogPrinter(
          theme: LogMainTheme.noColors,
          rows: const [
            LogRow(maxLength: 200, children: [LogMessage()]),
          ],
          output: lines.add,
        )
        ..i(
          'login',
          data: {
            'user': {'name': 'ann', 'password': 'hunter2'},
          },
        );

      final out = lines.join('\n');
      expect(out, contains('ann'));
      expect(out, isNot(contains('hunter2')));
      expect(out, isNot(contains('password')));
    });

    test(
      'a multi-data section is dropped by name in the console printer',
      () {
        // The printer duplicates the multi-data layout (it needs the
        // per-section line split). Before the fix it also duplicated the
        // rendering call, handing each section value to the walker as a
        // ROOT — so a name-based rule never fired and the secret was
        // printed.
        Loggable.sanitizer =
            (ctx) => ctx.name == 'password' ? Sanitize.drop : ctx.value;

        expect(
          _printMultiData(
            LoggableMultiData({'req': 'ok', 'password': 'hunter2'}),
          ),
          'login: req: "ok"',
        );
      },
    );

    test(
      'a multi-data section is replaced by name in the console printer',
      () {
        Loggable.sanitizer =
            (ctx) => ctx.name == 'password' ? '***' : ctx.value;

        expect(
          _printMultiData(
            LoggableMultiData({'req': 'ok', 'password': 'hunter2'}),
          ),
          'login: req: "ok", password: "***"',
        );
      },
    );

    test(
      'a value nested in a multi-data section keeps the section in its path',
      () {
        // A `path`-based rule used to work in JSONL and fail on console:
        // the printer rendered the section without its path segment.
        final paths = <String>[];
        Loggable.sanitizer = (ctx) {
          paths.add(ctx.path);

          return ctx.path == 'user.password' ? '***' : ctx.value;
        };

        final out = _printMultiData(
          LoggableMultiData({
            'user': {'name': 'ann', 'password': 'hunter2'},
          }),
        );

        expect(paths, ['user', 'user.name', 'user.password']);
        expect(out, isNot(contains('hunter2')));
        expect(out, contains('***'));
      },
    );

    test('without a sanitizer multi-data printing is unchanged', () {
      expect(
        _printMultiData(
          LoggableMultiData({'req': 'ok', 'password': 'hunter2'}),
        ),
        'login: req: "ok", password: "hunter2"',
      );
    });

    test('the secret never reaches the JSONL file', () async {
      Loggable.sanitizer = (ctx) => ctx.name == 'password' ? '***' : ctx.value;

      final tmp = await Directory.systemTemp.createTemp('sanitizer_e2e');
      addTearDown(() => tmp.delete(recursive: true));

      final storage = FileLogStorage(directory: tmp.path);
      Logger('app')
        ..level = LogLevels.all
        ..publisher = storage
        ..i('login', data: {'password': 'hunter2'});

      await storage.flush();
      await storage.close();

      final content = Directory(tmp.path)
          .listSync()
          .whereType<File>()
          .map((f) => utf8.decode(f.readAsBytesSync()))
          .join('\n');
      expect(content, contains('***'));
      expect(content, isNot(contains('hunter2')));
    });

    test('an in-app viewer rendering log.data is sanitized too', () {
      Loggable.sanitizer = (ctx) => ctx.name == 'password' ? '***' : ctx.value;

      // LogStorage requires maxCount; there is no `.logs` getter — the
      // stored logs are read back via `.snapshot()`.
      final storage = LogStorage(maxCount: 10);
      Logger('app')
        ..level = LogLevels.all
        ..publisher = storage
        ..i('login', data: {'password': 'hunter2'});

      final rendered = Loggable.objectToString(storage.snapshot().single.data);
      expect(rendered, contains('***'));
      expect(rendered, isNot(contains('hunter2')));
    });

    test('without a sanitizer the output is unchanged', () {
      final lines = <String>[];
      Logger('app')
        ..level = LogLevels.all
        ..publisher = ConsoleLogPrinter(
          theme: LogMainTheme.noColors,
          rows: const [
            LogRow(maxLength: 200, children: [LogMessage()]),
          ],
          output: lines.add,
        )
        ..i('login', data: {'password': 'hunter2'});

      expect(lines.join('\n'), contains('hunter2'));
    });

    test(
      'a rule replacing a prop value with null renders null in text, '
      'not the original',
      () {
        Loggable.sanitizer = (ctx) => ctx.name == 'secret' ? null : ctx.value;

        final out = Loggable.objectToString(
          Loggable.mapBuilder()..prop('secret', 'hunter2'),
        );

        expect(out, isNot(contains('hunter2')));
        expect(out, '{secret: null}');
      },
    );

    test(
      'a rule replacing a prop value with null renders null in JSON, '
      'not the original',
      () {
        Loggable.sanitizer = (ctx) => ctx.name == 'secret' ? null : ctx.value;

        final out = Loggable.objectToJson(
          Loggable.mapBuilder()..prop('secret', 'hunter2'),
        );

        expect(out.toString(), isNot(contains('hunter2')));
        expect(out, {'secret': null});
      },
    );

    test(
      "a round() prop's raw numeric view is sanitized exactly once in "
      'JSON',
      () {
        // round() gives the prop a raw `num` view distinct from `value`;
        // that view recurses back through objectToJson to be rendered.
        // Exactly two positions should ever reach the sanitizer here: the
        // root object and the `amount` prop's view. Counting ALL calls
        // (not just ones named 'amount') also catches a regression where
        // the raw view re-enters objectToJson's root check and fires a
        // third time disguised as another root call.
        var calls = 0;
        Loggable.sanitizer = (ctx) {
          calls++;

          return ctx.value;
        };

        Loggable.objectToJson(
          Loggable.builder(const Object(), name: 'D')
            ..round('amount', 12345.6789, precision: 2),
        );

        expect(calls, 2);
      },
    );

    test(
      "a replacing rule on a round() prop's view leaves no fragment of "
      'it in JSON',
      () {
        Loggable.sanitizer = (ctx) => ctx.name == 'amount' ? '***' : ctx.value;

        final out = Loggable.objectToJson(
          Loggable.builder(const Object(), name: 'D')
            ..round('amount', 12345.6789, precision: 2),
        ).toString();

        expect(out, contains('***'));
        expect(out, isNot(contains('12345')));
      },
    );
  });
}
