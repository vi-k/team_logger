import 'package:team_logger/team_logger.dart';
import 'package:test/test.dart';

final class _Point with Loggable {
  @override
  void collectLoggableData(LoggableData data) {
    data.prop('x', 1);
  }
}

void main() {
  group('LoggableData.name', () {
    test('returns the name given to the builder', () {
      final data = Loggable.builder(0, name: 'Point')..prop('x', 1);
      expect(data.name, 'Point');
    });

    test('falls back to the type when no name was given', () {
      expect(_Point().logClassInfo().name, '_Point');
    });

    test('reads back what the setter wrote', () {
      final data = Loggable.builder(0, name: 'Point')
        ..prop('x', 1)
        ..name = 'Renamed';
      expect(data.name, 'Renamed');
    });

    test('is the name the output shows', () {
      final data = Loggable.builder(0)..prop('x', 1);

      expect(data.toLogString(), startsWith(data.name));
      expect(
        (Loggable.objectToJson(data)! as Map)[':c'],
        data.name,
      );

      data.name = 'Renamed';

      expect(data.toLogString(), startsWith(data.name));
      expect(
        (Loggable.objectToJson(data)! as Map)[':c'],
        data.name,
      );
    });
  });

  group('LoggableData flags', () {
    test('showName reads back what the setter wrote', () {
      final data = Loggable.builder(0, name: 'Point')..prop('x', 1);
      expect(data.showName, isTrue);
      data.showName = false;
      expect(data.showName, isFalse);
      expect(data.toLogString(), '(x: 1)');
    });

    test('showBrackets reads back what the setter wrote', () {
      final data = Loggable.builder(0, name: 'Point')..prop('x', 1);
      expect(data.showBrackets, isTrue);
      data.showBrackets = false;
      expect(data.showBrackets, isFalse);
      expect(data.toLogString(), 'Pointx: 1');
    });
  });
}
