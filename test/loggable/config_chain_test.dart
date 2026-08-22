import 'package:team_logger/team_logger.dart';
import 'package:test/test.dart';

/// The `default ← user ← force` chain: an application-wide default nobody
/// has to repeat, and a policy no call site can switch off.
///
/// The force layer is the one that has to hold under pressure — it exists so
/// that a rule like "escape control codes" cannot be lifted by a nested
/// container or by the call that logs the value.

void main() {
  tearDown(() {
    Loggable.defaultConfig = const LoggableConfig();
    Loggable.forceConfig = const LoggableConfig();
    Loggable.sanitizer = null;
  });

  group('empty layers change nothing', () {
    test('the default output is what it always was', () {
      expect(Loggable.objectToString('x'), '"x"');
      expect(Loggable.objectToString([1, 2, 3]), '[₌₃ ₀:1, ₁:2, ₂:3]');
      expect(Loggable.objectToJson([1, 2, 3]), [1, 2, 3]);
    });
  });

  group('the default layer', () {
    test('applies where the call site said nothing', () {
      Loggable.defaultConfig = const LoggableConfig(stringInQuotes: false);

      expect(Loggable.objectToString('x'), 'x');
    });

    test('loses to the call site', () {
      Loggable.defaultConfig = const LoggableConfig(stringInQuotes: false);

      expect(
        Loggable.objectToString(
          'x',
          config: const LoggableConfig(stringInQuotes: true),
        ),
        '"x"',
      );
    });

    test('loses to a container of its own', () {
      Loggable.defaultConfig = const LoggableConfig(collectionMaxCount: 1);

      expect(
        Loggable.objectToString(
          Loggable.from(
            [1, 2, 3],
            config: const LoggableConfig(collectionMaxCount: 2),
          ),
        ),
        // A list keeps its first and last element, so a limit of 2 renders
        // "first, …, last" rather than "first, second, …".
        '[₌₃ ₀:1, …, ₂:3]',
      );
    });

    test('reaches the JSON output too', () {
      Loggable.defaultConfig = const LoggableConfig(collectionMaxCount: 1);

      expect(Loggable.objectToJson([1, 2, 3]), {
        ':k': 'list',
        ':l': 3,
        ':v': [1],
      });
    });
  });

  group('the force layer', () {
    test('beats the call site', () {
      Loggable.forceConfig = const LoggableConfig(stringInQuotes: false);

      expect(
        Loggable.objectToString(
          'x',
          config: const LoggableConfig(stringInQuotes: true),
        ),
        'x',
      );
    });

    test('beats a container that sets the same field', () {
      // The nesting is the point: a container config is merged during the
      // walk, long after the call site was read, and must not be a way
      // around the policy.
      Loggable.forceConfig = const LoggableConfig(collectionMaxCount: 1);

      expect(
        Loggable.objectToString(
          Loggable.from(
            [1, 2, 3],
            config: const LoggableConfig(collectionMaxCount: 3),
          ),
        ),
        '[₌₃ ₀:1, …]',
      );
    });

    test('beats a builder property config', () {
      Loggable.forceConfig = const LoggableConfig(stringInQuotes: false);

      final data = Loggable.mapBuilder()
        ..prop(
          'a',
          'x',
          config: const LoggableConfig(stringInQuotes: true),
        );

      expect(Loggable.objectToString(data), '{a: x}');
    });

    test('beats the default layer', () {
      Loggable.defaultConfig = const LoggableConfig(stringInQuotes: true);
      Loggable.forceConfig = const LoggableConfig(stringInQuotes: false);

      expect(Loggable.objectToString('x'), 'x');
    });

    test('reaches the JSON output too', () {
      Loggable.forceConfig = const LoggableConfig(collectionMaxCount: 1);

      expect(
        Loggable.objectToJson(
          Loggable.from(
            [1, 2, 3],
            config: const LoggableConfig(collectionMaxCount: 3),
          ),
        ),
        {
          ':k': 'list',
          ':l': 3,
          ':v': [1],
        },
      );
    });

    test('a field it does not set is left to the layers below', () {
      Loggable.forceConfig = const LoggableConfig(collectionMaxCount: 1);

      expect(
        Loggable.objectToString(
          ['ab'],
          config: const LoggableConfig(stringInQuotes: false),
        ),
        '[₌₁ ₀:ab]',
      );
    });
  });

  group('units keep their own rule', () {
    test('a root replacement drops units even when they are forced', () {
      // Units assert something about the original quantity, and a mask is
      // not that quantity. That holds against the force layer as well.
      Loggable.forceConfig = const LoggableConfig(units: 'kg');
      Loggable.sanitizer = (ctx) => ctx.depth == 0 ? 'masked' : ctx.value;

      expect(Loggable.objectToString(12), '"masked"');
    });

    test('forced units still reach an untouched value', () {
      Loggable.forceConfig = const LoggableConfig(units: 'kg');

      expect(Loggable.objectToString(12), '12kg');
    });
  });
}
