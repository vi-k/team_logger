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
          _printData(
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
          _printData(
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

        final out = _printData(
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

        expect(_printData(LoggableMultiData({'s': 'topsecret'})), 'login');
      },
    );

    test('a multi-data root replaced by the rule is printed instead', () {
      Loggable.sanitizer = (ctx) => ctx.depth == 0 ? '***' : ctx.value;

      expect(
        _printData(LoggableMultiData({'s': 'topsecret'})),
        'login: "***"',
      );
    });

    test('a root replacement inherits the container config, but not units', () {
      // The replacement stands in for the container, so it is rendered
      // with the container's formatting — and all FOUR renderers of a
      // multi-data must agree on that. The walkers used to offer the
      // root with the ambient config only, so `objectToString` and
      // `objectToJson` — the JSONL path — dropped the container limits
      // that the console applied.
      //
      // `units` are the exception, and the same one a property already
      // made: they assert something about the original quantity, and a
      // mask is not it. See test/loggable/sanitizer_root_test.dart.
      Loggable.sanitizer = (ctx) => ctx.depth == 0 ? [1, 2, 3] : ctx.value;

      final data = LoggableMultiData(
        {'s': 'topsecret'},
        config: const LoggableConfig(collectionMaxCount: 1, units: 'kg'),
      );

      const text = '[₌₃ ₀:1, …]';
      expect(data.toString(), text, reason: 'LoggableMultiData.toString');
      expect(_printData(data), 'login: $text', reason: 'ConsoleLogPrinter');
      expect(
        Loggable.objectToString(data),
        text,
        reason: 'Loggable.objectToString',
      );
      expect(
        Loggable.objectToJson(data),
        {
          ':k': 'list',
          ':l': 3,
          ':v': [1],
        },
        reason: 'Loggable.objectToJson',
      );
    });

    test(
      'a wrapped multi-data root replacement inherits the wrapper config, '
      'but not units',
      () {
        // Same claim as the plain multi-data case above, but the config
        // now lives on the LoggableWrapper around it, not on the
        // multi-data itself. All four renderers must still agree —
        // LoggableWrapper.toString stands in for LoggableMultiData
        // .toString here, since once wrapped the wrapper is the root, not
        // the multi-data inside it.
        Loggable.sanitizer = (ctx) => ctx.depth == 0 ? [1, 2, 3] : ctx.value;

        final wrapper = Loggable.from(
          LoggableMultiData({'s': 'topsecret'}),
          config: const LoggableConfig(collectionMaxCount: 1, units: 'kg'),
        );

        const text = '[₌₃ ₀:1, …]';
        expect(
          wrapper.toString(),
          text,
          reason: 'LoggableWrapper.toString',
        );
        expect(
          _printData(wrapper),
          'login: $text',
          reason: 'ConsoleLogPrinter',
        );
        expect(
          Loggable.objectToString(wrapper),
          text,
          reason: 'Loggable.objectToString',
        );
        expect(
          Loggable.objectToJson(wrapper),
          {
            ':k': 'list',
            ':l': 3,
            ':v': [1],
          },
          reason: 'Loggable.objectToJson',
        );
      },
    );

    test(
      'a wrapped multi-data root replacement inherits the multi-data own '
      'config, but not units, even when the wrapper carries none',
      () {
        // Mirror direction: the config lives on the LoggableMultiData
        // itself, and the LoggableWrapper around it carries none of its
        // own. Both directions must land on the same rendering.
        Loggable.sanitizer = (ctx) => ctx.depth == 0 ? [1, 2, 3] : ctx.value;

        final wrapper = Loggable.from(
          LoggableMultiData(
            {'s': 'topsecret'},
            config: const LoggableConfig(collectionMaxCount: 1, units: 'kg'),
          ),
        );

        const text = '[₌₃ ₀:1, …]';
        expect(
          wrapper.toString(),
          text,
          reason: 'LoggableWrapper.toString',
        );
        expect(
          _printData(wrapper),
          'login: $text',
          reason: 'ConsoleLogPrinter',
        );
        expect(
          Loggable.objectToString(wrapper),
          text,
          reason: 'Loggable.objectToString',
        );
        expect(
          Loggable.objectToJson(wrapper),
          {
            ':k': 'list',
            ':l': 3,
            ':v': [1],
          },
          reason: 'Loggable.objectToJson',
        );
      },
    );

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
      _printData(data);
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

      _printData(data);
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
      expect(_printData(LoggableMultiData({})), 'login:');
    });

    test('an empty multi-data prints its colon with a rule armed too', () {
      // The data block must not depend on the mere presence of a rule:
      // an empty rendering is a legitimate rendering, and only
      // `Sanitize.drop` removes the block. The printer used to read
      // "empty output + a sanitizer installed" as a drop.
      Loggable.sanitizer = (ctx) => ctx.value;

      expect(_printData(LoggableMultiData({})), 'login:');
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
        _printData(
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

  group('sanitizer scope — the error and the tags stay outside it', () {
    tearDown(() => Loggable.sanitizer = null);

    test('a Loggable error is rendered the same without a rule', () {
      expect(
        _printError({'k': 1}, _Boom()),
        'login: {₌₁ k: 1}: _Boom(code: "E42")',
      );
    });

    test('a root drop rule does not erase a Loggable error', () {
      // The rule owns the `data` block and nothing else: dropping the
      // root removes the data, but an error erased along with it would
      // leave a dangling colon and lose the only reason the log exists.
      Loggable.sanitizer = (ctx) => ctx.depth == 0 ? Sanitize.drop : ctx.value;

      expect(
        _printError({'k': 1}, _Boom()),
        'login: _Boom(code: "E42")',
      );
    });

    test('a root replacement rule leaves a Loggable error unchanged', () {
      Loggable.sanitizer = (ctx) => ctx.depth == 0 ? '***' : ctx.value;

      expect(
        _printError({'k': 1}, _Boom()),
        'login: "***": _Boom(code: "E42")',
      );
    });

    test('a root rule does not reach an error without any data either', () {
      Loggable.sanitizer = (ctx) => ctx.depth == 0 ? '***' : ctx.value;

      expect(_printError(Log.noData, _Boom()), 'login: _Boom(code: "E42")');
    });

    test('the props of an error are still offered by their position', () {
      // Suppressing the ROOT offer must not shift the depth or the path
      // of anything below it: the guard segment is not part of either.
      final paths = <String>[];
      Loggable.sanitizer = (ctx) {
        paths.add('${ctx.path}@${ctx.depth}');

        return ctx.name == 'code' ? '***' : ctx.value;
      };

      expect(_printError(Log.noData, _Boom()), 'login: _Boom(code: "***")');
      expect(paths, ['code@1']);
    });

    test('a root rule does not rewrite the tag set of a Log', () {
      // `Log.tags` is not a rendering: it is cached on the log, feeds
      // `activeTags` filtering and is what every non-rendering publisher
      // sees.
      Loggable.sanitizer = (ctx) => ctx.depth == 0 ? '***' : ctx.value;

      expect(_logWithTags([_Tag('t')]).tags, {'_Tag(v: "t")'});
    });

    test('a root drop rule does not erase a Loggable tag', () {
      Loggable.sanitizer = (ctx) => ctx.depth == 0 ? Sanitize.drop : ctx.value;

      expect(_logWithTags([_Tag('t')]).tags, {'_Tag(v: "t")'});
    });

    test('a root rule does not rewrite a Loggable tag on the console', () {
      Loggable.sanitizer = (ctx) => ctx.depth == 0 ? '***' : ctx.value;

      final out = _printTags([_Tag('t')]);
      expect(out, contains('#_Tag(v: "t")'));
      expect(out, isNot(contains('***')));
    });

    test('tags are unchanged without a rule', () {
      expect(_logWithTags([_Tag('t')]).tags, {'_Tag(v: "t")'});
      expect(_printTags([_Tag('t')]), contains('#_Tag(v: "t")'));
    });

    test('a Loggable stack trace is rendered the same without a rule', () {
      expect(_printTrace(_Trace()), contains('_Trace'));
    });

    test('a root drop rule does not erase a Loggable stack trace', () {
      // `Trace.from` is lazy: it stringifies the stack trace only when
      // the frames are read, so the suppression has to survive until
      // then.
      Loggable.sanitizer = (ctx) => ctx.depth == 0 ? Sanitize.drop : ctx.value;

      expect(_printTrace(_Trace()), contains('_Trace'));
    });

    test('a root replacement rule leaves a Loggable stack trace alone', () {
      Loggable.sanitizer = (ctx) => ctx.depth == 0 ? '***' : ctx.value;

      final out = _printTrace(_Trace());
      expect(out, contains('_Trace'));
      expect(out, isNot(contains('***')));
    });
  });

  group('sanitizer scope — the message and the path stay outside it', () {
    tearDown(() => Loggable.sanitizer = null);

    test('a Loggable message is rendered the same without a rule', () {
      expect(_capture(Logger('app'), (l) => l.i(_Msg())).message, _msgText);
    });

    test('a root drop rule does not erase a Loggable message', () {
      // `LazyString.convert` is a library-side `toString()` on a value
      // outside the scope — erasing it would leave a log with no text.
      Loggable.sanitizer = (ctx) => ctx.depth == 0 ? Sanitize.drop : ctx.value;

      expect(_capture(Logger('app'), (l) => l.i(_Msg())).message, _msgText);
    });

    test('a root replacement rule does not rewrite a Loggable message', () {
      Loggable.sanitizer = (ctx) => ctx.depth == 0 ? '***' : ctx.value;

      expect(_capture(Logger('app'), (l) => l.i(_Msg())).message, _msgText);
    });

    test('a Loggable message survives on the console', () {
      Loggable.sanitizer = (ctx) => ctx.depth == 0 ? Sanitize.drop : ctx.value;

      expect(_printMessage(_Msg()), contains(_msgText));
    });

    test('a lazy Loggable message is resolved outside the scope too', () {
      // The closure itself runs OUTSIDE the guard (it is user code); only
      // the `toString()` of what it returned is guarded.
      Loggable.sanitizer = (ctx) => ctx.depth == 0 ? Sanitize.drop : ctx.value;

      expect(_capture(Logger('app'), (l) => l.i(_Msg.new)).message, _msgText);
    });

    test('interpolation done by the caller is still sanitized', () {
      // The accepted boundary: `'$obj'` runs in user code before the log
      // call, so the root rule still reaches it. This is the one case the
      // release notes record as affected.
      Loggable.sanitizer = (ctx) => ctx.depth == 0 ? '***' : ctx.value;

      expect(_capture(Logger('app'), (l) => l.i('${_Msg()}')).message, '"***"');
      expect(
        _capture(Logger('app'), (l) => l.i(() => '${_Msg()}')).message,
        '"***"',
        reason: 'a closure interpolating it is caller code as well',
      );
    });

    test('a Loggable logger name keeps its real path', () {
      Loggable.sanitizer = (ctx) => ctx.depth == 0 ? '***' : ctx.value;

      expect(_capture(Logger(_Name('svc')), (l) => l.i('m')).path, _nameText);
    });

    test('a root drop rule does not erase the path either', () {
      Loggable.sanitizer = (ctx) => ctx.depth == 0 ? Sanitize.drop : ctx.value;

      expect(_capture(Logger(_Name('svc')), (l) => l.i('m')).path, _nameText);
    });

    test('a Loggable child name keeps its real path', () {
      Loggable.sanitizer = (ctx) => ctx.depth == 0 ? '***' : ctx.value;

      final child = Logger(_Name('svc')).createChild(name: _Name('child'));

      expect(
        _capture(child, (l) => l.i('m')).path,
        '$_nameText/_Name(v: "child")',
      );
    });

    test('the path is guarded where it is forced, not where it is built', () {
      // `_lazyPath` resolves on the first `path` read and memoizes the
      // result — once poisoned it stays poisoned for the process. The
      // logger is built under one rule and forced under another.
      Loggable.sanitizer = (ctx) => ctx.depth == 0 ? '***' : ctx.value;
      final logger = Logger(_Name('svc'));

      Loggable.sanitizer = (ctx) => ctx.depth == 0 ? Sanitize.drop : ctx.value;

      expect(logger.path, _nameText);
    });

    test('a Loggable namespace still matches activeNamespaces filtering', () {
      // The active theme keeps BBCode literal, the inactive one strips
      // it — so the marker shows which branch the filter took.
      Loggable.sanitizer = (ctx) => ctx.depth == 0 ? '***' : ctx.value;

      expect(
        _printFiltered(Logger(_Name('svc')), {_nameText}),
        contains('[b]hit[/b]'),
        reason: 'the namespace matches, so the log is active',
      );
      expect(
        _printFiltered(Logger(_Name('svc')), {'other'}),
        isNot(contains('[b]')),
        reason: 'a non-matching namespace still leaves the log inactive',
      );
    });
  });
}

/// Runs a log carrying an [error] through a real [ConsoleLogPrinter].
String _printError(Object? data, Object error) {
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
    ..i('login', data: data, error: error);

  return lines.join('\n').trimRight();
}

/// Runs a tagged log through a real [ConsoleLogPrinter] printing the tags.
String _printTags(Object? tags) {
  final lines = <String>[];
  Logger('app')
    ..level = LogLevels.all
    ..publisher = ConsoleLogPrinter(
      theme: LogMainTheme.noColors,
      rows: const [
        LogRow.singleLine(children: [LogMessage(), LogTags()]),
      ],
      output: lines.add,
    )
    ..i('login', tags: tags);

  return lines.join('\n').trimRight();
}

/// Runs a log carrying [stackTrace] through a real [ConsoleLogPrinter].
String _printTrace(StackTrace stackTrace) {
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
    ..i('login', stackTrace: stackTrace);

  return lines.join('\n');
}

/// The [Log] a tagged call produced, as a non-rendering publisher sees it.
Log _logWithTags(Object? tags) =>
    _capture(Logger('app'), (l) => l.i('login', tags: tags));

/// The [Log] [emit] produced on [logger], as a non-rendering publisher
/// sees it.
Log _capture(Logger logger, void Function(Logger logger) emit) {
  final publisher = _CapturePublisher();
  logger
    ..level = LogLevels.all
    ..publisher = publisher;
  emit(logger);

  return publisher.logs.single;
}

/// Runs a log whose MESSAGE is [message] through a real
/// [ConsoleLogPrinter].
String _printMessage(Object message) {
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
    ..i(message);

  return lines.join('\n');
}

/// Prints one log through a printer filtering on [activeNamespaces].
String _printFiltered(Logger logger, Set<String> activeNamespaces) {
  final lines = <String>[];
  logger
    ..level = LogLevels.all
    ..publisher = ConsoleLogPrinter(
      theme: LogMainTheme.noColors,
      inactiveTheme: LogMainTheme.noColorsNoTags,
      activeNamespaces: activeNamespaces,
      rows: const [
        LogRow.singleLine(children: [LogMessage()]),
      ],
      output: lines.add,
    )
    ..i('[b]hit[/b]');

  return lines.join('\n');
}

final class _CapturePublisher implements CustomLogPublisher<Log> {
  final logs = <Log>[];

  @override
  void publish(Log log) => logs.add(log);
}

/// An error object that is also [Loggable] — the library renders it with
/// `toString()`, outside the walkers.
final class _Boom with Loggable implements Exception {
  @override
  void collectLoggableData(LoggableData data) => data.prop('code', 'E42');
}

/// A tag object that is also [Loggable]: `LazyTags` turns it into a string
/// with `toString()`.
final class _Tag with Loggable {
  final String value;

  _Tag(this.value);

  @override
  void collectLoggableData(LoggableData data) => data.prop('v', value);
}

/// A stack trace that is also [Loggable]: both the printer (through
/// `Trace.from`) and `FileLogCodec` render it with `toString()`.
final class _Trace with Loggable implements StackTrace {
  @override
  void collectLoggableData(LoggableData data) => data.prop('at', 'main');
}

const _msgText = '_Msg(text: "hi")';

/// A message object that is also [Loggable]: `LazyString` turns it into a
/// string with `toString()`.
final class _Msg with Loggable {
  @override
  void collectLoggableData(LoggableData data) => data.prop('text', 'hi');
}

const _nameText = '_Name(v: "svc")';

/// A logger name that is also [Loggable]: `Logger._lazyPath` turns it
/// into the namespace path with `toString()`.
final class _Name with Loggable {
  final String value;

  _Name(this.value);

  @override
  void collectLoggableData(LoggableData data) => data.prop('v', value);
}
