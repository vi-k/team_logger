import 'package:team_logger/team_logger.dart';
import 'package:test/test.dart';

void main() {
  group('Loggable.sanitizer — root', () {
    tearDown(() => Loggable.sanitizer = null);

    test('is not applied when null', () {
      expect(Loggable.objectToString('secret'), '"secret"');
      expect(Loggable.objectToJson('secret'), 'secret');
    });

    test('replaces the root value in both outputs', () {
      Loggable.sanitizer = (ctx) => '***';

      expect(Loggable.objectToString('secret'), '"***"');
      expect(Loggable.objectToJson('secret'), '***');
    });

    test('sees the root as an unnamed value at depth 0', () {
      final seen = <SanitizeContext>[];
      Loggable.sanitizer = (ctx) {
        seen.add(ctx);

        return ctx.value;
      };

      Loggable.objectToString('secret');

      expect(seen.single.name, isNull);
      expect(seen.single.value, 'secret');
      expect(seen.single.depth, 0);
      expect(seen.single.path, isEmpty);
    });

    test('drop at the root renders empty', () {
      Loggable.sanitizer = (ctx) => Sanitize.drop;

      expect(Loggable.objectToString('secret'), isEmpty);
      expect(Loggable.objectToJson('secret'), isNull);
    });

    test('is applied exactly once per rendered value', () {
      var calls = 0;
      Loggable.sanitizer = (ctx) {
        calls++;

        return ctx.value;
      };

      Loggable.objectToString('secret');

      expect(calls, 1);
    });
  });
}
