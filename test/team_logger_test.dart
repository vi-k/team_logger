import 'dart:collection';
import 'dart:convert';

import 'package:ansi_escape_codes/extensions.dart';
import 'package:team_logger/team_logger.dart';
import 'package:test/test.dart';

const _emptyList = <String>[];

final class _LengthCountingIterable<E> extends IterableBase<E> {
  final List<E> _items;
  int lengthReads = 0;
  int lastReads = 0;

  _LengthCountingIterable(this._items);

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

final class _Point with Loggable {
  final double lat;
  final double lon;

  _Point(this.lat, this.lon);

  @override
  void collectLoggableData(LoggableData data) {
    data
      ..prop('lat', lat, units: '°')
      ..prop('lon', lon)
      ..hidden('secret', 'not for logs');
  }
}

void main() {
  group('Loggable', () {
    /// Отличается от `efficientLengthIterableToJson` тем, что
    /// несокращаемый список, у которого нет units, передаётся прямо, без
    /// преобразования в Map.
    group('listToJson', () {
      void expectNoLimit(List<String> items, Object expected, {String? units}) {
        expect(
          Loggable.listToJson(
            items,
            config: LoggableJsonConfig(units: units),
          ),
          expected,
          reason: 'collectionMaxCount=null, units=$units',
        );
      }

      void expectLimited(
        List<String> items,
        int limit,
        Object expected, {
        String? units,
      }) {
        expect(
          Loggable.listToJson(
            items,
            config: LoggableJsonConfig(
              collectionMaxCount: limit,
              units: units,
            ),
          ),
          expected,
          reason: 'collectionMaxCount=$limit, units=$units',
        );
      }

      void expectFull(List<String> items, Object expected, {String? units}) {
        expectLimited(items, items.length, expected, units: units);
        expectLimited(items, items.length + 1, expected, units: units);
      }

      test('with 0 items', () {
        const items = _emptyList;
        expectNoLimit(items, _emptyList);
        expectNoLimit(
          items,
          units: 'm',
          {':k': 'list', ':v': _emptyList, ':u': 'm'},
        );
        expectFull(items, _emptyList);
        expectFull(items, units: 'm', {
          ':k': 'list',
          ':v': _emptyList,
          ':u': 'm',
        });
      });

      test('with 1 item', () {
        const items = ['a'];
        expectNoLimit(items, ['a']);
        expectNoLimit(items, units: 'm', {
          ':k': 'list',
          ':v': ['a'],
          ':u': 'm',
        });
        expectLimited(items, 0, {
          ':k': 'list',
          ':l': 1,
          ':v': _emptyList,
        });
        expectLimited(items, 0, units: 'm', {
          ':k': 'list',
          ':l': 1,
          ':v': _emptyList,
          ':u': 'm',
        });
        expectFull(items, ['a']);
        expectFull(items, units: 'm', {
          ':k': 'list',
          ':v': ['a'],
          ':u': 'm',
        });
      });

      test('with 2 items', () {
        const items = ['a', 'b'];
        expectNoLimit(items, ['a', 'b']);
        expectNoLimit(items, units: 'm', {
          ':k': 'list',
          ':v': ['a', 'b'],
          ':u': 'm',
        });
        expectLimited(items, 0, {
          ':k': 'list',
          ':l': 2,
          ':v': _emptyList,
        });
        expectLimited(items, 0, units: 'm', {
          ':k': 'list',
          ':l': 2,
          ':v': _emptyList,
          ':u': 'm',
        });
        expectLimited(items, 1, {
          ':k': 'list',
          ':l': 2,
          ':v': ['a'],
        });
        expectLimited(items, 1, units: 'm', {
          ':k': 'list',
          ':l': 2,
          ':v': ['a'],
          ':u': 'm',
        });
        expectFull(items, ['a', 'b']);
        expectFull(items, units: 'm', {
          ':k': 'list',
          ':v': ['a', 'b'],
          ':u': 'm',
        });
      });

      test('with 3 items', () {
        const items = ['a', 'b', 'c'];
        expectNoLimit(items, ['a', 'b', 'c']);
        expectNoLimit(items, units: 'm', {
          ':k': 'list',
          ':v': ['a', 'b', 'c'],
          ':u': 'm',
        });
        expectLimited(items, 0, {
          ':k': 'list',
          ':l': 3,
          ':v': _emptyList,
        });
        expectLimited(items, 0, units: 'm', {
          ':k': 'list',
          ':l': 3,
          ':v': _emptyList,
          ':u': 'm',
        });
        expectLimited(items, 1, {
          ':k': 'list',
          ':l': 3,
          ':v': ['a'],
        });
        expectLimited(items, 1, units: 'm', {
          ':k': 'list',
          ':l': 3,
          ':v': ['a'],
          ':u': 'm',
        });
        expectLimited(items, 2, {
          ':k': 'list',
          ':l': 3,
          ':v': ['a', 'c'],
        });
        expectLimited(items, 2, units: 'm', {
          ':k': 'list',
          ':l': 3,
          ':v': ['a', 'c'],
          ':u': 'm',
        });
        expectFull(items, ['a', 'b', 'c']);
        expectFull(items, units: 'm', {
          ':k': 'list',
          ':v': ['a', 'b', 'c'],
          ':u': 'm',
        });
      });

      test('with 4 items', () {
        const items = ['a', 'b', 'c', 'd'];
        expectNoLimit(items, ['a', 'b', 'c', 'd']);
        expectNoLimit(items, units: 'm', {
          ':k': 'list',
          ':v': ['a', 'b', 'c', 'd'],
          ':u': 'm',
        });
        expectLimited(items, 0, {
          ':k': 'list',
          ':l': 4,
          ':v': _emptyList,
        });
        expectLimited(items, 0, units: 'm', {
          ':k': 'list',
          ':l': 4,
          ':v': _emptyList,
          ':u': 'm',
        });
        expectLimited(items, 1, {
          ':k': 'list',
          ':l': 4,
          ':v': ['a'],
        });
        expectLimited(items, 1, units: 'm', {
          ':k': 'list',
          ':l': 4,
          ':v': ['a'],
          ':u': 'm',
        });
        expectLimited(items, 2, {
          ':k': 'list',
          ':l': 4,
          ':v': ['a', 'd'],
        });
        expectLimited(items, 2, units: 'm', {
          ':k': 'list',
          ':l': 4,
          ':v': ['a', 'd'],
          ':u': 'm',
        });
        expectLimited(items, 3, {
          ':k': 'list',
          ':l': 4,
          ':v': ['a', 'b', 'd'],
        });
        expectLimited(items, 3, units: 'm', {
          ':k': 'list',
          ':l': 4,
          ':v': ['a', 'b', 'd'],
          ':u': 'm',
        });
        expectFull(items, ['a', 'b', 'c', 'd']);
        expectFull(items, units: 'm', {
          ':k': 'list',
          ':v': ['a', 'b', 'c', 'd'],
          ':u': 'm',
        });
      });
    });

    group('efficientLengthIterableToJson', () {
      void expectNoLimit(List<String> items, Object expected, {String? units}) {
        expect(
          Loggable.efficientLengthIterableToJson(
            items,
            config: LoggableJsonConfig(units: units),
          ),
          expected,
          reason: 'collectionMaxCount=null, units=$units',
        );
      }

      void expectLimited(
        List<String> items,
        int limit,
        Object expected, {
        String? units,
      }) {
        expect(
          Loggable.efficientLengthIterableToJson(
            items,
            config: LoggableJsonConfig(
              collectionMaxCount: limit,
              units: units,
            ),
          ),
          expected,
          reason: 'collectionMaxCount=$limit, units=$units',
        );
      }

      void expectFull(List<String> items, Object expected, {String? units}) {
        expectLimited(items, items.length, expected, units: units);
        expectLimited(items, items.length + 1, expected, units: units);
      }

      test('with 0 items', () {
        const items = _emptyList;
        expectNoLimit(items, {':k': 'iterable', ':v': _emptyList});
        expectNoLimit(
          items,
          units: 'm',
          {':k': 'iterable', ':v': _emptyList, ':u': 'm'},
        );
        expectFull(items, {':k': 'iterable', ':v': _emptyList});
        expectFull(
          items,
          units: 'm',
          {':k': 'iterable', ':v': _emptyList, ':u': 'm'},
        );
      });

      test('with 1 item', () {
        const items = ['a'];
        expectNoLimit(items, {
          ':k': 'iterable',
          ':v': ['a'],
        });
        expectNoLimit(items, units: 'm', {
          ':k': 'iterable',
          ':v': ['a'],
          ':u': 'm',
        });
        expectLimited(items, 0, {
          ':k': 'iterable',
          ':l': 1,
          ':v': _emptyList,
        });
        expectLimited(items, 0, units: 'm', {
          ':k': 'iterable',
          ':l': 1,
          ':v': _emptyList,
          ':u': 'm',
        });
        expectFull(items, {
          ':k': 'iterable',
          ':v': ['a'],
        });
        expectFull(items, units: 'm', {
          ':k': 'iterable',
          ':v': ['a'],
          ':u': 'm',
        });
      });

      test('with 2 items', () {
        const items = ['a', 'b'];
        expectNoLimit(items, {
          ':k': 'iterable',
          ':v': ['a', 'b'],
        });
        expectNoLimit(items, units: 'm', {
          ':k': 'iterable',
          ':v': ['a', 'b'],
          ':u': 'm',
        });
        expectLimited(items, 0, {
          ':k': 'iterable',
          ':l': 2,
          ':v': _emptyList,
        });
        expectLimited(items, 0, units: 'm', {
          ':k': 'iterable',
          ':l': 2,
          ':v': _emptyList,
          ':u': 'm',
        });
        expectLimited(items, 1, {
          ':k': 'iterable',
          ':l': 2,
          ':v': ['a'],
        });
        expectLimited(items, 1, units: 'm', {
          ':k': 'iterable',
          ':l': 2,
          ':v': ['a'],
          ':u': 'm',
        });
        expectFull(items, {
          ':k': 'iterable',
          ':v': ['a', 'b'],
        });
        expectFull(items, units: 'm', {
          ':k': 'iterable',
          ':v': ['a', 'b'],
          ':u': 'm',
        });
      });

      test('with 3 items', () {
        const items = ['a', 'b', 'c'];
        expectNoLimit(items, {
          ':k': 'iterable',
          ':v': ['a', 'b', 'c'],
        });
        expectNoLimit(items, units: 'm', {
          ':k': 'iterable',
          ':v': ['a', 'b', 'c'],
          ':u': 'm',
        });
        expectLimited(items, 0, {
          ':k': 'iterable',
          ':l': 3,
          ':v': _emptyList,
        });
        expectLimited(items, 0, units: 'm', {
          ':k': 'iterable',
          ':l': 3,
          ':v': _emptyList,
          ':u': 'm',
        });
        expectLimited(items, 1, {
          ':k': 'iterable',
          ':l': 3,
          ':v': ['a'],
        });
        expectLimited(items, 1, units: 'm', {
          ':k': 'iterable',
          ':l': 3,
          ':v': ['a'],
          ':u': 'm',
        });
        expectLimited(items, 2, {
          ':k': 'iterable',
          ':l': 3,
          ':v': ['a', 'c'],
        });
        expectLimited(items, 2, units: 'm', {
          ':k': 'iterable',
          ':l': 3,
          ':v': ['a', 'c'],
          ':u': 'm',
        });
        expectFull(items, {
          ':k': 'iterable',
          ':v': ['a', 'b', 'c'],
        });
        expectFull(items, units: 'm', {
          ':k': 'iterable',
          ':v': ['a', 'b', 'c'],
          ':u': 'm',
        });
      });

      test('with 4 items', () {
        const items = ['a', 'b', 'c', 'd'];
        expectNoLimit(items, {
          ':k': 'iterable',
          ':v': ['a', 'b', 'c', 'd'],
        });
        expectNoLimit(items, units: 'm', {
          ':k': 'iterable',
          ':v': ['a', 'b', 'c', 'd'],
          ':u': 'm',
        });
        expectLimited(items, 0, {
          ':k': 'iterable',
          ':l': 4,
          ':v': _emptyList,
        });
        expectLimited(items, 0, units: 'm', {
          ':k': 'iterable',
          ':l': 4,
          ':v': _emptyList,
          ':u': 'm',
        });
        expectLimited(items, 1, {
          ':k': 'iterable',
          ':l': 4,
          ':v': ['a'],
        });
        expectLimited(items, 1, units: 'm', {
          ':k': 'iterable',
          ':l': 4,
          ':v': ['a'],
          ':u': 'm',
        });
        expectLimited(items, 2, {
          ':k': 'iterable',
          ':l': 4,
          ':v': ['a', 'd'],
        });
        expectLimited(items, 2, units: 'm', {
          ':k': 'iterable',
          ':l': 4,
          ':v': ['a', 'd'],
          ':u': 'm',
        });
        expectLimited(items, 3, {
          ':k': 'iterable',
          ':l': 4,
          ':v': ['a', 'b', 'd'],
        });
        expectLimited(items, 3, units: 'm', {
          ':k': 'iterable',
          ':l': 4,
          ':v': ['a', 'b', 'd'],
          ':u': 'm',
        });
        expectFull(items, {
          ':k': 'iterable',
          ':v': ['a', 'b', 'c', 'd'],
        });
        expectFull(items, units: 'm', {
          ':k': 'iterable',
          ':v': ['a', 'b', 'c', 'd'],
          ':u': 'm',
        });
      });
    });

    group('iterableToJson', () {
      void expectNoLimit(List<String> items, Object expected, {String? units}) {
        expect(
          Loggable.iterableToJson(
            items,
            config: LoggableJsonConfig(units: units),
          ),
          expected,
          reason: 'collectionMaxCount=null, units=$units',
        );
      }

      void expectLimited(
        List<String> items,
        int limit,
        Object expected, {
        String? units,
      }) {
        expect(
          Loggable.iterableToJson(
            items,
            config: LoggableJsonConfig(
              collectionMaxCount: limit,
              units: units,
            ),
          ),
          expected,
          reason: 'collectionMaxCount=$limit, units=$units',
        );
      }

      void expectFull(List<String> items, Object expected, {String? units}) {
        expectLimited(items, items.length, expected, units: units);
        expectLimited(items, items.length + 1, expected, units: units);
      }

      test('with 0 items', () {
        const items = _emptyList;
        expectNoLimit(items, {':k': 'iterable', ':v': _emptyList});
        expectNoLimit(
          items,
          units: 'm',
          {':k': 'iterable', ':v': _emptyList, ':u': 'm'},
        );
        expectFull(items, {':k': 'iterable', ':v': _emptyList});
        expectFull(
          items,
          units: 'm',
          {':k': 'iterable', ':v': _emptyList, ':u': 'm'},
        );
      });

      test('with 1 item', () {
        const items = ['a'];
        expectNoLimit(items, {
          ':k': 'iterable',
          ':v': ['a'],
        });
        expectNoLimit(items, units: 'm', {
          ':k': 'iterable',
          ':v': ['a'],
          ':u': 'm',
        });
        expectLimited(items, 0, {
          ':k': 'iterable',
          ':v': _emptyList,
          ':trim': true,
        });
        expectLimited(items, 0, units: 'm', {
          ':k': 'iterable',
          ':v': _emptyList,
          ':trim': true,
          ':u': 'm',
        });
        expectFull(items, {
          ':k': 'iterable',
          ':v': ['a'],
        });
        expectFull(items, units: 'm', {
          ':k': 'iterable',
          ':v': ['a'],
          ':u': 'm',
        });
      });

      test('with 2 items', () {
        const items = ['a', 'b'];
        expectNoLimit(items, {
          ':k': 'iterable',
          ':v': ['a', 'b'],
        });
        expectNoLimit(items, units: 'm', {
          ':k': 'iterable',
          ':v': ['a', 'b'],
          ':u': 'm',
        });
        expectLimited(items, 0, {
          ':k': 'iterable',
          ':v': _emptyList,
          ':trim': true,
        });
        expectLimited(items, 0, units: 'm', {
          ':k': 'iterable',
          ':v': _emptyList,
          ':trim': true,
          ':u': 'm',
        });
        expectLimited(items, 1, {
          ':k': 'iterable',
          ':v': ['a'],
          ':trim': true,
        });
        expectLimited(items, 1, units: 'm', {
          ':k': 'iterable',
          ':v': ['a'],
          ':trim': true,
          ':u': 'm',
        });
        expectFull(items, {
          ':k': 'iterable',
          ':v': ['a', 'b'],
        });
        expectFull(items, units: 'm', {
          ':k': 'iterable',
          ':v': ['a', 'b'],
          ':u': 'm',
        });
      });

      test('with 3 items', () {
        const items = ['a', 'b', 'c'];
        expectNoLimit(items, {
          ':k': 'iterable',
          ':v': ['a', 'b', 'c'],
        });
        expectNoLimit(items, units: 'm', {
          ':k': 'iterable',
          ':v': ['a', 'b', 'c'],
          ':u': 'm',
        });
        expectLimited(items, 0, {
          ':k': 'iterable',
          ':v': _emptyList,
          ':trim': true,
        });
        expectLimited(items, 0, units: 'm', {
          ':k': 'iterable',
          ':v': _emptyList,
          ':trim': true,
          ':u': 'm',
        });
        expectLimited(items, 1, {
          ':k': 'iterable',
          ':v': ['a'],
          ':trim': true,
        });
        expectLimited(items, 1, units: 'm', {
          ':k': 'iterable',
          ':v': ['a'],
          ':trim': true,
          ':u': 'm',
        });
        expectLimited(items, 2, {
          ':k': 'iterable',
          ':v': ['a', 'b'],
          ':trim': true,
        });
        expectLimited(items, 2, units: 'm', {
          ':k': 'iterable',
          ':v': ['a', 'b'],
          ':trim': true,
          ':u': 'm',
        });
        expectFull(items, {
          ':k': 'iterable',
          ':v': ['a', 'b', 'c'],
        });
        expectFull(items, units: 'm', {
          ':k': 'iterable',
          ':v': ['a', 'b', 'c'],
          ':u': 'm',
        });
      });

      test('with 4 items', () {
        const items = ['a', 'b', 'c', 'd'];
        expectNoLimit(items, {
          ':k': 'iterable',
          ':v': ['a', 'b', 'c', 'd'],
        });
        expectNoLimit(items, units: 'm', {
          ':k': 'iterable',
          ':v': ['a', 'b', 'c', 'd'],
          ':u': 'm',
        });
        expectLimited(items, 0, {
          ':k': 'iterable',
          ':v': _emptyList,
          ':trim': true,
        });
        expectLimited(items, 0, units: 'm', {
          ':k': 'iterable',
          ':v': _emptyList,
          ':trim': true,
          ':u': 'm',
        });
        expectLimited(items, 1, {
          ':k': 'iterable',
          ':v': ['a'],
          ':trim': true,
        });
        expectLimited(items, 1, units: 'm', {
          ':k': 'iterable',
          ':v': ['a'],
          ':trim': true,
          ':u': 'm',
        });
        expectLimited(items, 2, {
          ':k': 'iterable',
          ':v': ['a', 'b'],
          ':trim': true,
        });
        expectLimited(items, 2, units: 'm', {
          ':k': 'iterable',
          ':v': ['a', 'b'],
          ':trim': true,
          ':u': 'm',
        });
        expectLimited(items, 3, {
          ':k': 'iterable',
          ':v': ['a', 'b', 'c'],
          ':trim': true,
        });
        expectLimited(items, 3, units: 'm', {
          ':k': 'iterable',
          ':v': ['a', 'b', 'c'],
          ':trim': true,
          ':u': 'm',
        });
        expectFull(items, {
          ':k': 'iterable',
          ':v': ['a', 'b', 'c', 'd'],
        });
        expectFull(items, units: 'm', {
          ':k': 'iterable',
          ':v': ['a', 'b', 'c', 'd'],
          ':u': 'm',
        });
      });
    });

    group('objectToJson', () {
      group('with null', () {
        test('without units', () {
          expect(Loggable.objectToJson(null), null);
        });

        test('ignores units', () {
          const config = LoggableJsonConfig(units: 'm');
          expect(Loggable.objectToJson(null, config: config), null);
        });
      });

      group('with bool', () {
        test('without units', () {
          expect(Loggable.objectToJson(false), false);
          expect(Loggable.objectToJson(true), true);
        });

        test('ignores units', () {
          const config = LoggableJsonConfig(units: 'm');
          expect(
            Loggable.objectToJson(false, config: config),
            false,
          );
          expect(
            Loggable.objectToJson(true, config: config),
            true,
          );
        });
      });

      group('with int', () {
        test('without units', () {
          expect(Loggable.objectToJson(0), 0);
          expect(Loggable.objectToJson(42), 42);
          expect(Loggable.objectToJson(-42), -42);
        });

        test('with units', () {
          const config = LoggableJsonConfig(units: 'm');
          expect(
            Loggable.objectToJson(0, config: config),
            {':v': 0, ':u': 'm'},
          );
          expect(
            Loggable.objectToJson(42, config: config),
            {':v': 42, ':u': 'm'},
          );
          expect(
            Loggable.objectToJson(-42, config: config),
            {':v': -42, ':u': 'm'},
          );
        });
      });

      group('with double', () {
        test('without units', () {
          expect(Loggable.objectToJson(0.0), 0.0);
          expect(Loggable.objectToJson(-0.0), -0.0);
          expect(Loggable.objectToJson(12345678.9), 12345678.9);
          expect(
            Loggable.objectToJson(double.nan),
            {':k': 'double', ':v': 'nan'},
          );
          expect(
            Loggable.objectToJson(double.infinity),
            {':k': 'double', ':v': 'inf'},
          );
          expect(
            Loggable.objectToJson(-double.infinity),
            {':k': 'double', ':v': '-inf'},
          );
          expect(
            Loggable.objectToJson(double.negativeInfinity),
            {':k': 'double', ':v': '-inf'},
          );
        });

        test('with units', () {
          const config = LoggableJsonConfig(units: 'm');
          expect(
            Loggable.objectToJson(0.0, config: config),
            {':v': 0.0, ':u': 'm'},
          );
          expect(
            Loggable.objectToJson(-0.0, config: config),
            {':v': -0.0, ':u': 'm'},
          );
          expect(
            Loggable.objectToJson(12345678.9, config: config),
            {':v': 12345678.9, ':u': 'm'},
          );
          // Units — визуальная сущность: для nan/inf не показываются.
          expect(
            Loggable.objectToJson(double.nan, config: config),
            {':k': 'double', ':v': 'nan'},
          );
          expect(
            Loggable.objectToJson(double.infinity, config: config),
            {':k': 'double', ':v': 'inf'},
          );
          expect(
            Loggable.objectToJson(-double.infinity, config: config),
            {':k': 'double', ':v': '-inf'},
          );
          expect(
            Loggable.objectToJson(double.negativeInfinity, config: config),
            {':k': 'double', ':v': '-inf'},
          );
        });
      });

      group('with String', () {
        test('without units', () {
          expect(Loggable.objectToJson(''), '');
          expect(Loggable.objectToJson('abc'), 'abc');
        });

        test('ignores units', () {
          const config = LoggableJsonConfig(units: 'm');
          expect(
            Loggable.objectToJson('abc', config: config),
            'abc',
          );
        });
      });

      group('with Enum', () {
        test('without units', () {
          expect(
            Loggable.objectToJson(LogTextAlign.left),
            {':c': 'LogTextAlign', ':v': 'left'},
          );
        });

        test('ignores units', () {
          const config = LoggableJsonConfig(units: 'm');
          expect(
            Loggable.objectToJson(LogTextAlign.left, config: config),
            {':c': 'LogTextAlign', ':v': 'left'},
          );
        });
      });

      group('with List', () {
        test('passes a plain list through', () {
          expect(
            Loggable.objectToJson([1, 'a', true, null]),
            [1, 'a', true, null],
          );
        });

        test('converts items', () {
          expect(Loggable.objectToJson([double.nan, LogTextAlign.left]), [
            {':k': 'double', ':v': 'nan'},
            {':c': 'LogTextAlign', ':v': 'left'},
          ]);
        });

        test('does not pass units to items', () {
          const config = LoggableJsonConfig(units: 'm');
          expect(Loggable.objectToJson([1, 2], config: config), {
            ':k': 'list',
            ':v': [1, 2],
            ':u': 'm',
          });
        });

        test('trims to collectionMaxCount keeping the last item', () {
          const config = LoggableJsonConfig(collectionMaxCount: 2);
          expect(Loggable.objectToJson([1, 2, 3, 4], config: config), {
            ':k': 'list',
            ':l': 4,
            ':v': [1, 4],
          });
        });

        test('applies collectionMaxCount recursively', () {
          const config = LoggableJsonConfig(collectionMaxCount: 2);
          expect(
            Loggable.objectToJson(
              [
                [1, 2, 3],
                [4, 5, 6],
              ],
              config: config,
            ),
            [
              {
                ':k': 'list',
                ':l': 3,
                ':v': [1, 3],
              },
              {
                ':k': 'list',
                ':l': 3,
                ':v': [4, 6],
              },
            ],
          );
        });
      });

      group('with Set', () {
        test('without units', () {
          expect(Loggable.objectToJson({1, 2, 3}), {
            ':k': 'set',
            ':v': [1, 2, 3],
          });
        });

        test('with units', () {
          const config = LoggableJsonConfig(units: 'm');
          expect(Loggable.objectToJson({1, 2, 3}, config: config), {
            ':k': 'set',
            ':v': [1, 2, 3],
            ':u': 'm',
          });
        });

        test('trims to collectionMaxCount keeping the last item', () {
          const config = LoggableJsonConfig(collectionMaxCount: 2);
          expect(Loggable.objectToJson({1, 2, 3}, config: config), {
            ':k': 'set',
            ':l': 3,
            ':v': [1, 3],
          });
        });
      });

      group('with Iterable', () {
        test('without limits', () {
          expect(Loggable.objectToJson(Iterable<int>.generate(3)), {
            ':k': 'iterable',
            ':v': [0, 1, 2],
          });
        });

        test('trims to collectionMaxCount keeping the first items', () {
          const config = LoggableJsonConfig(collectionMaxCount: 2);
          expect(
            Loggable.objectToJson(Iterable<int>.generate(3), config: config),
            {
              ':k': 'iterable',
              ':v': [0, 1],
              ':trim': true,
            },
          );
        });

        test('does not read the length or last item', () {
          final items = _LengthCountingIterable(['a', 'b', 'c']);

          expect(
            Loggable.objectToJson(
              items,
              config: const LoggableJsonConfig(collectionMaxCount: 2),
            ),
            {
              ':k': 'iterable',
              ':v': ['a', 'b'],
              ':trim': true,
            },
          );
          expect(items.lengthReads, 0);
          expect(items.lastReads, 0);
        });
      });

      group('with Map', () {
        test('converts values and keeps string keys', () {
          expect(
            Loggable.objectToJson({
              'a': 1,
              'b': [1, 2],
              'c': double.nan,
            }),
            {
              'a': 1,
              'b': [1, 2],
              'c': {':k': 'double', ':v': 'nan'},
            },
          );
        });

        test('converts non-string keys with toString', () {
          expect(
            Loggable.objectToJson({1: 'a', null: 'b', LogTextAlign.left: 'c'}),
            {'1': 'a', 'null': 'b', 'LogTextAlign.left': 'c'},
          );
        });

        test('rejects distinct keys with the same JSON representation', () {
          // Mutation: assigning without a collision check silently keeps only
          // the value of the later key.
          expect(
            () => Loggable.objectToJson(<Object?, Object?>{
              1: 'int',
              '1': 'string',
            }),
            throwsArgumentError,
          );
        });

        test('rejects null and string null keys together', () {
          // Mutation: treating null as the string "null" without a collision
          // check silently keeps only the value of the later key.
          expect(
            () => Loggable.objectToJson(<Object?, Object?>{
              null: 'null value',
              'null': 'string value',
            }),
            throwsArgumentError,
          );
        });

        test('rejects a collision when the first value is null', () {
          // Mutation: checking result[jsonKey] instead of containsKey misses
          // an existing key whose converted value is null.
          expect(
            () => Loggable.objectToJson(<Object?, Object?>{
              1: null,
              '1': 'string',
            }),
            throwsArgumentError,
          );
        });

        test('allows a colliding key when sanitizer drops its entry', () {
          // Mutation: checking collisions before Sanitize.drop would reject a
          // map whose emitted JSON representation is unambiguous.
          addTearDown(() => Loggable.sanitizer = null);
          Loggable.sanitizer =
              (ctx) => ctx.value == 'discard' ? Sanitize.drop : ctx.value;

          expect(
            Loggable.objectToJson(<Object?, Object?>{
              1: 'discard',
              '1': 'kept',
            }),
            {'1': 'kept'},
          );
        });

        test('does not pass units to values', () {
          const config = LoggableJsonConfig(units: 'm');
          expect(Loggable.objectToJson({'a': 1}, config: config), {
            'a': 1,
            ':u': 'm',
          });
        });

        test('applies collectionMaxCount to values', () {
          const config = LoggableJsonConfig(collectionMaxCount: 1);
          expect(
            Loggable.objectToJson(
              {
                'xs': [1, 2],
              },
              config: config,
            ),
            {
              'xs': {
                ':k': 'list',
                ':l': 2,
                ':v': [1],
              },
            },
          );
        });
      });

      group('with Loggable', () {
        test('serializes declared props and skips hidden ones', () {
          expect(
            Loggable.objectToJson(_Point(51.5, -0.125)),
            {
              ':c': '_Point',
              ':p': {
                'lat': {':v': 51.5, ':u': '°'},
                'lon': -0.125,
              },
            },
          );
        });

        test('applies units to the object itself, not to each prop', () {
          const config = LoggableJsonConfig(units: 'm');
          expect(
            Loggable.objectToJson(_Point(51.5, -0.125), config: config),
            {
              ':c': '_Point',
              ':p': {
                'lat': {':v': 51.5, ':u': '°'},
                'lon': -0.125,
              },
              ':u': 'm',
            },
          );
        });

        test('unwraps Loggable.from', () {
          expect(
            Loggable.objectToJson(Loggable.from(42)),
            42,
          );
        });

        test('applies the config of Loggable.from', () {
          final wrapped = Loggable.from(
            42,
            config: const LoggableConfig(units: 'm'),
          );
          expect(
            Loggable.objectToJson(wrapped),
            {':v': 42, ':u': 'm'},
          );
        });
      });

      group('with LoggableData', () {
        test('with Loggable.builder', () {
          final obj = Loggable.builder(0, name: 'Point')
            ..prop('x', 1)
            ..prop('y', 2);
          expect(
            Loggable.objectToJson(obj),
            {
              ':c': 'Point',
              ':p': {'x': 1, 'y': 2},
            },
          );
        });

        test('without name', () {
          final obj = Loggable.builder(0, name: 'Point', showName: false)
            ..prop('x', 1);
          expect(
            Loggable.objectToJson(obj),
            {
              ':p': {'x': 1},
            },
          );
        });

        test('without brackets', () {
          final obj = Loggable.builder(0, name: 'Point', showBrackets: false)
            ..prop('x', 1);
          expect(
            Loggable.objectToJson(obj),
            {
              ':c': 'Point',
              ':p': {'x': 1},
              ':brackets': false,
            },
          );
        });

        test('with unnamed props', () {
          final obj = Loggable.builder(0, name: 'Point')
            ..prop('x', 1)
            ..prop('y', 2, showName: false);
          expect(
            Loggable.objectToJson(obj),
            {
              ':c': 'Point',
              ':p': [
                {'x': 1},
                2,
              ],
            },
          );
        });

        test('with units', () {
          const config = LoggableJsonConfig(units: 'm');
          final obj = Loggable.builder(0, name: 'Point')..prop('x', 1);
          expect(
            Loggable.objectToJson(obj, config: config),
            {
              ':c': 'Point',
              ':p': {'x': 1},
              ':u': 'm',
            },
          );
        });

        test('wraps prop views with prop units', () {
          final obj = Loggable.builder(0, name: 'Point')
            ..round('pi', 3.14159, precision: 2, units: 'rad');
          expect(
            Loggable.objectToJson(obj),
            {
              ':c': 'Point',
              ':p': {
                'pi': {':v': 3.14, ':u': 'rad'},
              },
            },
          );
        });

        test('serializes prop views as strings', () {
          final obj = Loggable.builder(0, name: 'Point')
            ..round('pi', 3.14159, precision: 2)
            ..prop('speed', 10, view: const LoggableView(36, units: 'km/h'));
          expect(
            Loggable.objectToJson(obj),
            {
              ':c': 'Point',
              ':p': {
                'pi': 3.14,
                'speed': {':v': 36, ':u': 'km/h'},
              },
            },
          );
        });

        test('with Loggable.mapBuilder', () {
          final obj = Loggable.mapBuilder()
            ..prop('a', 1, units: 'kg')
            ..prop('b', 2);
          expect(
            Loggable.objectToJson(obj),
            {
              'a': {':v': 1, ':u': 'kg'},
              'b': 2,
            },
          );
        });
      });

      group('with LoggableMultiData', () {
        test('flattens sections', () {
          final multi = LoggableMultiData({'': 'connected', 'attempts': 3});
          expect(
            Loggable.objectToJson(multi),
            {':k': 'multi', '': 'connected', 'attempts': 3},
          );
        });

        test('applies its own config to values', () {
          final multi = LoggableMultiData(
            {
              'xs': [1, 2, 3],
            },
            config: const LoggableConfig(collectionMaxCount: 2),
          );
          expect(
            Loggable.objectToJson(multi),
            {
              ':k': 'multi',
              'xs': {
                ':k': 'list',
                ':l': 3,
                ':v': [1, 3],
              },
            },
          );
        });
      });

      group('with DateTime', () {
        test('without units', () {
          expect(
            Loggable.objectToJson(DateTime.utc(2026, 1, 2, 3, 4, 5)),
            {':k': 'datetime', ':v': '2026-01-02T03:04:05.000Z'},
          );
        });

        test('with units', () {
          const config = LoggableJsonConfig(units: 'm');
          expect(
            Loggable.objectToJson(
              DateTime.utc(2026, 1, 2, 3, 4, 5),
              config: config,
            ),
            {':k': 'datetime', ':v': '2026-01-02T03:04:05.000Z'},
          );
        });
      });

      group('with Duration', () {
        test('without units', () {
          expect(
            Loggable.objectToJson(const Duration(minutes: 1, seconds: 30)),
            {':k': 'duration', ':v': '0:01:30.000000'},
          );
        });

        test('with units', () {
          const config = LoggableJsonConfig(units: 'm');
          expect(
            Loggable.objectToJson(
              const Duration(minutes: 1, seconds: 30),
              config: config,
            ),
            {':k': 'duration', ':v': '0:01:30.000000'},
          );
        });
      });

      group('with unsupported types', () {
        test('falls back to toString', () {
          expect(
            Loggable.objectToJson(Future<void>.value()),
            {':view': "Instance of 'Future<void>'"},
          );
        });

        test('ignores units', () {
          const config = LoggableJsonConfig(units: 'm');
          expect(
            Loggable.objectToJson(Future<void>.value(), config: config),
            {':view': "Instance of 'Future<void>'"},
          );
        });
      });

      test('produces a structure that jsonEncode can serialize', () {
        final json = Loggable.objectToJson({
          'point': _Point(51.5, -0.125),
          'align': LogTextAlign.left,
          'nan': double.nan,
          'ids': {1, 2, 3},
          'seq': Iterable<int>.generate(3),
          'when': DateTime.utc(2026),
        });

        expect(jsonDecode(jsonEncode(json)), json);
      });
    });

    group('efficientLengthIterableToString', () {
      test('reads the collection length once', () {
        final items = _LengthCountingIterable(['a', 'b', 'c']);

        expect(
          Loggable.efficientLengthIterableToString(
            items,
            config: const LoggableConfig(stringInQuotes: false),
          ),
          '(₌₃ ₀:a, ₁:b, ₂:c)',
        );
        expect(items.lengthReads, 1);
      });

      test('does not read the length when it is not needed', () {
        final items = _LengthCountingIterable(['a', 'b', 'c']);

        expect(
          Loggable.efficientLengthIterableToString(
            items,
            config: const LoggableConfig(
              collectionShowCount: false,
              stringInQuotes: false,
            ),
          ),
          '(₀:a, ₁:b, ₂:c)',
        );
        expect(items.lengthReads, 0);
      });

      test('does not reserve space for a hidden collection count', () {
        expect(
          Loggable.efficientLengthIterableToString(
            ['a', 'b', 'c'],
            config: const LoggableConfig(
              collectionMaxStringLength: 6,
              collectionShowCount: false,
              collectionShowIndexes: false,
              stringInQuotes: false,
            ),
          ),
          '(a, …)',
        );
      });

      test('does not include ANSI escape codes in the length limit', () {
        final result = Loggable.efficientLengthIterableToString(
          ['aa', 'bb', 'cc'],
          theme: LogMainTheme.defaultActiveTheme.verbose,
          config: const LoggableConfig(
            collectionMaxStringLength: 7,
            collectionShowCount: false,
            collectionShowIndexes: false,
            stringInQuotes: false,
          ),
        );

        expect(result, contains('\x1B['));
        expect(result.lengthWithoutEscapeCodes, 7);
        expect(result, contains('aa'));
        expect(result, contains('…'));
        expect(result, isNot(contains('bb')));
      });

      test('accounts for visible count and indexes in the ANSI length limit',
          () {
        final result = Loggable.efficientLengthIterableToString(
          ['aa', 'bb', 'cc'],
          theme: LogMainTheme.defaultActiveTheme.verbose,
          config: const LoggableConfig(
            collectionMaxStringLength: 12,
            stringInQuotes: false,
          ),
        );

        expect(result, contains('\x1B['));
        expect(result.lengthWithoutEscapeCodes, 12);
        expect(result, contains('₌₃'));
        expect(result, contains('₀:'));
        expect(result, contains('aa'));
        expect(result, contains('…'));
        expect(result, isNot(contains('bb')));
      });

      group('when collectionMaxCount is set', () {
        void expectRange(
          Iterable<String> items,
          int from,
          int to,
          String expected,
        ) {
          for (var i = from; i <= to; i++) {
            expect(
              Loggable.efficientLengthIterableToString(
                items,
                config: LoggableConfig(
                  collectionMaxCount: i,
                  stringInQuotes: false,
                ),
              ),
              expected,
              reason: 'collectionMaxCount=$i',
            );
          }
        }

        test('with 0 items', () {
          const items = _emptyList;
          expectRange(items, 0, 1, '(₌₀)');
        });

        test('with 1 item', () {
          const items = ['a'];
          expectRange(items, 0, 0, '(₌₁ …)');
          expectRange(items, 1, 2, '(₌₁ ₀:a)');
        });

        test('with 2 items', () {
          const items = ['a', 'b'];
          expectRange(items, 0, 0, '(₌₂ …)');
          expectRange(items, 1, 1, '(₌₂ ₀:a, …)');
          expectRange(items, 2, 2, '(₌₂ ₀:a, ₁:b)');
        });

        test('with 3 items', () {
          const items = ['a', 'b', 'c'];
          expectRange(items, 0, 0, '(₌₃ …)');
          expectRange(items, 1, 1, '(₌₃ ₀:a, …)');
          expectRange(items, 2, 2, '(₌₃ ₀:a, …, ₂:c)');
          expectRange(items, 3, 4, '(₌₃ ₀:a, ₁:b, ₂:c)');
        });

        test('with 4 items', () {
          const items = ['a', 'b', 'c', 'd'];
          expectRange(items, 0, 0, '(₌₄ …)');
          expectRange(items, 1, 1, '(₌₄ ₀:a, …)');
          expectRange(items, 2, 2, '(₌₄ ₀:a, …, ₃:d)');
          expectRange(items, 3, 3, '(₌₄ ₀:a, ₁:b, …, ₃:d)');
          expectRange(items, 4, 5, '(₌₄ ₀:a, ₁:b, ₂:c, ₃:d)');
        });
      });

      group('when collectionMaxStringLength is set', () {
        void expectRange(
          Iterable<String> items,
          int from,
          int to,
          String expected,
        ) {
          for (var i = from; i <= to; i++) {
            expect(
              Loggable.efficientLengthIterableToString(
                items,
                config: LoggableConfig(
                  collectionMaxStringLength: i,
                  collectionShowIndexes: false,
                  stringInQuotes: false,
                ),
              ),
              expected,
              reason: 'collectionMaxStringLength=$i',
            );
          }
        }

        test('with 0 items', () {
          const items = _emptyList;
          expectRange(items, 1, 4, '(₌₀)');
        });

        test('with 1 empty item', () {
          const items = [''];
          expectRange(items, 1, 5, '(₌₁ )');
        });

        test('with 1 single-letter item', () {
          const items = ['a'];
          expectRange(items, 1, 6, '(₌₁ a)');
        });

        test('with 1 multi-letter item', () {
          const items = ['ab'];
          expectRange(items, 1, 6, '(₌₁ …)');
          expectRange(items, 7, 7, '(₌₁ ab)');
        });

        test('with 2 empty items', () {
          const items = ['', ''];
          expectRange(items, 1, 6, '(₌₂ …)');
          expectRange(items, 7, 7, '(₌₂ , )');
        });

        test('with 2 single-letter items', () {
          const items = ['a', 'b'];
          expectRange(items, 1, 8, '(₌₂ …)');
          expectRange(items, 9, 9, '(₌₂ a, b)');
        });

        test('with 2 multi-letter items', () {
          const items = ['aa', 'bb'];
          expectRange(items, 1, 9, '(₌₂ …)');
          expectRange(items, 10, 10, '(₌₂ aa, …)');
          expectRange(items, 11, 11, '(₌₂ aa, bb)');
        });

        test('with 3 empty items', () {
          const items = ['', '', ''];
          expectRange(items, 1, 7, '(₌₃ …)');
          expectRange(items, 8, 8, '(₌₃ , …)');
          expectRange(items, 9, 9, '(₌₃ , , )');
        });

        test('with 3 single-letter items', () {
          const items = ['a', 'b', 'c'];
          expectRange(items, 1, 8, '(₌₃ …)');
          expectRange(items, 9, 11, '(₌₃ a, …)');
          expectRange(items, 12, 12, '(₌₃ a, b, c)');
        });

        test('with 3 multi-letter items', () {
          const items = ['aa', 'bb', 'cc'];
          expectRange(items, 1, 9, '(₌₃ …)');
          expectRange(items, 10, 13, '(₌₃ aa, …)');
          expectRange(items, 14, 14, '(₌₃ aa, …, cc)');
          expectRange(items, 15, 15, '(₌₃ aa, bb, cc)');
        });

        test('with 4 empty items', () {
          const items = ['', '', '', ''];
          expectRange(items, 1, 7, '(₌₄ …)');
          expectRange(items, 8, 8, '(₌₄ , …)');
          expectRange(items, 9, 10, '(₌₄ , …, )');
          expectRange(items, 11, 11, '(₌₄ , , , )');
        });

        test('with 4 single-letter items', () {
          const items = ['a', 'b', 'c', 'd'];
          expectRange(items, 1, 8, '(₌₄ …)');
          expectRange(items, 9, 11, '(₌₄ a, …)');
          expectRange(items, 12, 14, '(₌₄ a, …, d)');
          expectRange(items, 15, 15, '(₌₄ a, b, c, d)');
        });

        test('with 4 multi-letter items', () {
          const items = ['aa', 'bb', 'cc', 'dd'];
          expectRange(items, 1, 9, '(₌₄ …)');
          expectRange(items, 10, 13, '(₌₄ aa, …)');
          expectRange(items, 14, 17, '(₌₄ aa, …, dd)');
          expectRange(items, 18, 18, '(₌₄ aa, bb, …, dd)');
          expectRange(items, 19, 19, '(₌₄ aa, bb, cc, dd)');
        });
      });
    });

    group('iterableToString', () {
      test('does not read the length or last item', () {
        final items = _LengthCountingIterable(['a', 'b', 'c']);

        expect(
          Loggable.iterableToString(
            items,
            config: const LoggableConfig(
              collectionMaxCount: 2,
              stringInQuotes: false,
            ),
          ),
          '(₀:a, ₁:b, …)',
        );
        expect(items.lengthReads, 0);
        expect(items.lastReads, 0);
      });

      group('when collectionMaxCount is set', () {
        void expectRange(
          Iterable<String> items,
          int from,
          int to,
          String expected,
        ) {
          for (var i = from; i <= to; i++) {
            expect(
              Loggable.iterableToString(
                items,
                config: LoggableConfig(
                  collectionMaxCount: i,
                  stringInQuotes: false,
                ),
              ),
              expected,
              reason: 'collectionMaxCount=$i',
            );
          }
        }

        test('with 0 items', () {
          const items = _emptyList;
          expectRange(items, 0, 1, '()');
        });

        test('with 1 item', () {
          const items = ['a'];
          expectRange(items, 0, 0, '(…)');
          expectRange(items, 1, 2, '(₀:a)');
        });

        test('with 2 items', () {
          const items = ['a', 'b'];
          expectRange(items, 0, 0, '(…)');
          expectRange(items, 1, 1, '(₀:a, …)');
          expectRange(items, 2, 3, '(₀:a, ₁:b)');
        });

        test('with 3 items', () {
          const items = ['a', 'b', 'c'];
          expectRange(items, 0, 0, '(…)');
          expectRange(items, 1, 1, '(₀:a, …)');
          expectRange(items, 2, 2, '(₀:a, ₁:b, …)');
          expectRange(items, 3, 4, '(₀:a, ₁:b, ₂:c)');
        });

        test('with 4 items', () {
          const items = ['a', 'b', 'c', 'd'];
          expectRange(items, 0, 0, '(…)');
          expectRange(items, 1, 1, '(₀:a, …)');
          expectRange(items, 2, 2, '(₀:a, ₁:b, …)');
          expectRange(items, 3, 3, '(₀:a, ₁:b, ₂:c, …)');
          expectRange(items, 4, 5, '(₀:a, ₁:b, ₂:c, ₃:d)');
        });
      });

      group('when collectionMaxStringLength is set', () {
        void expectRange(
          Iterable<String> items,
          int from,
          int to,
          String expected,
        ) {
          for (var i = from; i <= to; i++) {
            expect(
              Loggable.iterableToString(
                items,
                config: LoggableConfig(
                  collectionMaxStringLength: i,
                  collectionShowIndexes: false,
                  stringInQuotes: false,
                ),
              ),
              expected,
              reason: 'collectionMaxStringLength=$i',
            );
          }
        }

        test('with 0 items', () {
          const items = _emptyList;
          expectRange(items, 1, 2, '()');
        });

        test('with 1 empty item', () {
          const items = [''];
          expectRange(items, 1, 2, '()');
        });

        test('with 1 single-letter item', () {
          const items = ['a'];
          expectRange(items, 1, 3, '(a)');
        });

        test('with 1 multi-letter item', () {
          const items = ['ab'];
          expectRange(items, 1, 3, '(…)');
          expectRange(items, 4, 4, '(ab)');
        });

        test('with 2 empty items', () {
          const items = ['', ''];
          expectRange(items, 1, 3, '(…)');
          expectRange(items, 4, 4, '(, )');
        });

        test('with 2 single-letter items', () {
          const items = ['a', 'b'];
          expectRange(items, 1, 5, '(…)');
          expectRange(items, 6, 6, '(a, b)');
        });

        test('with 2 multi-letter items', () {
          const items = ['aa', 'bb'];
          expectRange(items, 1, 6, '(…)');
          expectRange(items, 7, 7, '(aa, …)');
          expectRange(items, 8, 8, '(aa, bb)');
        });

        test('with 3 empty items', () {
          const items = ['', '', ''];
          expectRange(items, 1, 4, '(…)');
          expectRange(items, 5, 5, '(, …)');
          expectRange(items, 6, 6, '(, , )');
        });

        test('with 3 single-letter items', () {
          const items = ['a', 'b', 'c'];
          expectRange(items, 1, 5, '(…)');
          expectRange(items, 6, 8, '(a, …)');
          expectRange(items, 9, 9, '(a, b, c)');
        });

        test('with 3 multi-letter items', () {
          const items = ['aa', 'bb', 'cc'];
          expectRange(items, 1, 6, '(…)');
          expectRange(items, 7, 10, '(aa, …)');
          expectRange(items, 11, 11, '(aa, bb, …)');
          expectRange(items, 12, 12, '(aa, bb, cc)');
        });

        test('with 4 empty items', () {
          const items = ['', '', '', ''];
          expectRange(items, 1, 4, '(…)');
          expectRange(items, 5, 6, '(, …)');
          expectRange(items, 7, 7, '(, , …)');
          expectRange(items, 8, 8, '(, , , )');
        });

        test('with 4 single-letter items', () {
          const items = ['a', 'b', 'c', 'd'];
          expectRange(items, 1, 5, '(…)');
          expectRange(items, 6, 8, '(a, …)');
          expectRange(items, 9, 11, '(a, b, …)');
          expectRange(items, 12, 12, '(a, b, c, d)');
        });

        test('with 4 multi-letter items', () {
          const items = ['aa', 'bb', 'cc', 'dd'];
          expectRange(items, 1, 6, '(…)');
          expectRange(items, 7, 10, '(aa, …)');
          expectRange(items, 11, 14, '(aa, bb, …)');
          expectRange(items, 15, 15, '(aa, bb, cc, …)');
          expectRange(items, 16, 16, '(aa, bb, cc, dd)');
        });

        test('styles delimiters', () {
          final theme = LogMainTheme.defaultActiveTheme.verbose;
          final result = Loggable.iterableToString(
            ['aa', 'bb', 'cc'],
            theme: theme,
            config: const LoggableConfig(
              collectionMaxStringLength: 12,
              collectionShowIndexes: false,
              stringInQuotes: false,
            ),
          );
          final delimiter = theme.depthTheme(0).punctuation(', ');

          expect(result.lengthWithoutEscapeCodes, 12);
          expect(delimiter.allMatches(result), hasLength(2));
        });
      });
    });
  });
}
