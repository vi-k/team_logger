import 'dart:async';

import 'package:team_logger/team_logger.dart';
import 'package:test/test.dart';

/// Captures whatever `print` wrote.
String _captured(void Function() body) {
  final lines = <String>[];
  runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      print: (_, __, ___, line) => lines.add(line),
    ),
  );

  return lines.join('\n');
}

/// Data that legitimately renders to an empty string.
LoggableData _emptyRendering() => Loggable.builder(
      Object(),
      showName: false,
      showBrackets: false,
    );

/// Regressions from task D of the 0.6.1 cross-review: one `units` policy for
/// a root replacement (D1), an explicit "dropped" signal instead of an empty
/// string (D2), multi-data with every section dropped (D3), and the root
/// offer on `toString()` (D4).
void main() {
  group('sanitizer root — units are not inherited by a replacement', () {
    tearDown(() => Loggable.sanitizer = null);

    test('a multi-data root replacement drops the container units', () {
      // `units` is a claim about a quantity, and a replacement is not that
      // quantity: the same rule that already applies to a property
      // (`LoggableConfig.withoutUnits`) now applies at the root too. All four
      // multi-data renderers must agree.
      Loggable.sanitizer = (ctx) => ctx.depth == 0 ? 12 : ctx.value;

      final data = LoggableMultiData(
        {'s': 'topsecret'},
        config: const LoggableConfig(units: 'kg'),
      );

      expect(data.toString(), '12', reason: 'LoggableMultiData.toString');
      expect(
        Loggable.objectToString(data),
        '12',
        reason: 'Loggable.objectToString',
      );
      expect(Loggable.objectToJson(data), 12, reason: 'Loggable.objectToJson');
      expect(_printData(data), 'login: 12', reason: 'ConsoleLogPrinter');
    });

    test('the rest of the container config still applies to a replacement', () {
      // Only `units` is stripped from the inherited container config:
      // `collectionMaxCount` and the other fields describe how to print
      // rather than a quantity, and stay in force.
      Loggable.sanitizer = (ctx) => ctx.depth == 0 ? [1, 2, 3] : ctx.value;

      final data = LoggableMultiData(
        {'s': 'topsecret'},
        config: const LoggableConfig(collectionMaxCount: 1, units: 'kg'),
      );

      expect(Loggable.objectToString(data), '[₌₃ ₀:1, …]');
    });

    test('units survive when the rule does not touch the root', () {
      Loggable.sanitizer = (ctx) => ctx.value;

      final data = LoggableMultiData(
        {'s': 12},
        config: const LoggableConfig(units: 'kg'),
      );

      expect(Loggable.objectToString(data), 's: 12kg');
      expect(Loggable.objectToJson(data), {
        ':k': 'multi',
        's': {':v': 12, ':u': 'kg'},
      });
    });

    test('a wrapper root replacement drops the wrapper units too', () {
      Loggable.sanitizer = (ctx) => ctx.depth == 0 ? 12 : ctx.value;

      final data = Loggable.from(1, config: const LoggableConfig(units: 'kg'));
      expect(
        Loggable.objectToString(data),
        '12',
        reason: 'Loggable.objectToString',
      );
      expect(Loggable.objectToJson(data), 12, reason: 'Loggable.objectToJson');
      expect(_printData(data), 'login: 12', reason: 'ConsoleLogPrinter');
    });

    test('an ambient units config is not applied to a replacement either', () {
      Loggable.sanitizer = (ctx) => ctx.depth == 0 ? 12 : ctx.value;

      expect(
        Loggable.objectToString(1, config: const LoggableConfig(units: 'kg')),
        '12',
      );
    });
  });

  group('sanitizer root — a replacement inherits the container config', () {
    tearDown(() => Loggable.sanitizer = null);

    // A replacement takes the container's place, so it is printed with the
    // container's settings. `units` is stripped; the rest — how to print — is
    // inherited. Only `LoggableMultiData` and `LoggableWrapper` used to manage
    // this: the builders keep their config in a private field the shared code
    // could not see.
    const config = LoggableConfig(collectionMaxCount: 1, units: 'kg');

    setUp(() {
      Loggable.sanitizer = (ctx) => ctx.depth == 0 ? [1, 2, 3] : ctx.value;
    });

    test('builder applies collectionMaxCount to a root replacement', () {
      final data = Loggable.builder(Object(), config: config)
        ..prop('s', 'topsecret');

      expect(Loggable.objectToString(data), '[₌₃ ₀:1, …]');
      expect(Loggable.objectToJson(data), {
        ':k': 'list',
        ':l': 3,
        ':v': [1],
      });
    });

    test('mapBuilder applies collectionMaxCount to a root replacement', () {
      final data = Loggable.mapBuilder(config: config)..prop('s', 'topsecret');

      expect(Loggable.objectToString(data), '[₌₃ ₀:1, …]');
      expect(Loggable.objectToJson(data), {
        ':k': 'list',
        ':l': 3,
        ':v': [1],
      });
    });

    test('multi-data does the same in JSON, not only in the string', () {
      final data = LoggableMultiData({'s': 'topsecret'}, config: config);

      expect(Loggable.objectToString(data), '[₌₃ ₀:1, …]');
      expect(Loggable.objectToJson(data), {
        ':k': 'list',
        ':l': 3,
        ':v': [1],
      });
    });

    test('a wrapper keeps doing it by unwrapping before the root offer', () {
      final data = LoggableWrapper('topsecret', config: config);

      expect(Loggable.objectToString(data), '[₌₃ ₀:1, …]');
      expect(Loggable.objectToJson(data), {
        ':k': 'list',
        ':l': 3,
        ':v': [1],
      });
    });

    test('a builder without its own config still takes the outer one', () {
      final data = Loggable.builder(Object())..prop('s', 'topsecret');

      expect(
        Loggable.objectToString(data, config: config),
        '[₌₃ ₀:1, …]',
      );
    });
  });

  group('sanitizer root — an empty rendering is not a drop', () {
    tearDown(() => Loggable.sanitizer = null);

    test('a replacement rendering empty keeps the colon on the console', () {
      // Before the fix a drop was reported as an empty string, so a
      // replacement that legitimately rendered to nothing read as a drop:
      // `login` was printed instead of `login: `.
      Loggable.sanitizer =
          (ctx) => ctx.depth == 0 ? _emptyRendering() : ctx.value;

      expect(_printData({'s': 'topsecret'}), 'login:');
      expect(_printData(LoggableMultiData({'s': 'topsecret'})), 'login:');
    });

    test('a dropped root still removes the data block', () {
      Loggable.sanitizer = (ctx) => ctx.depth == 0 ? Sanitize.drop : ctx.value;

      expect(_printData({'s': 'topsecret'}), 'login');
      expect(_printData(LoggableMultiData({'s': 'topsecret'})), 'login');
    });
  });

  group('sanitizer root — multi-data with every section dropped', () {
    tearDown(() => Loggable.sanitizer = null);

    test('leaves no data block at all', () {
      // A dangling `login: ` label with no contents is noise: the data block
      // disappears if the text is empty AND at least one entry was dropped.
      Loggable.sanitizer = (ctx) => ctx.depth == 0 ? ctx.value : Sanitize.drop;

      expect(
        _printData(LoggableMultiData({'a': 1, 'b': 2})),
        'login',
      );
    });

    test('an empty multi-data keeps its colon with a rule armed', () {
      // A multi-data that is empty on its own is a legitimate empty render,
      // not a drop (pinned in B6).
      Loggable.sanitizer = (ctx) => ctx.value;

      expect(_printData(LoggableMultiData({})), 'login:');
    });

    test('an empty multi-data keeps its colon without a rule', () {
      expect(_printData(LoggableMultiData({})), 'login:');
    });

    test('surviving sections are still printed when only some are dropped', () {
      Loggable.sanitizer =
          (ctx) => ctx.name == 'password' ? Sanitize.drop : ctx.value;

      expect(
        _printData(LoggableMultiData({'req': 'ok', 'password': 'hunter2'})),
        'login: req: "ok"',
      );
    });
  });

  group('sanitizer root — toString offers the root', () {
    tearDown(() => Loggable.sanitizer = null);

    test('a root rule reaches string interpolation of a Loggable', () {
      Loggable.sanitizer = (ctx) => ctx.depth == 0 ? '<ROOT>' : ctx.value;

      final user = _User('ann', 'topsecret');
      expect('$user', '"<ROOT>"');
      expect(Loggable.objectToString(user), '"<ROOT>"');
    });

    test('a root rule reaches LoggableData.toString', () {
      Loggable.sanitizer = (ctx) => ctx.depth == 0 ? '<ROOT>' : ctx.value;

      final data = Loggable.builder(Object())..prop('s', 'topsecret');
      expect('$data', '"<ROOT>"');
      expect(Loggable.objectToString(data), '"<ROOT>"');
    });

    test('a root drop renders an empty string on interpolation', () {
      Loggable.sanitizer = (ctx) => ctx.depth == 0 ? Sanitize.drop : ctx.value;

      expect('${_User('ann', 'topsecret')}', isEmpty);
      expect(
        '${Loggable.builder(Object())..prop('s', 'topsecret')}',
        isEmpty,
      );
    });

    test('print() goes through the same root offer', () {
      Loggable.sanitizer = (ctx) => ctx.depth == 0 ? '<ROOT>' : ctx.value;

      expect(_captured(() => print(_User('ann', 'topsecret'))), '"<ROOT>"');
    });

    test('props are still sanitized on the toString path', () {
      Loggable.sanitizer = (ctx) => ctx.name == 'password' ? '***' : ctx.value;

      final user = _User('ann', 'hunter2');
      expect('$user', '_User(name: "ann", password: "***")');
      expect(
        '${Loggable.mapBuilder()..prop('password', 'hunter2')}',
        // mapBuilder is a structure of props, not a collection: limits do
        // not apply to it and it has no entry counter.
        '{password: "***"}',
      );
    });

    test('the root is offered exactly once on every path', () {
      var roots = 0;
      Loggable.sanitizer = (ctx) {
        if (ctx.depth == 0) roots++;

        return ctx.value;
      };

      final user = _User('ann', 'hunter2');
      final data = Loggable.builder(Object())..prop('s', 'x');

      Loggable.objectToString(user);
      expect(roots, 1, reason: 'objectToString');

      roots = 0;
      Loggable.objectToJson(user);
      expect(roots, 1, reason: 'objectToJson');

      roots = 0;
      user.toString();
      expect(roots, 1, reason: 'Loggable.toString via interpolation');

      roots = 0;
      _captured(() => print(user));
      expect(roots, 1, reason: 'print(obj)');

      roots = 0;
      data.toString();
      expect(roots, 1, reason: 'LoggableData.toString');

      roots = 0;
      Loggable.objectToString(data);
      expect(roots, 1, reason: 'objectToString of a LoggableData');

      roots = 0;
      Loggable.objectToJson(data);
      expect(roots, 1, reason: 'objectToJson of a LoggableData');
    });

    test('a nested Loggable is not offered a second time as a root', () {
      // `toString()` of a nested object is called from inside the walk —
      // there the value has already been offered at its own position.
      final seen = <String>[];
      Loggable.sanitizer = (ctx) {
        seen.add('${ctx.path}@${ctx.depth}');

        return ctx.value;
      };

      Loggable.objectToString({'u': _User('ann', 'hunter2')});

      expect(seen, ['@0', 'u@1', 'u.name@2', 'u.password@2']);
    });

    test('a Loggable map key still offers its props once, not a root', () {
      final seen = <String>[];
      Loggable.sanitizer = (ctx) {
        seen.add('${ctx.path}@${ctx.depth}');

        return ctx.value;
      };

      final map = <Object?, Object?>{_Account('DE89'): 'primary'};

      Loggable.objectToString(map);
      final text = [...seen];
      seen.clear();

      Loggable.objectToJson(map);

      expect(text, ['@0', 'iban@1', '_Account(iban: "DE89")@1']);
      expect(seen, text);
    });

    test('a Loggable reached through a plain toString is not a second root',
        () {
      // The walker draws an unknown type with its own `toString()`, and that
      // is free to interpolate a [Loggable]. Without a guard covering the
      // whole root render the stack would be empty at that moment — and the
      // nested object would make a SECOND root offer (`@0`), shadowing the
      // real root for rules keyed on depth == 0.
      final seen = <String>[];
      Loggable.sanitizer = (ctx) {
        seen.add('${ctx.path}@${ctx.depth}');

        return ctx.value;
      };

      final envelope = _Envelope(_Account('DE89'));

      Loggable.objectToString(envelope);
      expect(seen, ['@0', 'iban@1'], reason: 'objectToString');

      seen.clear();
      Loggable.objectToJson(envelope);
      expect(seen, ['@0', 'iban@1'], reason: 'objectToJson');
    });

    test('a rule rendering the value it was handed does not recurse', () {
      // A contract violation (a rule must not render), but it must not hang
      // the process: the guard is held both for the duration of the rule call
      // and for the whole root render.
      Loggable.sanitizer = (ctx) => ctx.depth == 0 ? '${ctx.value}' : ctx.value;

      expect('${_User('ann', 'hunter2')}', contains('_User'));
    });

    test('without a rule toString is unchanged', () {
      expect(
        _User('ann', 'hunter2').toString(),
        '_User(name: "ann", password: "hunter2")',
      );
      expect(
        (Loggable.builder(Object(), name: 'D')..prop('s', 'x')).toString(),
        'D(s: "x")',
      );
    });
  });
}

/// Runs a log through a real [ConsoleLogPrinter] into a single line.
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

final class _User with Loggable {
  final String name;
  final String password;

  _User(this.name, this.password);

  @override
  void collectLoggableData(LoggableData data) {
    data
      ..prop('name', name)
      ..prop('password', password);
  }
}

final class _Account with Loggable {
  final String iban;

  _Account(this.iban);

  @override
  void collectLoggableData(LoggableData data) => data.prop('iban', iban);
}

/// A type the walker knows nothing about: it is drawn by its own
/// `toString()`, which in turn reaches into [Loggable].
final class _Envelope {
  final _Account inner;

  _Envelope(this.inner);

  @override
  String toString() => 'Envelope($inner)';
}
