import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:team_logger/src/file_storage/file_log_codec.dart';
import 'package:team_logger/src/file_storage/file_log_sessions.dart';
import 'package:team_logger/src/file_storage/file_log_storage.dart';
import 'package:team_logger/team_logger.dart';
import 'package:test/test.dart';

const _timeout = Duration(seconds: 5);

final class _Bomb {
  @override
  String toString() => throw StateError('bomb');
}

Logger _logger(FileLogStorage storage) => Logger('app')
  ..level = LogLevels.all
  ..publisher = storage;

List<String> _lines(File file) =>
    const LineSplitter().convert(file.readAsStringSync());

Map<String, Object?> _json(String line) =>
    jsonDecode(line) as Map<String, Object?>;

Future<bool> _createLinkOrSkip(Link link, String target) async {
  try {
    await link.create(target);
    return true;
  } on FileSystemException catch (error) {
    markTestSkipped('Symlink creation is unavailable: $error');
    return false;
  }
}

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('team_logger_test');
  });

  tearDown(() async {
    if (tmp.existsSync()) {
      await tmp.delete(recursive: true);
    }
  });

  File oldChunk(
    String name,
    int size, {
    required Duration age,
  }) =>
      File('${tmp.path}/$name')
        ..writeAsStringSync('x' * size)
        ..setLastModifiedSync(DateTime.now().subtract(age));

  group('FileLogStorage cleanup', () {
    test('deletes sessions older than maxAge on startup', () async {
      oldChunk('old.1.jsonl', 10, age: const Duration(days: 10));
      oldChunk('old.2.jsonl', 10, age: const Duration(days: 8));
      oldChunk('fresh.1.jsonl', 10, age: const Duration(hours: 1));

      final storage = FileLogStorage(directory: tmp.path, sessionId: 's1');
      await storage.ready;

      expect(File('${tmp.path}/old.1.jsonl').existsSync(), isFalse);
      expect(File('${tmp.path}/old.2.jsonl').existsSync(), isFalse);
      expect(File('${tmp.path}/fresh.1.jsonl').existsSync(), isTrue);

      await storage.close();
    });

    test('keeps a session whose newest chunk is fresh', () async {
      oldChunk('s0.1.jsonl', 10, age: const Duration(days: 10));
      oldChunk('s0.2.jsonl', 10, age: const Duration(hours: 1));

      final storage = FileLogStorage(directory: tmp.path, sessionId: 's1');
      await storage.ready;

      expect(File('${tmp.path}/s0.1.jsonl').existsSync(), isTrue);
      expect(File('${tmp.path}/s0.2.jsonl').existsSync(), isTrue);

      await storage.close();
    });

    test('maxAge null disables TTL cleanup', () async {
      oldChunk('old.1.jsonl', 10, age: const Duration(days: 365));

      final storage = FileLogStorage(
        directory: tmp.path,
        sessionId: 's1',
        maxAge: null,
      );
      await storage.ready;

      expect(File('${tmp.path}/old.1.jsonl').existsSync(), isTrue);

      await storage.close();
    });

    test('maxTotalSize deletes oldest sessions keeping a reserve', () async {
      oldChunk('a.1.jsonl', 1500, age: const Duration(days: 3));
      oldChunk('b.1.jsonl', 1500, age: const Duration(days: 2));
      oldChunk('c.1.jsonl', 900, age: const Duration(days: 1));

      final storage = FileLogStorage(
        directory: tmp.path,
        sessionId: 's1',
        maxSessionSize: 1000,
        maxChunkSize: 500,
        maxTotalSize: 3000,
      );
      await storage.ready;

      // Разрешено для старых сессий: 3000 - 1000 (резерв) = 2000 байт.
      expect(File('${tmp.path}/a.1.jsonl').existsSync(), isFalse);
      expect(File('${tmp.path}/b.1.jsonl').existsSync(), isFalse);
      expect(File('${tmp.path}/c.1.jsonl').existsSync(), isTrue);

      await storage.close();
    });

    test('cleanup ignores foreign files', () async {
      final foreign = File('${tmp.path}/notes.txt')
        ..writeAsStringSync('x' * 5000)
        ..setLastModifiedSync(
          DateTime.now().subtract(const Duration(days: 30)),
        );

      final storage = FileLogStorage(
        directory: tmp.path,
        sessionId: 's1',
        maxSessionSize: 500,
        maxChunkSize: 250,
        maxTotalSize: 1000,
      );
      await storage.ready;

      expect(foreign.existsSync(), isTrue);

      await storage.close();
    });

    test('startup cleanup ignores symlinks with chunk names', () async {
      // Mutation: removing the no-follow check lets cleanup remove the link.
      final victim = File('${tmp.path}/victim.txt')
        ..writeAsStringSync('outside-secret')
        ..setLastModifiedSync(
          DateTime.now().subtract(const Duration(days: 30)),
        );
      final link = Link('${tmp.path}/old.1.jsonl');
      if (!await _createLinkOrSkip(link, victim.path)) return;

      final storage = FileLogStorage(
        directory: tmp.path,
        sessionId: 'current',
        maxAge: const Duration(days: 7),
      );
      await storage.ready;

      expect(
        FileSystemEntity.typeSync(link.path, followLinks: false),
        FileSystemEntityType.link,
      );
      expect(victim.readAsStringSync(), 'outside-secret');
      await storage.close();
    });
  });

  group('FileLogStorage', () {
    test('writes published logs to the first chunk with a meta line', () async {
      final storage = FileLogStorage(
        directory: tmp.path,
        sessionId: 's1',
        meta: {'app': 'demo'},
      );
      _logger(storage)
        ..i('first')
        ..w('second');
      await storage.flush().timeout(_timeout);

      final file = File('${tmp.path}/s1.1.jsonl');
      expect(file.existsSync(), isTrue);

      final lines = _lines(file);
      expect(lines, hasLength(3));

      final meta =
          _json(lines[0])[FileLogCodec.metaKey]! as Map<String, Object?>;
      expect(meta['sessionId'], 's1');
      expect(meta['app'], 'demo');
      expect(_json(lines[1])['message'], 'first');
      expect(_json(lines[2])['message'], 'second');

      await storage.close();
    });

    test('flush completes when nothing was published', () async {
      final storage = FileLogStorage(directory: tmp.path);

      await storage.flush().timeout(_timeout);

      // flush also guarantees initialization: the first chunk with the
      // meta line is already on disk.
      final chunks = Directory(tmp.path)
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.1.jsonl'))
          .toList();
      expect(chunks, hasLength(1));
      expect(_lines(chunks.single), hasLength(1));

      await storage.close();
    });

    test('minLevel filters out lower levels', () async {
      final storage = FileLogStorage(
        directory: tmp.path,
        sessionId: 's1',
        minLevel: LogLevels.warning,
      );
      _logger(storage)
        ..i('skipped')
        ..e('kept');
      await storage.flush().timeout(_timeout);

      final lines = _lines(File('${tmp.path}/s1.1.jsonl'));
      expect(lines, hasLength(2));
      expect(_json(lines[1])['message'], 'kept');

      await storage.close();
    });

    test('default sessionId is derived from the start time', () async {
      final time = DateTime(2026, 7, 27, 14, 30, 59, 482, 913);
      late FileLogStorage storage;
      withClock(Clock.fixed(time), () {
        storage = FileLogStorage(directory: tmp.path);
      });

      expect(storage.sessionId, defaultSessionId(time));

      await storage.close();
    });

    test('custom sessionId is sanitized', () async {
      final storage = FileLogStorage(
        directory: tmp.path,
        sessionId: 'my session.1',
      );

      expect(storage.sessionId, 'my_session_1');

      await storage.close();
    });

    test('sessionId collision gets a numeric suffix', () async {
      File('${tmp.path}/s1.1.jsonl').writeAsStringSync('{}\n');
      File('${tmp.path}/s1-1.1.jsonl').writeAsStringSync('{}\n');

      final storage = FileLogStorage(directory: tmp.path, sessionId: 's1');
      await storage.ready;

      expect(storage.sessionId, 's1-2');

      _logger(storage).i('x');
      await storage.flush().timeout(_timeout);
      expect(File('${tmp.path}/s1-2.1.jsonl').existsSync(), isTrue);

      await storage.close();
    });

    test('reports the error once and disables itself on unusable directory',
        () async {
      File('${tmp.path}/blocked').writeAsStringSync('');

      final reports = <Object>[];
      final storage = FileLogStorage(
        directory: '${tmp.path}/blocked/dir',
        onError: (error, stackTrace) => reports.add(error),
      );
      final log = _logger(storage);
      log.i('x');
      await storage.flush().timeout(_timeout);
      log.i('y');
      await storage.flush().timeout(_timeout);

      // Одна ошибка инициализации; последующие публикации молча
      // отбрасываются без новых ошибок.
      expect(reports, hasLength(1));

      await storage.close();
    });

    test('close writes pending logs', () async {
      final storage = FileLogStorage(directory: tmp.path, sessionId: 's1');
      _logger(storage).i('pending');
      await storage.close();

      final lines = _lines(File('${tmp.path}/s1.1.jsonl'));
      expect(lines, hasLength(2));
      expect(_json(lines[1])['message'], 'pending');
    });

    test('close waits for initialization before it completes', () async {
      // Mutation: removing `await ready` from close lets it return while
      // initialization can still recreate the directory and first chunk.
      final logs = Directory('${tmp.path}/logs');
      final storage = FileLogStorage(directory: logs.path, sessionId: 's1');
      var readyCompleted = false;
      unawaited(storage.ready.whenComplete(() => readyCompleted = true));

      final firstClose = storage.close();
      final secondClose = storage.close();
      expect(identical(firstClose, secondClose), isTrue);
      await firstClose.timeout(_timeout);

      expect(readyCompleted, isTrue);
      expect(File('${logs.path}/s1.1.jsonl').existsSync(), isTrue);
      await logs.delete(recursive: true);
      await storage.ready;
      expect(logs.existsSync(), isFalse);
    });

    test('rotates chunks and deletes the oldest, keeping the tail', () async {
      final storage = FileLogStorage(
        directory: tmp.path,
        sessionId: 's1',
        maxSessionSize: 1200,
        maxChunkSize: 600,
      );
      final log = _logger(storage);
      final chunk1 = File('${tmp.path}/s1.1.jsonl');
      final chunk2 = File('${tmp.path}/s1.2.jsonl');

      var i = 0;
      while (!chunk2.existsSync() && i < 20) {
        log.i('msg$i ${'x' * 100}');
        await storage.flush().timeout(_timeout);
        i++;
      }
      expect(chunk2.existsSync(), isTrue, reason: 'rotation did not happen');
      expect(_lines(chunk2).first, contains(FileLogCodec.metaKey));

      while (chunk1.existsSync() && i < 40) {
        log.i('msg$i ${'x' * 100}');
        await storage.flush().timeout(_timeout);
        i++;
      }
      expect(
        chunk1.existsSync(),
        isFalse,
        reason: 'oldest chunk was not deleted',
      );

      final session = (await storage.sessions.list()).single;
      expect(await session.readAsString(), contains('msg${i - 1} '));

      await storage.close();
    });

    test('a line longer than the chunk target is written whole', () async {
      final storage = FileLogStorage(
        directory: tmp.path,
        sessionId: 's1',
        maxSessionSize: 1200,
        maxChunkSize: 600,
      );
      final log = _logger(storage);

      log.i('y' * 2000);
      await storage.flush().timeout(_timeout);

      final chunk1 = File('${tmp.path}/s1.1.jsonl');
      expect(_lines(chunk1), hasLength(2));
      expect(chunk1.lengthSync(), greaterThan(1200));

      log.i('after');
      await storage.flush().timeout(_timeout);

      expect(chunk1.existsSync(), isFalse);
      final chunk2 = File('${tmp.path}/s1.2.jsonl');
      expect(_lines(chunk2), hasLength(2));
      expect(_json(_lines(chunk2)[1])['message'], 'after');

      await storage.close();
    });

    test('skips a symlink occupying the next chunk path', () async {
      // Mutation: path-based append follows the link and changes victim.
      final reports = <Object>[];
      final storage = FileLogStorage(
        directory: tmp.path,
        sessionId: 's1',
        maxSessionSize: 1200,
        maxChunkSize: 600,
        onError: (error, stackTrace) => reports.add(error),
      );
      final log = _logger(storage);
      await storage.ready;

      log.i('x' * 700);
      await storage.flush().timeout(_timeout);
      final victim = File('${tmp.path}/victim.txt')
        ..writeAsStringSync('outside');
      if (!await _createLinkOrSkip(
        Link('${tmp.path}/s1.2.jsonl'),
        victim.path,
      )) {
        await storage.close();
        return;
      }

      log.i('safe');
      await storage.flush().timeout(_timeout);

      expect(victim.readAsStringSync(), 'outside');
      expect(
        File('${tmp.path}/s1.3.jsonl').readAsStringSync(),
        contains('safe'),
      );
      expect(reports, hasLength(1));
      await storage.close();
    });

    test(
      'keeps writing to the opened chunk after its path is replaced',
      () async {
        // Mutation: reopening by path follows the replacement symlink.
        final logs = Directory('${tmp.path}/logs');
        final storage = FileLogStorage(directory: logs.path, sessionId: 's1');
        final log = _logger(storage);
        await storage.ready;

        final chunk = File('${logs.path}/s1.1.jsonl');
        final detached = await chunk.rename('${tmp.path}/detached.jsonl');
        final victim = File('${tmp.path}/victim.txt')
          ..writeAsStringSync('outside');
        if (!await _createLinkOrSkip(Link(chunk.path), victim.path)) {
          await storage.close();
          return;
        }

        log.i('safe');
        await storage.flush().timeout(_timeout);

        expect(victim.readAsStringSync(), 'outside');
        expect(detached.readAsStringSync(), contains('safe'));
        await storage.close();
      },
      skip: Platform.isWindows ? 'Windows may not rename an opened file' : null,
    );

    test('exposes sessions reader for its directory', () async {
      final storage = FileLogStorage(directory: tmp.path, sessionId: 's1');
      _logger(storage).i('x');
      await storage.flush().timeout(_timeout);

      final sessions = await storage.sessions.list();
      expect(sessions.map((s) => s.id), ['s1']);

      await storage.close();
    });
  });

  group('FileLogStorage robustness', () {
    test('non-encodable meta does not block writing', () async {
      final storage = FileLogStorage(
        directory: tmp.path,
        sessionId: 's1',
        meta: {'device': Object()},
      );
      _logger(storage).i('alive');
      await storage.flush().timeout(_timeout);

      final lines = _lines(File('${tmp.path}/s1.1.jsonl'));
      expect(_json(lines.last)['message'], 'alive');
      final meta =
          _json(lines.first)[FileLogCodec.metaKey]! as Map<String, Object?>;
      expect(meta['sessionId'], 's1');

      await storage.close();
    });

    test('a log that fails to encode does not lose its batch neighbors',
        () async {
      final reports = <Object>[];
      final storage = FileLogStorage(
        directory: tmp.path,
        sessionId: 's1',
        onError: (error, stackTrace) => reports.add(error),
      );
      _logger(storage)
        ..i('one')
        ..i('two', data: _Bomb())
        ..i('three');
      await storage.flush().timeout(_timeout);

      final lines = _lines(File('${tmp.path}/s1.1.jsonl'));
      expect(lines, hasLength(4));
      expect(_json(lines[1])['message'], 'one');
      // Только тип ошибки: её текст может нести те самые данные, ради
      // сокрытия которых правило и бросило (см. тест ниже).
      expect(_json(lines[2])['encodeError'], 'StateError');
      expect(_json(lines[3])['message'], 'three');
      expect(reports, hasLength(1));
      expect(reports.single.toString(), contains('bomb'));

      await storage.close();
    });

    test('an encode error carrying a secret is not written to the file',
        () async {
      // ArgumentError.value(ctx.value) — совершенно естественная форма
      // отказа для правила: до фикса fallback-строка писала в JSONL
      // текст исключения вместе с секретом.
      addTearDown(() => Loggable.sanitizer = null);
      Loggable.sanitizer = (ctx) => ctx.name == 'password'
          ? throw ArgumentError.value(ctx.value, 'value')
          : ctx.value;

      final reports = <Object>[];
      final storage = FileLogStorage(
        directory: tmp.path,
        sessionId: 's1',
        onError: (error, stackTrace) => reports.add(error),
      );
      _logger(storage).i('login', data: {'password': 'hunter2'});
      await storage.flush().timeout(_timeout);

      final content = File('${tmp.path}/s1.1.jsonl').readAsStringSync();
      expect(content, isNot(contains('hunter2')));

      final lines = _lines(File('${tmp.path}/s1.1.jsonl'));
      expect(_json(lines[1])['encodeError'], 'ArgumentError');
      // Полная информация — только в onError.
      expect(reports.single.toString(), contains('hunter2'));

      await storage.close();
    });

    test('throwing onError does not break writing or flush', () async {
      final storage = FileLogStorage(
        directory: tmp.path,
        sessionId: 's1',
        onError: (error, stackTrace) => throw StateError('user error'),
      );
      _logger(storage)
        ..i('one', data: _Bomb())
        ..i('two');
      await storage.flush().timeout(_timeout);

      final lines = _lines(File('${tmp.path}/s1.1.jsonl'));
      expect(_json(lines.last)['message'], 'two');

      await storage.close();
    });

    test('publish after close is a silent no-op', () async {
      final storage = FileLogStorage(directory: tmp.path, sessionId: 's1');
      final log = _logger(storage);
      log.i('before');
      await storage.close();

      expect(() => log.i('after1'), returnsNormally);
      expect(() => log.i('after2'), returnsNormally);
      await storage.flush().timeout(_timeout);

      final lines = _lines(File('${tmp.path}/s1.1.jsonl'));
      expect(lines, hasLength(2));
      expect(_json(lines.last)['message'], 'before');
    });

    test('reserves the first chunk with a meta line at init', () async {
      final storage = FileLogStorage(directory: tmp.path, sessionId: 's1');
      await storage.ready;

      final lines = _lines(File('${tmp.path}/s1.1.jsonl'));
      expect(lines, hasLength(1));
      expect(_json(lines.single), contains(FileLogCodec.metaKey));

      await storage.close();
    });

    test('two storages with the same sessionId get distinct sessions',
        () async {
      final a = FileLogStorage(directory: tmp.path, sessionId: 'main');
      final b = FileLogStorage(directory: tmp.path, sessionId: 'main');
      await a.ready;
      await b.ready;

      expect({a.sessionId, b.sessionId}, hasLength(2));

      _logger(a).i('from A');
      await a.flush().timeout(_timeout);
      _logger(b).i('from B');
      await b.flush().timeout(_timeout);

      final aLines = _lines(File('${tmp.path}/${a.sessionId}.1.jsonl'));
      final bLines = _lines(File('${tmp.path}/${b.sessionId}.1.jsonl'));
      expect(_json(aLines.last)['message'], 'from A');
      expect(_json(bLines.last)['message'], 'from B');

      await a.close();
      await b.close();
    });

    test('splits a large batch into chunks and keeps the tail', () async {
      final storage = FileLogStorage(
        directory: tmp.path,
        sessionId: 's1',
        maxSessionSize: 1200,
        maxChunkSize: 600,
      );
      final log = _logger(storage);
      for (var i = 0; i < 50; i++) {
        log.i('msg$i ${'x' * 80}');
      }
      await storage.flush().timeout(_timeout);

      final session = (await storage.sessions.list()).single;
      final lastIndex =
          parseChunkName(session.files.last.uri.pathSegments.last)!.index;
      // Один батч разрезан на несколько чанков, а не записан целиком.
      expect(lastIndex, greaterThanOrEqualTo(3));
      // Хвост сессии в пределах лимита (плюс одна строка сверх target).
      expect(session.size, lessThanOrEqualTo(1200 + 400));
      expect(await session.readAsString(), contains('msg49 '));

      await storage.close();
    });

    test('recovers into a new chunk after chunk creation failure', () async {
      final reports = <Object>[];
      final logs = Directory('${tmp.path}/logs');
      final storage = FileLogStorage(
        directory: logs.path,
        sessionId: 's1',
        maxSessionSize: 1200,
        maxChunkSize: 600,
        onError: (error, stackTrace) => reports.add(error),
      );
      final log = _logger(storage);
      log.i('x' * 700);
      await storage.flush().timeout(_timeout);

      final unavailable = await logs.rename('${tmp.path}/unavailable');
      log.i('lost');
      await storage.flush().timeout(_timeout);
      expect(reports, isNotEmpty);
      await unavailable.rename(logs.path);

      log.i('recovered');
      await storage.flush().timeout(_timeout);

      // Сбойный батч потерян по прежнему контракту; следующий пишет в
      // более поздний индекс и не склеивается с частичным JSONL.
      final recovered = File('${logs.path}/s1.3.jsonl');
      expect(recovered.existsSync(), isTrue);
      expect(_json(_lines(recovered).last)['message'], 'recovered');
      expect(recovered.readAsStringSync(), isNot(contains('lost')));

      await storage.close();
    });

    test('maxQueueSize refuses the newest logs and reports them', () async {
      final dropped = <Log>[];
      final storage = FileLogStorage(
        directory: tmp.path,
        sessionId: 's1',
        maxQueueSize: 1,
        onDropped: dropped.addAll,
      );
      final log = _logger(storage);

      // Очередь не разгружается, пока не провернётся event loop, так что
      // из трёх синхронных публикаций принята будет только первая.
      log.i('accepted');
      log.i('refused1');
      log.i('refused2');
      await storage.flush().timeout(_timeout);

      expect(
        dropped.map((log) => log.message),
        ['refused1', 'refused2'],
      );

      final lines = _lines(File('${tmp.path}/s1.1.jsonl'));
      expect(lines, hasLength(2));
      expect(_json(lines.last)['message'], 'accepted');

      await storage.close();
    });

    test('maxTotalSize must not be smaller than maxSessionSize', () {
      expect(
        () => FileLogStorage(
          directory: tmp.path,
          maxSessionSize: 1000,
          maxChunkSize: 500,
          maxTotalSize: 500,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('maxSessionSize must fit at least two chunks', () {
      expect(
        () => FileLogStorage(
          directory: tmp.path,
          maxSessionSize: 1000,
          maxChunkSize: 600,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
