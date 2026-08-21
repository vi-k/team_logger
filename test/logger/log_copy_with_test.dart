import 'package:team_logger/team_logger.dart';
import 'package:test/test.dart';

void main() {
  group('Log.copyWith', () {
    Log capture(void Function(Logger logger) emit) {
      final logs = <Log>[];
      final logger = Logger('test')
        ..level = LogLevels.all
        ..publisher = CustomLogPublisher(logs.add);
      emit(logger);

      return logs.single;
    }

    test('no arguments: an equivalent copy, identity preserved', () {
      final original = capture(
        (log) => log.i(
          'hello',
          data: {'a': 1},
          tags: {'t'},
          error: StateError('boom'),
        ),
      );
      final before = Log.lastNum;
      final copy = original.copyWith();

      expect(Log.lastNum, before, reason: 'no new number is minted');
      expect(copy.num, original.num);
      expect(copy.time, original.time);
      expect(copy.level, original.level);
      expect(copy.levelName, original.levelName);
      expect(copy.zone, same(original.zone));
      expect(copy.path, original.path);
      expect(copy.message, original.message);
      expect(copy.data, same(original.data));
      // Performance characterization: an unchanged immutable snapshot is
      // reused instead of copied by every transformer.
      expect(copy.tags, same(original.tags));
      expect(copy.traceIds, same(original.traceIds));
      expect(copy.error, same(original.error));
      expect(copy.stackTrace, same(original.stackTrace));
    });

    test('replaces the message, keeps number and time', () {
      final original = capture((log) => log.i('token secret-1'));
      final copy = original.copyWith(message: 'token ***');

      expect(copy.message, 'token ***');
      expect(copy.num, original.num);
      expect(copy.time, original.time);
    });

    test('replaces and clears data', () {
      final original = capture((log) => log.i('m', data: {'pin': 1234}));

      final masked = original.copyWith(data: {'pin': '***'});
      expect(masked.data, {'pin': '***'});
      expect(masked.hasData, isTrue);

      final cleared = original.copyWith(data: Log.noData);
      expect(cleared.hasData, isFalse);
    });

    test('data can be set to null (a valid value)', () {
      final original = capture((log) => log.i('m', data: {'a': 1}));
      final copy = original.copyWith(data: null);

      expect(copy.data, isNull);
    });

    test('clears the error without re-deriving the stack trace', () {
      // У не-брошенного StateError stackTrace == null, поэтому трейс
      // передаётся явно — иначе утверждения были бы слепыми.
      final original = capture(
        (log) => log.e(
          'fail',
          error: StateError('secret'),
          stackTrace: StackTrace.current,
        ),
      );
      expect(original.stackTrace, isNotNull);

      final cleared = original.copyWith(error: null, stackTrace: null);
      expect(cleared.error, isNull);
      expect(cleared.stackTrace, isNull);
    });

    test('replacing the error keeps the original stack trace', () {
      final original = capture(
        (log) => log.e(
          'fail',
          error: StateError('secret'),
          stackTrace: StackTrace.current,
        ),
      );
      expect(original.stackTrace, isNotNull);

      final copy = original.copyWith(error: 'redacted');

      expect(copy.error, 'redacted');
      expect(copy.stackTrace, same(original.stackTrace));
    });

    test('replaces tags, path and traceIds; empty collections clear', () {
      final original = capture((log) => log.i('m', tags: {'a', 'b'}));
      final copy = original.copyWith(
        tags: const {},
        path: 'other',
        traceIds: const [TraceId.manual('req', 1)],
      );

      expect(copy.tags, isEmpty);
      expect(copy.path, 'other');
      expect(copy.traceIds, hasLength(1));

      final clearedTraces = copy.copyWith(traceIds: const []);
      expect(clearedTraces.traceIds, isEmpty);
    });

    test('snapshots replacement collections', () {
      // Mutation: assigning replacements directly lets their caller change
      // an already transformed log after copyWith returns.
      final original = capture((log) => log.i('m'));
      final tags = <String>{'original'};
      final traceIds = <TraceId>[const TraceId.manual('req', 1)];

      final copy = original.copyWith(tags: tags, traceIds: traceIds);
      tags.add('mutated');
      traceIds.add(const TraceId.manual('req', 2));

      expect(copy.tags, {'original'});
      expect(copy.traceIds.map((id) => id.toString()), ['req-1']);
    });

    test(
      'stackTrace rejects a value that is neither a StackTrace nor null',
      () {
        final original = capture((log) => log.i('m'));

        expect(
          () => original.copyWith(stackTrace: 'not a stack trace'),
          throwsA(isA<TypeError>()),
        );
      },
    );
  });

  group('Log collection snapshots', () {
    test('the public constructor snapshots mutable inputs', () {
      // Mutation: assigning constructor inputs directly lets their caller
      // change an already constructed log.
      final tags = <String>{'original'};
      final traceIds = <TraceId>[const TraceId.manual('req', 1)];
      final log = Log(
        LevelLogger(level: LogLevels.info, name: 'info'),
        path: 'test',
        traceIds: traceIds,
        message: 'm',
        data: Log.noData,
        tags: tags,
      );

      tags.add('mutated');
      traceIds.add(const TraceId.manual('req', 2));

      expect(log.tags, {'original'});
      expect(log.traceIds.map((id) => id.toString()), ['req-1']);
    });

    test('published collections cannot be mutated', () {
      // Mutation: exposing the owned List and Set directly lets one consumer
      // change what later publishers and storages observe.
      final logs = <Log>[];
      final logger = Logger('test')
        ..level = LogLevels.all
        ..publisher = CustomLogPublisher(logs.add);

      logger.i(
        'm',
        traceId: const TraceId.manual('req', 1),
        tags: {'original'},
      );
      final log = logs.single;

      expect(() => log.tags.add('mutated'), throwsUnsupportedError);
      expect(
        () => log.traceIds.add(const TraceId.manual('req', 2)),
        throwsUnsupportedError,
      );
    });
  });
}
