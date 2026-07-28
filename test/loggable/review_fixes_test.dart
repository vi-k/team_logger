import 'dart:convert';

import 'package:team_logger/team_logger.dart';
import 'package:test/test.dart';

final class _Plain {
  final int x;

  const _Plain(this.x);
}

final class _PlainConverter implements LoggableTypeConverter<_Plain> {
  @override
  LoggableData convertToData(_Plain obj) =>
      Loggable.builder(obj, name: 'Plain')..prop('x', obj.x);
}

void main() {
  group('LoggableMultiView.toJson', () {
    test('returns structured JSON instead of a joined string', () {
      const view = LoggableMultiView([
        LoggableView(36, units: 'km/h'),
        LoggableView(10, units: 'm/s'),
      ]);

      final json = view.toJson(null);

      expect(json, {
        ':k': 'multi-view',
        ':v': [
          {':v': 36, ':u': 'km/h'},
          {':v': 10, ':u': 'm/s'},
        ],
      });
      expect(() => jsonEncode(json), returnsNormally);
    });
  });

  group('LoggableTypeConverter', () {
    tearDown(Loggable.unregisterTypeConverter<_Plain>);

    test('interface requires only convertToData', () {
      Loggable.registerTypeConverter<_Plain>(_PlainConverter());

      expect(Loggable.objectToString(const _Plain(7)), contains('7'));
      expect(
        jsonEncode(Loggable.objectToJson(const _Plain(7))),
        contains('7'),
      );
    });
  });

  group('ControlCodeFormatter', () {
    test('does not leak ANSI reset into noColors output', () {
      final result = Loggable.objectToString('a\nb');

      expect(result, isNot(contains('\x1B')));
    });
  });

  group('collectionMaxCount + collectionMaxStringLength', () {
    test('list stays within the length budget', () {
      final result = Loggable.listToString(
        [111, 222, 333, 444, 555],
        config: const LoggableConfig(
          collectionMaxCount: 4,
          collectionMaxStringLength: 20,
        ),
      );

      expect(result.length, lessThanOrEqualTo(20));
    });

    test('iterable stays within the length budget', () {
      final result = Loggable.iterableToString(
        Iterable<int>.generate(5, (i) => 111 * (i + 1)),
        config: const LoggableConfig(
          collectionMaxCount: 2,
          collectionMaxStringLength: 10,
        ),
      );

      expect(result.length, lessThanOrEqualTo(10));
    });
  });
}
