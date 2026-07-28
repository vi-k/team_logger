import 'dart:convert';

import 'package:team_logger/team_logger.dart';
import 'package:test/test.dart';

final class _Node with Loggable {
  final String name;
  _Node? next;

  _Node(this.name);

  @override
  void collectLoggableData(LoggableData data) => data
    ..prop('name', name)
    ..prop('next', next);
}

void main() {
  group('cycle protection in objectToString', () {
    test('self-referencing list', () {
      final list = <Object?>[1];
      list.add(list);

      final result = Loggable.objectToString(list);

      expect(result, contains('...'));
      expect(result, contains('1'));
    });

    test('self-referencing map', () {
      final map = <String, Object?>{'a': 1};
      map['self'] = map;

      final result = Loggable.objectToString(map);

      expect(result, contains('...'));
    });

    test('indirect cycle through list and map', () {
      final list = <Object?>[];
      final map = <String, Object?>{'list': list};
      list.add(map);

      expect(() => Loggable.objectToString(list), returnsNormally);
    });

    test('self-referencing Loggable', () {
      final node = _Node('a');
      node.next = node;

      final result = Loggable.objectToString(node);

      expect(result, contains('...'));
      expect(result, contains('a'));
    });

    test('shared non-cyclic references are not marked as cycles', () {
      final shared = <Object?>[1, 2];
      final root = <Object?>[shared, shared];

      final result = Loggable.objectToString(root);

      expect(result, isNot(contains('...')));
      expect('...'.allMatches(result), isEmpty);
    });
  });

  group('cycle protection in objectToJson', () {
    test('self-referencing list encodes to valid JSON with cycle marker', () {
      final list = <Object?>[1];
      list.add(list);

      final json = Loggable.objectToJson(list);
      final encoded = jsonEncode(json);

      expect(encoded, contains('"cycle"'));
    });

    test('self-referencing map encodes to valid JSON', () {
      final map = <String, Object?>{'a': 1};
      map['self'] = map;

      expect(() => jsonEncode(Loggable.objectToJson(map)), returnsNormally);
    });

    test('self-referencing Loggable encodes to valid JSON', () {
      final node = _Node('a');
      node.next = node;

      final encoded = jsonEncode(Loggable.objectToJson(node));

      expect(encoded, contains('"cycle"'));
    });

    test('shared non-cyclic references are not marked as cycles', () {
      final shared = <Object?>[1, 2];
      final root = <Object?>[shared, shared];

      final encoded = jsonEncode(Loggable.objectToJson(root));

      expect(encoded, isNot(contains('cycle')));
    });
  });
}
