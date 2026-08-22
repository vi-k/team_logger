import 'dart:collection';

import 'package:team_logger/team_logger.dart';
import 'package:test/test.dart';

/// A bare `Iterable` is rendered without reading its length or its last
/// element, because it may be single-pass or expensive to walk twice. Where
/// the caller knows better, `iterableEfficientLength` says so and the richer
/// rendering — the count and the last element — becomes available.
///
/// The flag is an assertion by the caller, like `units`: the package cannot
/// tell an efficient-length iterable from a generator.

/// Counts what the renderer asks of it.
final class _Counting<E> extends IterableBase<E> {
  final List<E> _items;
  int lengthReads = 0;
  int lastReads = 0;

  _Counting(this._items);

  @override
  Iterator<E> get iterator => _items.iterator;

  @override
  int get length {
    lengthReads++;

    return _items.length;
  }

  @override
  E get last {
    lastReads++;

    return _items.last;
  }
}

/// A plain iterable that is neither a List nor a Set.
Iterable<int> _iterable() => [1, 2, 3, 4, 5].where((e) => true);

const _limit = LoggableConfig(collectionMaxCount: 3);
const _efficient = LoggableConfig(
  collectionMaxCount: 3,
  iterableEfficientLength: true,
);

void main() {
  tearDown(() {
    Loggable.defaultConfig = const LoggableConfig();
    Loggable.forceConfig = const LoggableConfig();
  });

  group('by default an Iterable is walked once', () {
    test('the string keeps the head and says nothing about the length', () {
      expect(Loggable.objectToString(_iterable()), '(₀:1, ₁:2, ₂:3, ₃:4, ₄:5)');
      expect(
        Loggable.objectToString(_iterable(), config: _limit),
        '(₀:1, ₁:2, ₂:3, …)',
      );
    });

    test('the JSON marks a trim instead of reporting a length', () {
      expect(
        Loggable.objectToJson(
          _iterable(),
          config: const LoggableJsonConfig(collectionMaxCount: 3),
        ),
        {
          ':k': 'iterable',
          ':v': [1, 2, 3],
          ':trim': true,
        },
      );
    });

    test('neither the length nor the last element is read', () {
      final items = _Counting([1, 2, 3, 4, 5]);

      Loggable.objectToString(items, config: _limit);

      expect(items.lengthReads, 0);
      expect(items.lastReads, 0);
    });
  });

  group('iterableEfficientLength opts into the richer rendering', () {
    test('the string reports the count and keeps the last element', () {
      expect(
        Loggable.objectToString(_iterable(), config: _efficient),
        '(₌₅ ₀:1, ₁:2, …, ₄:5)',
      );
    });

    test('the JSON reports the length and keeps the last element', () {
      expect(
        Loggable.objectToJson(
          Loggable.from(_iterable(), config: _efficient),
          config: const LoggableJsonConfig(collectionMaxCount: 3),
        ),
        {
          ':k': 'iterable',
          ':l': 5,
          ':v': [1, 2, 5],
        },
      );
    });

    test('the length is read, which is what the caller asserted', () {
      final items = _Counting([1, 2, 3, 4, 5]);

      Loggable.objectToString(items, config: _efficient);

      expect(items.lengthReads, greaterThan(0));
    });

    test('an unlimited render still reports the count', () {
      expect(
        Loggable.objectToString(
          _iterable(),
          config: const LoggableConfig(iterableEfficientLength: true),
        ),
        '(₌₅ ₀:1, ₁:2, ₂:3, ₃:4, ₄:5)',
      );
    });
  });

  group('the flag takes the config layers', () {
    test('the application can turn it on for everything', () {
      Loggable.defaultConfig =
          const LoggableConfig(iterableEfficientLength: true);

      expect(
        Loggable.objectToString(_iterable(), config: _limit),
        '(₌₅ ₀:1, ₁:2, …, ₄:5)',
      );
    });

    test('a call site can turn it off again', () {
      Loggable.defaultConfig =
          const LoggableConfig(iterableEfficientLength: true);

      expect(
        Loggable.objectToString(
          _iterable(),
          config: const LoggableConfig(
            collectionMaxCount: 3,
            iterableEfficientLength: false,
          ),
        ),
        '(₀:1, ₁:2, ₂:3, …)',
      );
    });

    test('a forced policy is not lifted by the call site', () {
      Loggable.forceConfig =
          const LoggableConfig(iterableEfficientLength: false);

      expect(
        Loggable.objectToString(_iterable(), config: _efficient),
        '(₀:1, ₁:2, ₂:3, …)',
      );
    });
  });

  group('List and Set are untouched', () {
    test('a List always had the count and the last element', () {
      expect(
        Loggable.objectToString([1, 2, 3, 4, 5], config: _limit),
        '[₌₅ ₀:1, ₁:2, …, ₄:5]',
      );
    });

    test('a Set is the same with its own brackets', () {
      expect(
        Loggable.objectToString({1, 2, 3, 4, 5}, config: _limit),
        '{₌₅ ₀:1, ₁:2, …, ₄:5}',
      );
    });
  });
}
