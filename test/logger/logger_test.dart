import 'package:team_logger/team_logger.dart';
import 'package:test/test.dart';

final class _Capture implements CustomLogPublisher<Log> {
  final logs = <Log>[];

  @override
  void publish(Log log) => logs.add(log);
}

(Logger, _Capture) _logger([String name = 'app']) {
  final capture = _Capture();
  final logger = Logger(name)
    ..level = LogLevels.all
    ..publisher = capture;

  return (logger, capture);
}

void main() {
  group('zone trace propagation', () {
    test('logs inside trace pick up the trace id', () async {
      final (log, out) = _logger();
      const id = TraceId.manual('req', 1);

      await log.trace(id, () async {
        log.i('inside');
        await Future<void>.delayed(Duration.zero);
        log.i('after await');
      });
      log.i('outside');

      expect(out.logs[0].traceIds.map((e) => e.toString()), ['req-1']);
      expect(out.logs[1].traceIds.map((e) => e.toString()), ['req-1']);
      expect(out.logs[2].traceIds, isEmpty);
    });

    test('nested traces accumulate ids in order', () {
      final (log, out) = _logger();

      log.trace(const TraceId.manual('a', 1), () {
        log.trace(const TraceId.manual('b', 2), () {
          log.i('x');
        });
      });

      expect(
        out.logs.single.traceIds.map((e) => e.toString()),
        ['a-1', 'b-2'],
      );
    });

    test('trace tags merge with call tags', () {
      final (log, out) = _logger();

      log.trace(const TraceId.manual('a', 1), tags: {'zone'}, () {
        log.i('x', tags: 'call');
      });

      expect(out.logs.single.tags, containsAll(<String>{'zone', 'call'}));
    });

    test('trace zone does not leak after an exception', () {
      final (log, out) = _logger();

      expect(
        () => log.trace(const TraceId.manual('a', 1), () {
          throw StateError('boom');
        }),
        throwsStateError,
      );
      log.i('after');

      expect(out.logs.single.traceIds, isEmpty);
    });

    test('zonedTraceIds returns an unmodifiable view', () {
      final (log, _) = _logger();

      log.trace(const TraceId.manual('a', 1), () {
        final ids = Logger.zonedTraceIds();
        expect(
          () => ids.add(const TraceId.manual('b', 2)),
          throwsUnsupportedError,
        );
      });
    });

    test('zonedTags returns an unmodifiable view', () {
      final (log, _) = _logger();

      log.trace(const TraceId.manual('a', 1), tags: {'original'}, () {
        final tags = Logger.zonedTags();
        expect(() => tags.add('injected'), throwsUnsupportedError);
      });
    });

    test('a mutated zonedTags view cannot retag the rest of the zone', () {
      final (log, out) = _logger();

      log.trace(const TraceId.manual('a', 1), tags: {'original'}, () {
        expect(
          () => Logger.zonedTags().add('injected'),
          throwsUnsupportedError,
        );
        log.i('after');
      });

      expect(out.logs.single.tags, {'original'});
    });

    test('the caller keeps no writable handle on the zone tags', () {
      final (log, out) = _logger();
      final passed = {'original'};

      log.trace(const TraceId.manual('a', 1), tags: passed, () {
        passed.add('late');
        log.i('after');
      });

      expect(out.logs.single.tags, {'original'});
    });
  });

  group('TraceId', () {
    test('manual id formats as group-num', () {
      expect(const TraceId.manual('req', 7).toString(), 'req-7');
    });

    test('suffix is appended after a dot', () {
      final id = const TraceId.manual('req', 7).withSuffix('retry');

      expect(id.toString(), 'req-7.retry');
    });

    test('auto ids are not resolved for disabled levels', () {
      final (log, out) = _logger();
      log.level = LogLevels.warning;

      final before = TraceId.auto('lazy-group');
      log.d('disabled', traceId: before);
      log.w('enabled', traceId: TraceId.auto('lazy-group'));

      // The disabled log did not consume a number: the first resolve went to
      // the enabled log.
      expect(out.logs.single.traceIds.single.num, 1);
    });
  });

  group('logger hierarchy', () {
    test('createChild builds a path and inherits tags', () {
      final (log, out) = _logger();
      final child = log.createChild(name: 'net', tags: {'io'});

      child.i('x');

      expect(out.logs.single.path, 'app/net');
      expect(out.logs.single.tags, contains('io'));
    });

    test('a per-level publisher pins that level and leaves the rest linked',
        () {
      final (parent, parentOut) = _logger();
      final child = parent.createChild(name: 'net');
      final pinned = _Capture();

      child[LogLevels.error].publisher = pinned;

      child.i('info');
      child.e('error');

      expect(parentOut.logs.map((e) => e.message), ['info']);
      expect(pinned.logs.map((e) => e.message), ['error']);
      expect(child.publisherLinked, isTrue);

      // A pinned level does not detach the child as a whole: replacing the
      // parent's publisher still reaches the remaining levels.
      final replaced = _Capture();
      parent.publisher = replaced;

      child.i('after');
      child.e('after error');

      expect(replaced.logs.map((e) => e.message), ['after']);
      expect(
        pinned.logs.map((e) => e.message),
        ['error', 'after error'],
      );
    });

    test('copyWith keeps the path without extending it', () {
      final (log, out) = _logger();
      final copy = log.copyWith(tags: {'copy'});

      copy.i('x');

      expect(out.logs.single.path, 'app');
      expect(out.logs.single.tags, contains('copy'));
    });

    test('disabled level does not resolve the lazy message', () {
      final (log, _) = _logger();
      log.level = LogLevels.warning;

      var resolved = false;
      log.d(() {
        resolved = true;
        return 'lazy';
      });

      expect(resolved, isFalse);
    });

    test('resolves message and snapshots logger tags before lazy call tags',
        () {
      // Mutation: resolving call tags before path/message and before copying
      // logger tags changes side-effect order and the current log's snapshot.
      final order = <String>[];
      final loggerTags = <String>{};
      final out = _Capture();
      final log = Logger('app', tags: loggerTags)
        ..level = LogLevels.all
        ..publisher = out;

      log.i(
        () {
          order.add('message');
          return 'm';
        },
        tags: () {
          order.add('tags');
          loggerTags.add('late');
          return {'call'};
        },
      );

      expect(order, ['message', 'tags']);
      expect(out.logs.single.tags, {'call'});
      expect(loggerTags, {'late'});
    });
  });
}
