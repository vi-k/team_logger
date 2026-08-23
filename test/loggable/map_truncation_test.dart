import 'package:team_logger/team_logger.dart';
import 'package:test/test.dart';

/// A `Map` obeys the collection limits, the way a `List` and a `Set` do.
///
/// The shapes here are deliberately the same shapes the list renderer
/// produces for the same limits — the two are compared side by side in
/// "a Map truncates like a List". A map is ordered and re-iterable, so the
/// first entries and the last one survive a cut, exactly as for a list.

const _five = {'a': 1, 'b': 2, 'c': 3, 'd': 4, 'e': 5};

String _map(Map<Object?, Object?> map, [LoggableConfig? config]) =>
    Loggable.objectToString(map, config: config ?? const LoggableConfig());

String _list(List<Object?> list, [LoggableConfig? config]) =>
    Loggable.objectToString(list, config: config ?? const LoggableConfig());

void main() {
  tearDown(() {
    Loggable.defaultConfig = const LoggableConfig();
    Loggable.forceConfig = const LoggableConfig();
    Loggable.sanitizer = null;
  });

  group('a Map reports its size', () {
    test('an untruncated map says how many entries it has', () {
      expect(_map(_five), '{₌₅ a: 1, b: 2, c: 3, d: 4, e: 5}');
    });

    test('an empty map says so', () {
      expect(_map(const {}), '{₌₀}');
    });

    test('collectionShowCount: false takes the count off', () {
      expect(
        _map(_five, const LoggableConfig(collectionShowCount: false)),
        '{a: 1, b: 2, c: 3, d: 4, e: 5}',
      );
    });
  });

  group('collectionMaxCount truncates a Map', () {
    test('the first entries and the last one survive', () {
      expect(
        _map(_five, const LoggableConfig(collectionMaxCount: 3)),
        '{₌₅ a: 1, b: 2, …, e: 5}',
      );
    });

    test('a limit of two keeps the first and the last', () {
      expect(
        _map(_five, const LoggableConfig(collectionMaxCount: 2)),
        '{₌₅ a: 1, …, e: 5}',
      );
    });

    test('a limit of one keeps only the first', () {
      expect(
        _map(_five, const LoggableConfig(collectionMaxCount: 1)),
        '{₌₅ a: 1, …}',
      );
    });

    test('a limit of zero keeps nothing but the count', () {
      expect(
        _map(_five, const LoggableConfig(collectionMaxCount: 0)),
        '{₌₅ …}',
      );
    });

    test('a limit above the size changes nothing', () {
      expect(
        _map(_five, const LoggableConfig(collectionMaxCount: 99)),
        '{₌₅ a: 1, b: 2, c: 3, d: 4, e: 5}',
      );
    });
  });

  group('a Map truncates like a List', () {
    // One setting has to mean one thing across collections, so for every
    // limit a map of five and a list of five must show the same number of
    // items and put the ellipsis in the same place.
    for (final limit in [0, 1, 2, 3, 4, 5, 99]) {
      test('a limit of $limit shows as many entries as it shows elements', () {
        final config = LoggableConfig(collectionMaxCount: limit);
        final asMap = _map(_five, config);
        final asList = _list([1, 2, 3, 4, 5], config);

        expect(
          ', '.allMatches(asMap).length,
          ', '.allMatches(asList).length,
          reason: '$asMap vs $asList',
        );
        expect(asMap.contains('…'), asList.contains('…'), reason: asMap);
      });
    }
  });

  group('collectionMaxStringLength truncates a Map', () {
    test('a tight budget falls back to the count and an ellipsis', () {
      expect(
        _map(_five, const LoggableConfig(collectionMaxStringLength: 8)),
        '{₌₅ …}',
      );
    });

    test('a budget that fits the head keeps the head and the last', () {
      final rendered =
          _map(_five, const LoggableConfig(collectionMaxStringLength: 20));

      expect(rendered, startsWith('{₌₅ a: 1'));
      expect(rendered, contains('…'));
      expect(rendered.length, lessThanOrEqualTo(20 + '₌₅ '.length));
    });
  });

  group('the sanitizer and the limit', () {
    test('a dropped entry does not use up a slot', () {
      Loggable.sanitizer = (ctx) => ctx.name == 'b' ? Sanitize.drop : ctx.value;

      // 'b' is gone, so the two shown entries are 'a' and 'c'.
      expect(
        _map(_five, const LoggableConfig(collectionMaxCount: 3)),
        '{₌₅ a: 1, c: 3, …, e: 5}',
      );
    });

    test('the reported size is the size of the map, not of the output', () {
      Loggable.sanitizer = (ctx) => ctx.name == 'b' ? Sanitize.drop : ctx.value;

      // Four entries printed out of five: the count is the only trace that
      // one of them was redacted away.
      expect(_map(_five), '{₌₅ a: 1, c: 3, d: 4, e: 5}');
    });
  });

  group('JSON changes shape only when truncated', () {
    test('a whole map stays a plain object', () {
      expect(Loggable.objectToJson(_five), {
        'a': 1,
        'b': 2,
        'c': 3,
        'd': 4,
        'e': 5,
      });
    });

    test('a truncated map reports its length like a list does', () {
      expect(
        Loggable.objectToJson(
          _five,
          config: const LoggableJsonConfig(collectionMaxCount: 3),
        ),
        {
          ':k': 'map',
          ':l': 5,
          ':v': {'a': 1, 'b': 2, 'e': 5},
        },
      );
    });
  });

  group('the limit takes the config layers', () {
    test('a forced cap is not lifted by the call site', () {
      Loggable.forceConfig = const LoggableConfig(collectionMaxCount: 2);

      expect(
        _map(_five, const LoggableConfig(collectionMaxCount: 99)),
        '{₌₅ a: 1, …, e: 5}',
      );
    });
  });
}
