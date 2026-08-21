import 'package:team_logger/team_logger.dart';
import 'package:test/test.dart';

Logger _logger(LogStorage storage) => Logger('app')
  ..level = LogLevels.all
  ..publisher = storage;

void main() {
  group('LogStorage', () {
    test('maxCount must be positive', () {
      for (final value in [0, -1]) {
        expect(
          () => LogStorage(maxCount: value),
          throwsA(
            isA<ArgumentError>()
                .having((error) => error.name, 'name', 'maxCount')
                .having(
                  (error) => error.invalidValue,
                  'invalidValue',
                  value,
                ),
          ),
        );
      }
    });

    test('publish and clear after dispose are silent no-ops', () async {
      final storage = LogStorage(maxCount: 10);
      final log = _logger(storage);
      log.i('before');
      await storage.dispose();

      expect(() => log.i('after'), returnsNormally);
      expect(storage.clear, returnsNormally);
    });

    test('reversed.reversed restores the original order', () {
      final storage = LogStorage(maxCount: 10);
      _logger(storage)
        ..i('a')
        ..i('b');

      expect(storage[0].message, 'a');
      expect(storage.reversed[0].message, 'b');
      expect(storage.reversed.reversed[0].message, 'a');
    });

    test('snapshot of an empty storage is growable', () {
      final storage = LogStorage(maxCount: 10);
      final empty = storage.snapshot();

      _logger(storage).i('x');
      final nonEmpty = storage.snapshot();

      expect(() => empty.addAll(nonEmpty), returnsNormally);
    });
  });

  group('tags conversion', () {
    test('accepts an untyped iterable of strings', () {
      final storage = LogStorage(maxCount: 10);
      final log = _logger(storage);

      expect(
        () => log.i('msg', tags: <Object>['a', 'b']),
        returnsNormally,
      );
      expect(storage.last.tags, {'a', 'b'});
    });
  });
}
