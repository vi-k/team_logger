import 'package:ansi_escape_codes/extensions.dart';
import 'package:team_logger/team_logger.dart';
import 'package:test/test.dart';

/// Regressions from the 0.6.1 cross-review (Codex plus an adversarial
/// reviewer).
///
/// Each group pins one finding: the double render of a [Map] key (B1), its
/// unconditional nature (B2), sanitizing an element cut off by a limit (B4),
/// and how [Prop] behaves under `Sanitize.drop` (B9.2). A separate group pins
/// what README §10 and the `Loggable.sanitizer` dartdoc promise about the
/// contents of a key object: where it is offered to the rule, under which
/// path, and where it is NOT offered (the leak into JSON).
void main() {
  group('cross-review — a map key is rendered exactly once', () {
    tearDown(() => Loggable.sanitizer = null);

    test('a Loggable key offers its props once, at one path in both outputs',
        () {
      // The key used to be rendered twice: once as a draft
      // `entry.key.toString()` (for the path) and once more into the output,
      // with diverging paths, so a path rule masked the draft and let the
      // printed one through.
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
      final json = [...seen];

      // The key's props are offered under the key's own path (a key is not a
      // path segment, see README §10); the entry's value is offered under the
      // key.
      expect(text, ['@0', 'iban@1', '_Account(iban: "DE89")@1']);
      expect(json, text);
    });

    test('a path rule masks the printed key in both outputs', () {
      Loggable.sanitizer = (ctx) => ctx.path == 'iban' ? '<masked>' : ctx.value;

      final map = <Object?, Object?>{
        _Account('DE89370400440532013000'): 'primary',
      };

      expect(
        Loggable.objectToString(map),
        '{₌₁ _Account(iban: "<masked>"): "primary"}',
      );
      expect(
        Loggable.objectToJson(map),
        {'_Account(iban: "<masked>")': 'primary'},
      );
    });

    test('a non-String key is rendered exactly once without a sanitizer', () {
      // "One null check per value, nothing more": with no rule installed the
      // key must render exactly as it did before 0.6.0.
      final key = _CountingKey();

      Loggable.objectToString(<Object?, Object?>{key: 1});
      expect(key.calls, 1, reason: 'objectToString');

      key.calls = 0;
      Loggable.objectToJson(<Object?, Object?>{key: 1});
      expect(key.calls, 1, reason: 'objectToJson');
    });

    test('a non-String key is rendered exactly once with a rule armed', () {
      Loggable.sanitizer = (ctx) => ctx.value;
      final key = _CountingKey();

      Loggable.objectToString(<Object?, Object?>{key: 1});
      expect(key.calls, 1, reason: 'objectToString');

      key.calls = 0;
      Loggable.objectToJson(<Object?, Object?>{key: 1});
      expect(key.calls, 1, reason: 'objectToJson');
    });

    test('a Loggable key with a throwing toString still renders as text', () {
      // Before 0.6.0 the string output drew non-String keys through
      // objectToString, so toString() of such a key was never called at all.
      final map = <Object?, Object?>{_ThrowingKey('DE89'): 'primary'};

      expect(
        Loggable.objectToString(map),
        '{₌₁ _ThrowingKey(iban: "DE89"): "primary"}',
      );
    });

    test('the same key still throws in JSON, as it did before 0.6.0', () {
      // An asymmetry between the two outputs, not an oversight: JSON draws
      // the key through `key.toString()` and already called it in 0.5.2.
      // Pinned so that "the string output does not call toString" is not read
      // as "nothing calls it anywhere".
      final map = <Object?, Object?>{_ThrowingKey('DE89'): 'primary'};

      expect(() => Loggable.objectToJson(map), throwsStateError);

      Loggable.sanitizer = (ctx) => ctx.value;
      expect(() => Loggable.objectToJson(map), throwsStateError);
    });

    test('the key handed to the rule carries no escape codes', () {
      final names = <String?>[];
      Loggable.sanitizer = (ctx) {
        names.add(ctx.name);

        return ctx.value;
      };

      // A theme with styles: the printed key itself is colored, but the name
      // and the path are data for the rule, not output.
      final theme = LogMainTheme(info: LogThemeData.gray10).info;
      final out = Loggable.objectToString(
        <Object?, Object?>{_Account('DE89'): 'primary'},
        theme: theme,
      );

      expect(out.ansiHasEscapeCodes, isTrue);
      expect(names.last, '_Account(iban: "DE89")');
    });
  });

  group('cross-review — what a key object exposes to the rule', () {
    tearDown(() => Loggable.sanitizer = null);

    test('a secret inside a non-Loggable key survives into JSON', () {
      // Documented behavior, not a bug filed "for later": the string output
      // draws any key with the walker, while JSON goes through
      // `key.toString()`, so in JSON the rule never descends into a plain
      // container used as a key. If this leak is ever closed the test fails —
      // and README §10 and the [sanitizer] dartdoc have to be updated with
      // it.
      Loggable.sanitizer = (ctx) => ctx.name == 'pw' ? '<masked>' : ctx.value;

      final map = <Object?, Object?>{
        {'pw': 'hunter2'}: 'primary',
      };

      expect(
        Loggable.objectToString(map),
        '{₌₁ {₌₁ pw: "<masked>"}: "primary"}',
      );
      expect(Loggable.objectToJson(map), {'{pw: hunter2}': 'primary'});
    });

    test('a Loggable key is offered in both outputs', () {
      // The flip side of the same asymmetry: `toString` of a [Loggable] key
      // goes through the walkers, so in JSON it does get sanitized after
      // all.
      Loggable.sanitizer = (ctx) => ctx.name == 'iban' ? '<masked>' : ctx.value;

      final map = <Object?, Object?>{_Account('DE89'): 'primary'};

      expect(
        Loggable.objectToString(map),
        '{₌₁ _Account(iban: "<masked>"): "primary"}',
      );
      expect(
        Loggable.objectToJson(map),
        {'_Account(iban: "<masked>")': 'primary'},
      );
    });

    test('the contents of a key carry the container path, not the entry', () {
      final seen = <String>[];
      Loggable.sanitizer = (ctx) {
        seen.add(ctx.path);

        return ctx.value;
      };

      Loggable.objectToString(<Object?, Object?>{
        'acc': <Object?, Object?>{_Account('DE89'): 'x'},
      });

      // The key's prop is `acc.iban`, i.e. the path of the CONTAINER `acc`,
      // not the entry path `acc._Account(iban: "DE89")`.
      expect(seen, ['', 'acc', 'acc.iban', 'acc._Account(iban: "DE89")']);
    });

    test('ctx.name of a non-String key is the key as that output renders it',
        () {
      // A consequence of the correct fix (the name is the key exactly as it
      // is printed, computed once and reused), not a bug: the string output
      // takes the name from objectToString, JSON from key.toString(). The two
      // forms differ, and the string one depends on the theme.
      final names = <String>[];
      Loggable.sanitizer = (ctx) {
        if (ctx.name case final name?) names.add(name);

        return ctx.value;
      };

      final listKey = <Object?, Object?>{
        [1, 2]: 'hunter2',
      };
      final enumKey = <Object?, Object?>{_Role.admin: 'hunter2'};

      Loggable.objectToJson(listKey);
      expect(names, ['[1, 2]'], reason: 'objectToJson');

      names.clear();
      Loggable.objectToString(listKey);
      expect(names, ['[₌₂ ₀:1, ₁:2]'], reason: 'objectToString');

      names.clear();
      Loggable.objectToJson(enumKey);
      expect(names, ['_Role.admin'], reason: 'objectToJson, enum key');

      names.clear();
      Loggable.objectToString(enumKey);
      expect(names, ['.admin'], reason: 'objectToString, enum key');
    });

    test('a name rule written for one output misses the other', () {
      // This is why the README and the dartdoc tell you to edit such entries
      // by value, or drop them whole, rather than with a rule matching the
      // key text.
      Loggable.sanitizer =
          (ctx) => ctx.name == '[1, 2]' ? '<masked>' : ctx.value;

      final map = <Object?, Object?>{
        [1, 2]: 'hunter2',
      };

      expect(Loggable.objectToJson(map), {'[1, 2]': '<masked>'});
      expect(Loggable.objectToString(map), contains('hunter2'));
    });

    test('dropping the entry is what keeps a key secret out of JSON', () {
      Loggable.sanitizer =
          (ctx) => ctx.name == '{pw: hunter2}' ? Sanitize.drop : ctx.value;

      expect(
        Loggable.objectToJson(<Object?, Object?>{
          {'pw': 'hunter2'}: 'primary',
        }),
        <String, Object?>{},
      );
    });
  });

  group('cross-review — collectionMaxCount does not render the cut tail', () {
    tearDown(() => Loggable.sanitizer = null);

    test('with maxCount 1 the last element is not offered to the rule', () {
      final offered = <String>[];
      Loggable.sanitizer = (ctx) {
        offered.add('${ctx.path}=${ctx.value}');

        return ctx.value;
      };

      expect(
        Loggable.objectToString(
          [1, 2, 3],
          config: const LoggableConfig(collectionMaxCount: 1),
        ),
        '[₌₃ ₀:1, …]',
      );
      expect(offered, ['=[1, 2, 3]', '[0]=1']);
    });

    test('with maxCount 1 and two elements the tail is not offered either', () {
      final offered = <String>[];
      Loggable.sanitizer = (ctx) {
        offered.add('${ctx.path}=${ctx.value}');

        return ctx.value;
      };

      expect(
        Loggable.objectToString(
          [1, 2],
          config: const LoggableConfig(collectionMaxCount: 1),
        ),
        '[₌₂ ₀:1, …]',
      );
      expect(offered, ['=[1, 2]', '[0]=1']);
    });

    test('the surviving last element is still offered, in output order', () {
      final offered = <String>[];
      Loggable.sanitizer = (ctx) {
        offered.add('${ctx.path}=${ctx.value}');

        return ctx.value;
      };

      expect(
        Loggable.objectToString(
          [1, 2, 3, 4],
          config: const LoggableConfig(collectionMaxCount: 3),
        ),
        '[₌₄ ₀:1, ₁:2, …, ₃:4]',
      );
      expect(offered, ['=[1, 2, 3, 4]', '[0]=1', '[3]=4', '[1]=2']);
    });
  });

  group('cross-review — LoggableData.toJson without a sanitizer', () {
    test('keeps the map shape', () {
      expect(
        Loggable.objectToJson(
          Loggable.builder(const Object(), name: 'D')
            ..prop('a', 1)
            ..prop('b', 2),
        ),
        {
          ':c': 'D',
          ':p': {'a': 1, 'b': 2},
        },
      );
    });

    test('keeps the list shape when an unnamed prop is present', () {
      expect(
        Loggable.objectToJson(
          Loggable.builder(const Object(), name: 'D')
            ..prop('a', 1)
            ..prop('b', 2, showName: false),
        ),
        {
          ':c': 'D',
          ':p': [
            {'a': 1},
            2,
          ],
        },
      );
    });
  });

  group('cross-review — a Prop rendered directly on drop', () {
    tearDown(() => Loggable.sanitizer = null);

    test('prints the drop marker, having no container to remove it from', () {
      Loggable.sanitizer =
          (ctx) => ctx.name == 'password' ? Sanitize.drop : ctx.value;

      final props = _User('ann', 'hunter2').logClassInfo().props;

      expect(
        props.map((p) => p.toLogString()).toList(),
        ['name: "ann"', 'password: <dropped>'],
      );
      expect(
        Map.fromEntries(props.map((p) => p.toMapEntry())),
        {
          'name': 'ann',
          'password': {':view': '<dropped>'},
        },
      );
    });

    test('rendering through LoggableData removes the prop entirely', () {
      Loggable.sanitizer =
          (ctx) => ctx.name == 'password' ? Sanitize.drop : ctx.value;

      expect(
        Loggable.objectToString(_User('ann', 'hunter2')),
        '_User(name: "ann")',
      );
    });
  });
}

final class _Account with Loggable {
  final String iban;

  _Account(this.iban);

  @override
  void collectLoggableData(LoggableData data) => data.prop('iban', iban);
}

final class _ThrowingKey with Loggable {
  final String iban;

  _ThrowingKey(this.iban);

  @override
  void collectLoggableData(LoggableData data) => data.prop('iban', iban);

  @override
  String toString() => throw StateError('toString must not be called');
}

enum _Role { admin }

final class _CountingKey {
  int calls = 0;

  @override
  String toString() {
    calls++;

    return 'key';
  }
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
