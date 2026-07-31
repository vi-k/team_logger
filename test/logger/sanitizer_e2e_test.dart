import 'dart:convert';
import 'dart:io';

import 'package:team_logger/team_logger_io.dart';
import 'package:test/test.dart';

/// Runs a log through a real [ConsoleLogPrinter] on a single line and
/// returns what it printed.
String _printData(Object? data) {
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

/// Same, for a `LoggableMultiData` — the printer renders those itself.
String _printMultiData(LoggableMultiData data) => _printData(data);

/// Data that legitimately renders to an empty string.
LoggableData _emptyRendering() => Loggable.builder(
      const Object(),
      showName: false,
      showBrackets: false,
    );

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

        // The first observation is the ROOT (empty path): the printer
        // must offer the whole data object before walking its sections.
        expect(paths, ['', 'user', 'user.name', 'user.password']);
        expect(out, isNot(contains('hunter2')));
        expect(out, contains('***'));
      },
    );

    test(
      'a multi-data root dropped by the rule leaves no data block on the '
      'console',
      () {
        // Both the printer and LoggableMultiData.toString entered the
        // section walk directly, so the ROOT value was never offered: a
        // rule honoured in the JSONL file was ignored on the console —
        // the default publisher — and the secret was printed.
        Loggable.sanitizer =
            (ctx) => ctx.depth == 0 ? Sanitize.drop : ctx.value;

        expect(_printMultiData(LoggableMultiData({'s': 'topsecret'})), 'login');
      },
    );

    test('a multi-data root replaced by the rule is printed instead', () {
      Loggable.sanitizer = (ctx) => ctx.depth == 0 ? '***' : ctx.value;

      expect(
        _printMultiData(LoggableMultiData({'s': 'topsecret'})),
        'login: "***"',
      );
    });

    test('a root replacement inherits the container config', () {
      // The replacement stands in for the container, so it is rendered
      // with the container's formatting — and all FOUR renderers of a
      // multi-data must agree on that. The walkers used to offer the
      // root with the ambient config only, so `objectToString` and
      // `objectToJson` — the JSONL path — dropped the units that the
      // console printed.
      Loggable.sanitizer = (ctx) => ctx.depth == 0 ? 12 : ctx.value;

      final data = LoggableMultiData(
        {'s': 'topsecret'},
        config: const LoggableConfig(units: 'kg'),
      );

      expect(data.toString(), '12kg', reason: 'LoggableMultiData.toString');
      expect(_printMultiData(data), 'login: 12kg', reason: 'ConsoleLogPrinter');
      expect(
        Loggable.objectToString(data),
        '12kg',
        reason: 'Loggable.objectToString',
      );
      expect(
        Loggable.objectToJson(data),
        {':v': 12, ':u': 'kg'},
        reason: 'Loggable.objectToJson',
      );
    });

    test('every renderer offers the multi-data root exactly once', () {
      var roots = 0;
      Loggable.sanitizer = (ctx) {
        if (ctx.depth == 0) roots++;

        return ctx.value;
      };

      final data = LoggableMultiData({'s': 'topsecret'});

      Loggable.objectToString(data);
      expect(roots, 1, reason: 'objectToString');

      roots = 0;
      Loggable.objectToJson(data);
      expect(roots, 1, reason: 'objectToJson');

      roots = 0;
      data.toString();
      expect(roots, 1, reason: 'LoggableMultiData.toString');

      roots = 0;
      _printMultiData(data);
      expect(roots, 1, reason: 'ConsoleLogPrinter');
    });

    test('console, JSON and text renderers observe the same positions', () {
      // The invariant behind both leaks: whichever renderer runs, every
      // rendered value is offered once, at the same path and the same
      // depth. A renderer that grew its own walk again shows up here as
      // a missing root, a truncated path or a repeated position.
      final seen = <String>[];
      Loggable.sanitizer = (ctx) {
        seen.add('${ctx.path}@${ctx.depth}');

        return ctx.value;
      };

      final data = LoggableMultiData({
        'req': {'pan': '4111'},
        'res': Loggable.mapBuilder()
          ..prop('card', 'unused', view: Loggable.from({'cvv': '123'})),
      });

      Loggable.objectToString(data);
      final text = [...seen];
      seen.clear();

      Loggable.objectToJson(data);
      final json = [...seen];
      seen.clear();

      _printMultiData(data);
      final console = [...seen];

      expect(text, [
        '@0',
        'req@1',
        'req.pan@2',
        'res@1',
        'res.card@2',
        'res.card.cvv@3',
      ]);
      expect(json, text);
      expect(console, text);
    });

    test('a plain data root dropped by the rule leaves no data block', () {
      Loggable.sanitizer = (ctx) => ctx.depth == 0 ? Sanitize.drop : ctx.value;

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
        ..i('login', data: {'password': 'hunter2'});

      expect(lines.join('\n').trimRight(), 'login');
    });

    test('an empty multi-data still prints its colon without a sanitizer', () {
      // Zero behaviour change while `Loggable.sanitizer` is null: an
      // empty rendering is only read as "dropped" when a rule is armed.
      expect(_printMultiData(LoggableMultiData({})), 'login:');
    });

    test('an empty multi-data prints its colon with a rule armed too', () {
      // The data block must not depend on the mere presence of a rule:
      // an empty rendering is a legitimate rendering, and only
      // `Sanitize.drop` removes the block. The printer used to read
      // "empty output + a sanitizer installed" as a drop.
      Loggable.sanitizer = (ctx) => ctx.value;

      expect(_printMultiData(LoggableMultiData({})), 'login:');
    });

    test('data rendering empty prints its colon without a sanitizer', () {
      expect(_printData(_emptyRendering()), 'login:');
    });

    test('data rendering empty prints its colon with a rule armed too', () {
      Loggable.sanitizer = (ctx) => ctx.value;

      expect(_printData(_emptyRendering()), 'login:');
    });

    test('a wrapped data root is offered unwrapped, exactly once', () {
      // The printer offers the root itself now (it needs to know whether
      // the rule dropped it); a `LoggableWrapper` must stay transparent
      // there just like it is in the walkers.
      final seen = <Object?>[];
      Loggable.sanitizer = (ctx) {
        seen.add(ctx.value);

        return ctx.value;
      };

      expect(
        _printData(
          Loggable.from(1, config: const LoggableConfig(units: 'kg')),
        ),
        'login: 1kg',
      );
      expect(seen, [1]);
    });

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
