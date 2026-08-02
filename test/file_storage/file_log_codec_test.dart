import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:team_logger/src/file_storage/file_log_codec.dart';
import 'package:team_logger/team_logger.dart';
import 'package:test/test.dart';

final class _CapturePublisher implements CustomLogPublisher<Log> {
  final logs = <Log>[];

  @override
  void publish(Log log) => logs.add(log);
}

Log _makeLog(void Function(Logger log) emit) {
  final publisher = _CapturePublisher();
  final logger = Logger('app')
    ..level = LogLevels.all
    ..publisher = publisher;
  emit(logger);
  return publisher.logs.single;
}

Map<String, Object?> _decode(String line) =>
    jsonDecode(line) as Map<String, Object?>;

/// An error object that is also [Loggable] — the codec writes it with
/// `toString()`, outside the walkers.
final class _Boom with Loggable implements Exception {
  @override
  void collectLoggableData(LoggableData data) => data.prop('code', 'E42');
}

/// A tag object that is also [Loggable]: `LazyTags` turns it into a string
/// with `toString()`.
final class _Tag with Loggable {
  final String value;

  _Tag(this.value);

  @override
  void collectLoggableData(LoggableData data) => data.prop('v', value);
}

/// A stack trace that is also [Loggable] — the codec writes it with
/// `toString()`, outside the walkers.
final class _Trace with Loggable implements StackTrace {
  @override
  void collectLoggableData(LoggableData data) => data.prop('at', 'main');
}

void main() {
  group('FileLogCodec.encode', () {
    test('encodes full schema', () {
      final time = DateTime(2026, 7, 27, 14, 30, 59, 482, 913);
      late Log log;
      withClock(Clock.fixed(time), () {
        log = _makeLog(
          (l) => l.i(
            'GET /users',
            traceId: const TraceId.manual('req', 7),
            data: {'status': 200},
            tags: 'http',
            error: Exception('boom'),
            stackTrace: StackTrace.fromString('#0 main (file.dart:1)'),
          ),
        );
      });

      final map = _decode(FileLogCodec().encode(log));

      expect(map['num'], log.num);
      expect(map['level'], LogLevels.info);
      expect(map['levelName'], log.levelName);
      expect(map['time'], time.toUtc().toIso8601String());
      expect(map['path'], 'app');
      expect(map['traceIds'], ['req-7']);
      expect(map['message'], 'GET /users');
      expect(map['tags'], ['http']);
      expect(
        map['data'],
        Loggable.objectToString(
          {'status': 200},
          theme: LogMainTheme.noColors[LogLevels.info],
        ),
      );
      expect(map['error'], 'Exception: boom');
      expect(map['stackTrace'], contains('#0'));
    });

    test('omits empty fields', () {
      final log = _makeLog((l) => l.d('hello'));

      final map = _decode(FileLogCodec().encode(log));

      expect(
        map.keys,
        unorderedEquals(
          ['num', 'level', 'levelName', 'time', 'path', 'message'],
        ),
      );
    });

    test('encodes data as json in json mode', () {
      final log = _makeLog((l) => l.i('m', data: {'status': 200}));

      final map = _decode(
        FileLogCodec(dataFormat: FileLogDataFormat.json).encode(log),
      );

      expect(map['data'], Loggable.objectToJson({'status': 200}));
    });

    test('preserves ANSI codes with colored theme', () {
      final log = _makeLog((l) => l.e('[b]bold[/b]', data: {'a': 1}));

      final map = _decode(
        FileLogCodec(theme: LogMainTheme.defaultActiveTheme).encode(log),
      );

      expect(map['message'], contains('\x1B['));
      expect(map['data'], contains('\x1B['));
    });

    test('keeps BBCode literal with default noColors theme', () {
      final log = _makeLog((l) => l.i('[b]bold[/b]'));

      final map = _decode(FileLogCodec().encode(log));

      expect(map['message'], '[b]bold[/b]');
    });

    test('strips BBCode with noColorsNoTags theme', () {
      final log = _makeLog((l) => l.i('[b]bold[/b]'));

      final map = _decode(
        FileLogCodec(theme: LogMainTheme.noColorsNoTags).encode(log),
      );

      expect(map['message'], 'bold');
    });

    test('produces a single line', () {
      final log = _makeLog((l) => l.i('a\nb', data: {'x': 'y\nz'}));

      expect(FileLogCodec().encode(log), isNot(contains('\n')));
    });
  });

  group('FileLogCodec — the sanitizer scope', () {
    tearDown(() => Loggable.sanitizer = null);

    test('a root drop rule does not erase a Loggable error', () {
      // `error` is outside the sanitizer's documented scope: the codec
      // writes it with `toString()`, and a root rule must not be able to
      // blank out the only reason the log exists.
      Loggable.sanitizer = (ctx) => ctx.depth == 0 ? Sanitize.drop : ctx.value;

      final log = _makeLog((l) => l.i('m', data: {'k': 1}, error: _Boom()));

      final map = _decode(FileLogCodec().encode(log));
      expect(map['error'], '_Boom(code: "E42")');
    });

    test('a root replacement rule leaves a Loggable error unchanged', () {
      Loggable.sanitizer = (ctx) => ctx.depth == 0 ? '***' : ctx.value;

      final log = _makeLog((l) => l.i('m', error: _Boom()));

      final map = _decode(FileLogCodec().encode(log));
      expect(map['error'], '_Boom(code: "E42")');
    });

    test('a root rule does not rewrite the tags', () {
      Loggable.sanitizer = (ctx) => ctx.depth == 0 ? '***' : ctx.value;

      final log = _makeLog((l) => l.i('m', tags: [_Tag('t')]));

      expect(_decode(FileLogCodec().encode(log))['tags'], ['_Tag(v: "t")']);
    });

    test('a root rule still applies to the data', () {
      Loggable.sanitizer = (ctx) => ctx.depth == 0 ? '***' : ctx.value;

      final log = _makeLog((l) => l.i('m', data: {'k': 'topsecret'}));

      expect(_decode(FileLogCodec().encode(log))['data'], '"***"');
    });

    test('a root drop rule does not erase a Loggable stack trace', () {
      Loggable.sanitizer = (ctx) => ctx.depth == 0 ? Sanitize.drop : ctx.value;

      final log = _makeLog((l) => l.i('m', stackTrace: _Trace()));

      final map = _decode(FileLogCodec().encode(log));
      expect(map['stackTrace'], '_Trace(at: "main")');
    });

    test('a root replacement rule leaves a Loggable stack trace alone', () {
      Loggable.sanitizer = (ctx) => ctx.depth == 0 ? '***' : ctx.value;

      final log = _makeLog((l) => l.i('m', stackTrace: _Trace()));

      final map = _decode(FileLogCodec().encode(log));
      expect(map['stackTrace'], '_Trace(at: "main")');
    });

    test('the error and the tags are unchanged without a rule', () {
      final log = _makeLog(
        (l) => l.i('m', error: _Boom(), tags: [_Tag('t')]),
      );

      final map = _decode(FileLogCodec().encode(log));
      expect(map['error'], '_Boom(code: "E42")');
      expect(map['tags'], ['_Tag(v: "t")']);
    });
  });

  group('FileLogCodec.encodeMeta', () {
    test('writes auto fields and user fields', () {
      final line = FileLogCodec().encodeMeta(
        sessionId: 's1',
        started: DateTime.utc(2026, 7, 27, 9, 30, 59, 482, 913),
        meta: {'appVersion': '1.2.3'},
      );

      final map = _decode(line);
      expect(map.keys, [FileLogCodec.metaKey]);

      final metaObj = map[FileLogCodec.metaKey]! as Map<String, Object?>;
      expect(metaObj['sessionId'], 's1');
      expect(metaObj['started'], '2026-07-27T09:30:59.482913Z');
      expect(metaObj['appVersion'], '1.2.3');
    });

    test('reserved keys win over user meta, time converted to UTC', () {
      final started = DateTime(2026, 7, 27, 14, 30);
      final line = FileLogCodec().encodeMeta(
        sessionId: 's1',
        started: started,
        meta: {'sessionId': 'hacked', 'started': 'hacked'},
      );

      final metaObj =
          _decode(line)[FileLogCodec.metaKey]! as Map<String, Object?>;
      expect(metaObj['sessionId'], 's1');
      expect(metaObj['started'], started.toUtc().toIso8601String());
    });

    test('survives non-encodable meta values', () {
      final line = FileLogCodec().encodeMeta(
        sessionId: 's1',
        started: DateTime.utc(2026),
        meta: {'device': Object(), 'ratio': double.nan},
      );

      expect(line, isNot(contains('\n')));
      final metaObj =
          _decode(line)[FileLogCodec.metaKey]! as Map<String, Object?>;
      expect(metaObj['sessionId'], 's1');
      expect(metaObj['started'], '2026-01-01T00:00:00.000Z');
    });

    test('produces a single line without meta', () {
      final line = FileLogCodec().encodeMeta(
        sessionId: 's1',
        started: DateTime.utc(2026),
      );

      expect(line, isNot(contains('\n')));
      final metaObj =
          _decode(line)[FileLogCodec.metaKey]! as Map<String, Object?>;
      expect(metaObj.keys, unorderedEquals(['sessionId', 'started']));
    });
  });
}
