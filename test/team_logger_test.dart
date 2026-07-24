import 'package:team_logger/team_logger.dart';
import 'package:test/test.dart';

void main() {
  group('Loggable static methods:', () {
    group('enumToJson', () {
      test('w/o units.', () {
        expect(Loggable.enumToJson(LogTextAlign.left), {
          ':enum': 'LogTextAlign',
          ':name': 'left',
        });
      });

      test('with units.', () {
        const config = LoggableJsonConfig(units: 'm');
        expect(Loggable.enumToJson(LogTextAlign.left, config: config), {
          ':enum': 'LogTextAlign',
          ':name': 'left',
          ':units': 'm',
        });
      });
    });

    group('bool to json', () {
      test('w/o units.', () {
        expect(Loggable.objectToJson(false), false);
        expect(Loggable.objectToJson(true), true);
      });

      test('with units.', () {
        const config = LoggableJsonConfig(units: 'm');
        expect(
          Loggable.objectToJson(false, config: config),
          {':value': false, ':units': 'm'},
        );
        expect(
          Loggable.objectToJson(true, config: config),
          {':value': true, ':units': 'm'},
        );
      });
    });

    group('int to json', () {
      test('w/o units.', () {
        expect(Loggable.objectToJson(0), 0);
        expect(Loggable.objectToJson(42), 42);
        expect(Loggable.objectToJson(-42), -42);
      });

      test('with units.', () {
        const config = LoggableJsonConfig(units: 'm');
        expect(
          Loggable.objectToJson(0, config: config),
          {':value': 0, ':units': 'm'},
        );
        expect(
          Loggable.objectToJson(42, config: config),
          {':value': 42, ':units': 'm'},
        );
        expect(
          Loggable.objectToJson(-42, config: config),
          {':value': -42, ':units': 'm'},
        );
      });
    });

    group('double to json', () {
      test('w/o units.', () {
        expect(Loggable.objectToJson(0.0), 0.0);
        expect(Loggable.objectToJson(-0.0), -0.0);
        expect(Loggable.objectToJson(12345678.9), 12345678.9);
        expect(
          Loggable.objectToJson(double.nan),
          {':type': 'double', ':value': 'nan'},
        );
        expect(
          Loggable.objectToJson(double.infinity),
          {':type': 'double', ':value': 'inf'},
        );
        expect(
          Loggable.objectToJson(-double.infinity),
          {':type': 'double', ':value': '-inf'},
        );
        expect(
          Loggable.objectToJson(double.negativeInfinity),
          {':type': 'double', ':value': '-inf'},
        );
      });

      test('with units.', () {
        const config = LoggableJsonConfig(units: 'm');
        expect(
          Loggable.objectToJson(0.0, config: config),
          {':value': 0.0, ':units': 'm'},
        );
        expect(
          Loggable.objectToJson(-0.0, config: config),
          {':value': -0.0, ':units': 'm'},
        );
        expect(
          Loggable.objectToJson(12345678.9, config: config),
          {':value': 12345678.9, ':units': 'm'},
        );
        expect(
          Loggable.objectToJson(double.nan, config: config),
          {':type': 'double', ':value': 'nan', ':units': 'm'},
        );
        expect(
          Loggable.objectToJson(double.infinity, config: config),
          {':type': 'double', ':value': 'inf', ':units': 'm'},
        );
        expect(
          Loggable.objectToJson(-double.infinity, config: config),
          {':type': 'double', ':value': '-inf', ':units': 'm'},
        );
        expect(
          Loggable.objectToJson(double.negativeInfinity, config: config),
          {':type': 'double', ':value': '-inf', ':units': 'm'},
        );
      });
    });

    /// Отличается от `efficientLengthIterableToJson` тем, что
    /// несокращаемый список, у которого нет units, передаётся прямо, без
    /// преобразования в Map.
    group('listToJson.', () {
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

      test('0 items', () {
        final items = <String>[];
        expectNoLimit(items, <String>[]);
        expectNoLimit(items, units: 'm', {
          ':type': 'List',
          ':values': <String>[],
          ':units': 'm',
        });
        expectFull(items, <String>[]);
        expectFull(items, units: 'm', {
          ':type': 'List',
          ':values': <String>[],
          ':units': 'm',
        });
      });

      test('1 item', () {
        final items = ['a'];
        expectNoLimit(items, ['a']);
        expectNoLimit(items, units: 'm', {
          ':type': 'List',
          ':values': ['a'],
          ':units': 'm',
        });
        expectLimited(items, 0, {
          ':type': 'List',
          ':length': 1,
          ':values': <String>[],
        });
        expectLimited(items, 0, units: 'm', {
          ':type': 'List',
          ':length': 1,
          ':values': <String>[],
          ':units': 'm',
        });
        expectFull(items, ['a']);
        expectFull(items, units: 'm', {
          ':type': 'List',
          ':values': ['a'],
          ':units': 'm',
        });
      });

      test('2 items', () {
        final items = ['a', 'b'];
        expectNoLimit(items, ['a', 'b']);
        expectNoLimit(items, units: 'm', {
          ':type': 'List',
          ':values': ['a', 'b'],
          ':units': 'm',
        });
        expectLimited(items, 0, {
          ':type': 'List',
          ':length': 2,
          ':values': <String>[],
        });
        expectLimited(items, 0, units: 'm', {
          ':type': 'List',
          ':length': 2,
          ':values': <String>[],
          ':units': 'm',
        });
        expectLimited(items, 1, {
          ':type': 'List',
          ':length': 2,
          ':values': ['a'],
        });
        expectLimited(items, 1, units: 'm', {
          ':type': 'List',
          ':length': 2,
          ':values': ['a'],
          ':units': 'm',
        });
        expectFull(items, ['a', 'b']);
        expectFull(items, units: 'm', {
          ':type': 'List',
          ':values': ['a', 'b'],
          ':units': 'm',
        });
      });

      test('3 items', () {
        final items = ['a', 'b', 'c'];
        expectNoLimit(items, ['a', 'b', 'c']);
        expectNoLimit(items, units: 'm', {
          ':type': 'List',
          ':values': ['a', 'b', 'c'],
          ':units': 'm',
        });
        expectLimited(items, 0, {
          ':type': 'List',
          ':length': 3,
          ':values': <String>[],
        });
        expectLimited(items, 0, units: 'm', {
          ':type': 'List',
          ':length': 3,
          ':values': <String>[],
          ':units': 'm',
        });
        expectLimited(items, 1, {
          ':type': 'List',
          ':length': 3,
          ':values': ['a'],
        });
        expectLimited(items, 1, units: 'm', {
          ':type': 'List',
          ':length': 3,
          ':values': ['a'],
          ':units': 'm',
        });
        expectLimited(items, 2, {
          ':type': 'List',
          ':length': 3,
          ':values': ['a', 'c'],
        });
        expectLimited(items, 2, units: 'm', {
          ':type': 'List',
          ':length': 3,
          ':values': ['a', 'c'],
          ':units': 'm',
        });
        expectFull(items, ['a', 'b', 'c']);
        expectFull(items, units: 'm', {
          ':type': 'List',
          ':values': ['a', 'b', 'c'],
          ':units': 'm',
        });
      });

      test('4 items', () {
        final items = ['a', 'b', 'c', 'd'];
        expectNoLimit(items, ['a', 'b', 'c', 'd']);
        expectNoLimit(items, units: 'm', {
          ':type': 'List',
          ':values': ['a', 'b', 'c', 'd'],
          ':units': 'm',
        });
        expectLimited(items, 0, {
          ':type': 'List',
          ':length': 4,
          ':values': <String>[],
        });
        expectLimited(items, 0, units: 'm', {
          ':type': 'List',
          ':length': 4,
          ':values': <String>[],
          ':units': 'm',
        });
        expectLimited(items, 1, {
          ':type': 'List',
          ':length': 4,
          ':values': ['a'],
        });
        expectLimited(items, 1, units: 'm', {
          ':type': 'List',
          ':length': 4,
          ':values': ['a'],
          ':units': 'm',
        });
        expectLimited(items, 2, {
          ':type': 'List',
          ':length': 4,
          ':values': ['a', 'd'],
        });
        expectLimited(items, 2, units: 'm', {
          ':type': 'List',
          ':length': 4,
          ':values': ['a', 'd'],
          ':units': 'm',
        });
        expectLimited(items, 3, {
          ':type': 'List',
          ':length': 4,
          ':values': ['a', 'b', 'd'],
        });
        expectLimited(items, 3, units: 'm', {
          ':type': 'List',
          ':length': 4,
          ':values': ['a', 'b', 'd'],
          ':units': 'm',
        });
        expectFull(items, ['a', 'b', 'c', 'd']);
        expectFull(items, units: 'm', {
          ':type': 'List',
          ':values': ['a', 'b', 'c', 'd'],
          ':units': 'm',
        });
      });
    });

    group('efficientLengthIterableToJson.', () {
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

      test('0 items', () {
        final items = <String>[];
        expectNoLimit(items, {
          ':type': 'Iterable',
          ':values': <String>[],
        });
        expectNoLimit(items, units: 'm', {
          ':type': 'Iterable',
          ':values': <String>[],
          ':units': 'm',
        });
        expectFull(items, {
          ':type': 'Iterable',
          ':values': <String>[],
        });
        expectFull(items, units: 'm', {
          ':type': 'Iterable',
          ':values': <String>[],
          ':units': 'm',
        });
      });

      test('1 item', () {
        final items = ['a'];
        expectNoLimit(items, {
          ':type': 'Iterable',
          ':values': ['a'],
        });
        expectNoLimit(items, units: 'm', {
          ':type': 'Iterable',
          ':values': ['a'],
          ':units': 'm',
        });
        expectLimited(items, 0, {
          ':type': 'Iterable',
          ':length': 1,
          ':values': <String>[],
        });
        expectLimited(items, 0, units: 'm', {
          ':type': 'Iterable',
          ':length': 1,
          ':values': <String>[],
          ':units': 'm',
        });
        expectFull(items, {
          ':type': 'Iterable',
          ':values': ['a'],
        });
        expectFull(items, units: 'm', {
          ':type': 'Iterable',
          ':values': ['a'],
          ':units': 'm',
        });
      });

      test('2 items', () {
        final items = ['a', 'b'];
        expectNoLimit(items, {
          ':type': 'Iterable',
          ':values': ['a', 'b'],
        });
        expectNoLimit(items, units: 'm', {
          ':type': 'Iterable',
          ':values': ['a', 'b'],
          ':units': 'm',
        });
        expectLimited(items, 0, {
          ':type': 'Iterable',
          ':length': 2,
          ':values': <String>[],
        });
        expectLimited(items, 0, units: 'm', {
          ':type': 'Iterable',
          ':length': 2,
          ':values': <String>[],
          ':units': 'm',
        });
        expectLimited(items, 1, {
          ':type': 'Iterable',
          ':length': 2,
          ':values': ['a'],
        });
        expectLimited(items, 1, units: 'm', {
          ':type': 'Iterable',
          ':length': 2,
          ':values': ['a'],
          ':units': 'm',
        });
        expectFull(items, {
          ':type': 'Iterable',
          ':values': ['a', 'b'],
        });
        expectFull(items, units: 'm', {
          ':type': 'Iterable',
          ':values': ['a', 'b'],
          ':units': 'm',
        });
      });

      test('3 items', () {
        final items = ['a', 'b', 'c'];
        expectNoLimit(items, {
          ':type': 'Iterable',
          ':values': ['a', 'b', 'c'],
        });
        expectNoLimit(items, units: 'm', {
          ':type': 'Iterable',
          ':values': ['a', 'b', 'c'],
          ':units': 'm',
        });
        expectLimited(items, 0, {
          ':type': 'Iterable',
          ':length': 3,
          ':values': <String>[],
        });
        expectLimited(items, 0, units: 'm', {
          ':type': 'Iterable',
          ':length': 3,
          ':values': <String>[],
          ':units': 'm',
        });
        expectLimited(items, 1, {
          ':type': 'Iterable',
          ':length': 3,
          ':values': ['a'],
        });
        expectLimited(items, 1, units: 'm', {
          ':type': 'Iterable',
          ':length': 3,
          ':values': ['a'],
          ':units': 'm',
        });
        expectLimited(items, 2, {
          ':type': 'Iterable',
          ':length': 3,
          ':values': ['a', 'c'],
        });
        expectLimited(items, 2, units: 'm', {
          ':type': 'Iterable',
          ':length': 3,
          ':values': ['a', 'c'],
          ':units': 'm',
        });
        expectFull(items, {
          ':type': 'Iterable',
          ':values': ['a', 'b', 'c'],
        });
        expectFull(items, units: 'm', {
          ':type': 'Iterable',
          ':values': ['a', 'b', 'c'],
          ':units': 'm',
        });
      });

      test('4 items', () {
        final items = ['a', 'b', 'c', 'd'];
        expectNoLimit(items, {
          ':type': 'Iterable',
          ':values': ['a', 'b', 'c', 'd'],
        });
        expectNoLimit(items, units: 'm', {
          ':type': 'Iterable',
          ':values': ['a', 'b', 'c', 'd'],
          ':units': 'm',
        });
        expectLimited(items, 0, {
          ':type': 'Iterable',
          ':length': 4,
          ':values': <String>[],
        });
        expectLimited(items, 0, units: 'm', {
          ':type': 'Iterable',
          ':length': 4,
          ':values': <String>[],
          ':units': 'm',
        });
        expectLimited(items, 1, {
          ':type': 'Iterable',
          ':length': 4,
          ':values': ['a'],
        });
        expectLimited(items, 1, units: 'm', {
          ':type': 'Iterable',
          ':length': 4,
          ':values': ['a'],
          ':units': 'm',
        });
        expectLimited(items, 2, {
          ':type': 'Iterable',
          ':length': 4,
          ':values': ['a', 'd'],
        });
        expectLimited(items, 2, units: 'm', {
          ':type': 'Iterable',
          ':length': 4,
          ':values': ['a', 'd'],
          ':units': 'm',
        });
        expectLimited(items, 3, {
          ':type': 'Iterable',
          ':length': 4,
          ':values': ['a', 'b', 'd'],
        });
        expectLimited(items, 3, units: 'm', {
          ':type': 'Iterable',
          ':length': 4,
          ':values': ['a', 'b', 'd'],
          ':units': 'm',
        });
        expectFull(items, {
          ':type': 'Iterable',
          ':values': ['a', 'b', 'c', 'd'],
        });
        expectFull(items, units: 'm', {
          ':type': 'Iterable',
          ':values': ['a', 'b', 'c', 'd'],
          ':units': 'm',
        });
      });
    });

    group('iterableToJson.', () {
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

      test('0 items', () {
        final items = <String>[];
        expectNoLimit(items, {
          ':type': 'Iterable',
          ':values': <String>[],
        });
        expectNoLimit(items, units: 'm', {
          ':type': 'Iterable',
          ':values': <String>[],
          ':units': 'm',
        });
        expectFull(items, {
          ':type': 'Iterable',
          ':values': <String>[],
        });
        expectFull(items, units: 'm', {
          ':type': 'Iterable',
          ':values': <String>[],
          ':units': 'm',
        });
      });

      test('1 item', () {
        final items = ['a'];
        expectNoLimit(items, {
          ':type': 'Iterable',
          ':values': ['a'],
        });
        expectNoLimit(items, units: 'm', {
          ':type': 'Iterable',
          ':values': ['a'],
          ':units': 'm',
        });
        expectLimited(items, 0, {
          ':type': 'Iterable',
          ':values': <String>[],
          ':trimmed': true,
        });
        expectLimited(items, 0, units: 'm', {
          ':type': 'Iterable',
          ':values': <String>[],
          ':trimmed': true,
          ':units': 'm',
        });
        expectFull(items, {
          ':type': 'Iterable',
          ':values': ['a'],
        });
        expectFull(items, units: 'm', {
          ':type': 'Iterable',
          ':values': ['a'],
          ':units': 'm',
        });
      });

      test('2 items', () {
        final items = ['a', 'b'];
        expectNoLimit(items, {
          ':type': 'Iterable',
          ':values': ['a', 'b'],
        });
        expectNoLimit(items, units: 'm', {
          ':type': 'Iterable',
          ':values': ['a', 'b'],
          ':units': 'm',
        });
        expectLimited(items, 0, {
          ':type': 'Iterable',
          ':values': <String>[],
          ':trimmed': true,
        });
        expectLimited(items, 0, units: 'm', {
          ':type': 'Iterable',
          ':values': <String>[],
          ':trimmed': true,
          ':units': 'm',
        });
        expectLimited(items, 1, {
          ':type': 'Iterable',
          ':values': ['a'],
          ':trimmed': true,
        });
        expectLimited(items, 1, units: 'm', {
          ':type': 'Iterable',
          ':values': ['a'],
          ':trimmed': true,
          ':units': 'm',
        });
        expectFull(items, {
          ':type': 'Iterable',
          ':values': ['a', 'b'],
        });
        expectFull(items, units: 'm', {
          ':type': 'Iterable',
          ':values': ['a', 'b'],
          ':units': 'm',
        });
      });

      test('3 items', () {
        final items = ['a', 'b', 'c'];
        expectNoLimit(items, {
          ':type': 'Iterable',
          ':values': ['a', 'b', 'c'],
        });
        expectNoLimit(items, units: 'm', {
          ':type': 'Iterable',
          ':values': ['a', 'b', 'c'],
          ':units': 'm',
        });
        expectLimited(items, 0, {
          ':type': 'Iterable',
          ':values': <String>[],
          ':trimmed': true,
        });
        expectLimited(items, 0, units: 'm', {
          ':type': 'Iterable',
          ':values': <String>[],
          ':trimmed': true,
          ':units': 'm',
        });
        expectLimited(items, 1, {
          ':type': 'Iterable',
          ':values': ['a'],
          ':trimmed': true,
        });
        expectLimited(items, 1, units: 'm', {
          ':type': 'Iterable',
          ':values': ['a'],
          ':trimmed': true,
          ':units': 'm',
        });
        expectLimited(items, 2, {
          ':type': 'Iterable',
          ':values': ['a', 'b'],
          ':trimmed': true,
        });
        expectLimited(items, 2, units: 'm', {
          ':type': 'Iterable',
          ':values': ['a', 'b'],
          ':trimmed': true,
          ':units': 'm',
        });
        expectFull(items, {
          ':type': 'Iterable',
          ':values': ['a', 'b', 'c'],
        });
        expectFull(items, units: 'm', {
          ':type': 'Iterable',
          ':values': ['a', 'b', 'c'],
          ':units': 'm',
        });
      });

      test('4 items', () {
        final items = ['a', 'b', 'c', 'd'];
        expectNoLimit(items, {
          ':type': 'Iterable',
          ':values': ['a', 'b', 'c', 'd'],
        });
        expectNoLimit(items, units: 'm', {
          ':type': 'Iterable',
          ':values': ['a', 'b', 'c', 'd'],
          ':units': 'm',
        });
        expectLimited(items, 0, {
          ':type': 'Iterable',
          ':values': <String>[],
          ':trimmed': true,
        });
        expectLimited(items, 0, units: 'm', {
          ':type': 'Iterable',
          ':values': <String>[],
          ':trimmed': true,
          ':units': 'm',
        });
        expectLimited(items, 1, {
          ':type': 'Iterable',
          ':values': ['a'],
          ':trimmed': true,
        });
        expectLimited(items, 1, units: 'm', {
          ':type': 'Iterable',
          ':values': ['a'],
          ':trimmed': true,
          ':units': 'm',
        });
        expectLimited(items, 2, {
          ':type': 'Iterable',
          ':values': ['a', 'b'],
          ':trimmed': true,
        });
        expectLimited(items, 2, units: 'm', {
          ':type': 'Iterable',
          ':values': ['a', 'b'],
          ':trimmed': true,
          ':units': 'm',
        });
        expectLimited(items, 3, {
          ':type': 'Iterable',
          ':values': ['a', 'b', 'c'],
          ':trimmed': true,
        });
        expectLimited(items, 3, units: 'm', {
          ':type': 'Iterable',
          ':values': ['a', 'b', 'c'],
          ':trimmed': true,
          ':units': 'm',
        });
        expectFull(items, {
          ':type': 'Iterable',
          ':values': ['a', 'b', 'c', 'd'],
        });
        expectFull(items, units: 'm', {
          ':type': 'Iterable',
          ':values': ['a', 'b', 'c', 'd'],
          ':units': 'm',
        });
      });
    });

    group('efficientLengthIterableToString.', () {
      group('Check collectionMaxCount.', () {
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

        test('0 items', () {
          final items = <String>[];
          expectRange(items, 0, 1, '(₌₀)');
        });

        test('1 item', () {
          final items = ['a'];
          expectRange(items, 0, 0, '(₌₁ …)');
          expectRange(items, 1, 2, '(₌₁ ₀:a)');
        });

        test('2 items', () {
          final items = ['a', 'b'];
          expectRange(items, 0, 0, '(₌₂ …)');
          expectRange(items, 1, 1, '(₌₂ ₀:a, …)');
          expectRange(items, 2, 2, '(₌₂ ₀:a, ₁:b)');
        });

        test('3 items', () {
          final items = ['a', 'b', 'c'];
          expectRange(items, 0, 0, '(₌₃ …)');
          expectRange(items, 1, 1, '(₌₃ ₀:a, …)');
          expectRange(items, 2, 2, '(₌₃ ₀:a, …, ₂:c)');
          expectRange(items, 3, 4, '(₌₃ ₀:a, ₁:b, ₂:c)');
        });

        test('4 items', () {
          final items = ['a', 'b', 'c', 'd'];
          expectRange(items, 0, 0, '(₌₄ …)');
          expectRange(items, 1, 1, '(₌₄ ₀:a, …)');
          expectRange(items, 2, 2, '(₌₄ ₀:a, …, ₃:d)');
          expectRange(items, 3, 3, '(₌₄ ₀:a, ₁:b, …, ₃:d)');
          expectRange(items, 4, 5, '(₌₄ ₀:a, ₁:b, ₂:c, ₃:d)');
        });
      });

      group('Check collectionMaxStringLength.', () {
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

        test('0 items', () {
          final items = <String>[];
          expectRange(items, 1, 4, '(₌₀)');
        });

        test('1 empty item', () {
          final items = [''];
          expectRange(items, 1, 5, '(₌₁ )');
        });

        test('1 single-letter item', () {
          final items = ['a'];
          expectRange(items, 1, 6, '(₌₁ a)');
        });

        test('1 multi-letter item', () {
          final items = ['ab'];
          expectRange(items, 1, 6, '(₌₁ …)');
          expectRange(items, 7, 7, '(₌₁ ab)');
        });

        test('2 empty items', () {
          final items = ['', ''];
          // expectRange(items, 1, 6, '(₌₂ …)');
          expectRange(items, 7, 7, '(₌₂ , )');
        });

        test('2 single-letter items', () {
          final items = ['a', 'b'];
          expectRange(items, 1, 8, '(₌₂ …)');
          expectRange(items, 9, 9, '(₌₂ a, b)');
        });

        test('2 multi-letter items', () {
          final items = ['aa', 'bb'];
          expectRange(items, 1, 9, '(₌₂ …)');
          expectRange(items, 10, 10, '(₌₂ aa, …)');
          expectRange(items, 11, 11, '(₌₂ aa, bb)');
        });

        test('3 empty items', () {
          final items = ['', '', ''];
          expectRange(items, 1, 7, '(₌₃ …)');
          expectRange(items, 8, 8, '(₌₃ , …)');
          expectRange(items, 9, 9, '(₌₃ , , )');
        });

        test('3 single-letter items', () {
          final items = ['a', 'b', 'c'];
          expectRange(items, 1, 8, '(₌₃ …)');
          expectRange(items, 9, 11, '(₌₃ a, …)');
          expectRange(items, 12, 12, '(₌₃ a, b, c)');
        });

        test('3 multi-letter items', () {
          final items = ['aa', 'bb', 'cc'];
          expectRange(items, 1, 9, '(₌₃ …)');
          expectRange(items, 10, 13, '(₌₃ aa, …)');
          expectRange(items, 14, 14, '(₌₃ aa, …, cc)');
          expectRange(items, 15, 15, '(₌₃ aa, bb, cc)');
        });

        test('4 empty items', () {
          final items = ['', '', '', ''];
          expectRange(items, 1, 7, '(₌₄ …)');
          expectRange(items, 8, 8, '(₌₄ , …)');
          expectRange(items, 9, 10, '(₌₄ , …, )');
          expectRange(items, 11, 11, '(₌₄ , , , )');
        });

        test('4 single-letter items', () {
          final items = ['a', 'b', 'c', 'd'];
          expectRange(items, 1, 8, '(₌₄ …)');
          expectRange(items, 9, 11, '(₌₄ a, …)');
          expectRange(items, 12, 14, '(₌₄ a, …, d)');
          expectRange(items, 15, 15, '(₌₄ a, b, c, d)');
        });

        test('4 multi-letter items', () {
          final items = ['aa', 'bb', 'cc', 'dd'];
          expectRange(items, 1, 9, '(₌₄ …)');
          expectRange(items, 10, 13, '(₌₄ aa, …)');
          expectRange(items, 14, 17, '(₌₄ aa, …, dd)');
          expectRange(items, 18, 18, '(₌₄ aa, bb, …, dd)');
          expectRange(items, 19, 19, '(₌₄ aa, bb, cc, dd)');
        });
      });
    });

    group('iterableToString.', () {
      group('Check collectionMaxCount.', () {
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

        test('0 items', () {
          final items = <String>[];
          expectRange(items, 0, 1, '()');
        });

        test('1 item', () {
          final items = ['a'];
          expectRange(items, 0, 0, '(…)');
          expectRange(items, 1, 2, '(₀:a)');
        });

        test('2 items', () {
          final items = ['a', 'b'];
          expectRange(items, 0, 0, '(…)');
          expectRange(items, 1, 1, '(₀:a, …)');
          expectRange(items, 2, 3, '(₀:a, ₁:b)');
        });

        test('3 items', () {
          final items = ['a', 'b', 'c'];
          expectRange(items, 0, 0, '(…)');
          expectRange(items, 1, 1, '(₀:a, …)');
          expectRange(items, 2, 2, '(₀:a, ₁:b, …)');
          expectRange(items, 3, 4, '(₀:a, ₁:b, ₂:c)');
        });

        test('4 items', () {
          final items = ['a', 'b', 'c', 'd'];
          expectRange(items, 0, 0, '(…)');
          expectRange(items, 1, 1, '(₀:a, …)');
          expectRange(items, 2, 2, '(₀:a, ₁:b, …)');
          expectRange(items, 3, 3, '(₀:a, ₁:b, ₂:c, …)');
          expectRange(items, 4, 5, '(₀:a, ₁:b, ₂:c, ₃:d)');
        });
      });

      group('Check collectionMaxStringLength.', () {
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

        test('0 items', () {
          final items = <String>[];
          expectRange(items, 1, 2, '()');
        });

        test('1 empty item', () {
          final items = [''];
          expectRange(items, 1, 2, '()');
        });

        test('1 single-letter item', () {
          final items = ['a'];
          expectRange(items, 1, 3, '(a)');
        });

        test('1 multi-letter item', () {
          final items = ['ab'];
          expectRange(items, 1, 3, '(…)');
          expectRange(items, 4, 4, '(ab)');
        });

        test('2 empty items', () {
          final items = ['', ''];
          expectRange(items, 1, 3, '(…)');
          expectRange(items, 4, 4, '(, )');
        });

        test('2 single-letter items', () {
          final items = ['a', 'b'];
          expectRange(items, 1, 5, '(…)');
          expectRange(items, 6, 6, '(a, b)');
        });

        test('2 multi-letter items', () {
          final items = ['aa', 'bb'];
          expectRange(items, 1, 6, '(…)');
          expectRange(items, 7, 7, '(aa, …)');
          expectRange(items, 8, 8, '(aa, bb)');
        });

        test('3 empty items', () {
          final items = ['', '', ''];
          expectRange(items, 1, 4, '(…)');
          expectRange(items, 5, 5, '(, …)');
          expectRange(items, 6, 6, '(, , )');
        });

        test('3 single-letter items', () {
          final items = ['a', 'b', 'c'];
          expectRange(items, 1, 5, '(…)');
          expectRange(items, 6, 8, '(a, …)');
          expectRange(items, 9, 9, '(a, b, c)');
        });

        test('3 multi-letter items', () {
          final items = ['aa', 'bb', 'cc'];
          expectRange(items, 1, 6, '(…)');
          expectRange(items, 7, 10, '(aa, …)');
          expectRange(items, 11, 11, '(aa, bb, …)');
          expectRange(items, 12, 12, '(aa, bb, cc)');
        });

        test('4 empty items', () {
          final items = ['', '', '', ''];
          expectRange(items, 1, 4, '(…)');
          expectRange(items, 5, 6, '(, …)');
          expectRange(items, 7, 7, '(, , …)');
          expectRange(items, 8, 8, '(, , , )');
        });

        test('4 single-letter items', () {
          final items = ['a', 'b', 'c', 'd'];
          expectRange(items, 1, 5, '(…)');
          expectRange(items, 6, 8, '(a, …)');
          expectRange(items, 9, 11, '(a, b, …)');
          expectRange(items, 12, 12, '(a, b, c, d)');
        });

        test('4 multi-letter items', () {
          final items = ['aa', 'bb', 'cc', 'dd'];
          expectRange(items, 1, 6, '(…)');
          expectRange(items, 7, 10, '(aa, …)');
          expectRange(items, 11, 14, '(aa, bb, …)');
          expectRange(items, 15, 15, '(aa, bb, cc, …)');
          expectRange(items, 16, 16, '(aa, bb, cc, dd)');
        });
      });
    });
  });
}
