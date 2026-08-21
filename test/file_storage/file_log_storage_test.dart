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

    test('minLevel filters logs before they consume queue capacity', () async {
      final dropped = <Log>[];
      final storage = FileLogStorage(
        directory: tmp.path,
        sessionId: 's1',
        minLevel: LogLevels.warning,
        maxQueueSize: 1,
        onDropped: dropped.addAll,
      );
      _logger(storage)
        ..i('filtered')
        ..e('kept');
      await storage.flush().timeout(_timeout);

      expect(dropped, isEmpty);
      final lines = _lines(File('${tmp.path}/s1.1.jsonl'));
      expect(lines, hasLength(2));
      expect(_json(lines.last)['message'], 'kept');

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

    test('flush stays failed after initialization loses accepted logs',
        () async {
      File('${tmp.path}/blocked').writeAsStringSync('');

      final reports = <Object>[];
      final dropped = <Log>[];
      final storage = FileLogStorage(
        directory: '${tmp.path}/blocked/dir',
        onError: (error, stackTrace) => reports.add(error),
        onDropped: dropped.addAll,
      );
      final log = _logger(storage);
      log.i('x');
      await expectLater(
        storage.flush().timeout(_timeout),
        throwsA(isA<FileSystemException>()),
      );
      log.i('y');
      await expectLater(
        storage.flush().timeout(_timeout),
        throwsA(isA<FileSystemException>()),
      );

      // Initialization itself is reported once. Every accepted log is also
      // reported as dropped, without retrying a permanently disabled store.
      expect(reports, hasLength(1));
      expect(dropped.map((log) => log.message), ['x', 'y']);

      await expectLater(
        storage.close().timeout(_timeout),
        throwsA(isA<FileSystemException>()),
      );
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

    test('flush after close returns the full close future', () async {
      // Mutation: bypassing `_closeFuture` returns before the active handle
      // close that follows the base publisher drain.
      final logs = Directory('${tmp.path}/logs');
      final storage = FileLogStorage(directory: logs.path, sessionId: 's1');
      addTearDown(storage.close);
      _logger(storage).i('pending');

      final closeFuture = storage.close();
      final flushFuture = storage.flush();

      expect(identical(flushFuture, closeFuture), isTrue);
      await flushFuture.timeout(_timeout);
      await logs.delete(recursive: true);
      expect(logs.existsSync(), isFalse);
    });

    test('isClosed flips synchronously when close starts', () async {
      // Mutation: relying on the inherited getter keeps this false until
      // `_close()` reaches `super.close()` after awaiting initialization.
      final storage = FileLogStorage(directory: tmp.path, sessionId: 's1');
      expect(storage.isClosed, isFalse);

      final closeFuture = storage.close();

      expect(storage.isClosed, isTrue);
      await closeFuture.timeout(_timeout);
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

    test('skips an ordinary file occupying the next chunk path', () async {
      // Mutation: reopening or overwriting an occupied path changes its
      // contents instead of preserving the batch for the next free index.
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
      final occupied = File('${tmp.path}/s1.2.jsonl')
        ..writeAsStringSync('occupied');

      log.i('safe');
      await storage.flush().timeout(_timeout);

      expect(occupied.readAsStringSync(), 'occupied');
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

    test('deletes the current session after storage is closed', () async {
      final storage = FileLogStorage(directory: tmp.path, sessionId: 's1');
      _logger(storage).i('safe');
      await storage.flush().timeout(_timeout);
      final session = (await storage.sessions.list()).single;
      final chunks = [...session.files];

      await storage.close();
      await session.delete();

      expect(chunks.every((file) => !file.existsSync()), isTrue);
      expect(await storage.sessions.list(), isEmpty);
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

    test('write failure stays sticky after later logs recover', () async {
      final reports = <Object>[];
      final dropped = <Log>[];
      final logs = Directory('${tmp.path}/logs');
      final storage = FileLogStorage(
        directory: logs.path,
        sessionId: 's1',
        maxSessionSize: 1200,
        maxChunkSize: 600,
        onError: (error, stackTrace) => reports.add(error),
        onDropped: dropped.addAll,
      );
      final log = _logger(storage);
      log.i('x' * 700);
      await storage.flush().timeout(_timeout);

      final unavailable = await logs.rename('${tmp.path}/unavailable');
      log.i('lost');
      await expectLater(
        storage.flush().timeout(_timeout),
        throwsA(isA<FileSystemException>()),
      );
      expect(reports, isNotEmpty);
      expect(dropped.map((log) => log.message), ['lost']);
      await unavailable.rename(logs.path);

      log.i('recovered');
      await expectLater(
        storage.flush().timeout(_timeout),
        throwsA(isA<FileSystemException>()),
      );

      // The next batch still reaches disk. Its successful write cannot make
      // the earlier loss disappear from the instance's durability result.
      final recovered = File('${logs.path}/s1.3.jsonl');
      expect(recovered.existsSync(), isTrue);
      expect(_json(_lines(recovered).last)['message'], 'recovered');
      expect(recovered.readAsStringSync(), isNot(contains('lost')));
      expect(dropped.map((log) => log.message), ['lost']);

      await expectLater(
        storage.close().timeout(_timeout),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('partial batch failure drops only the uncommitted suffix', () async {
      final logs = Directory('${tmp.path}/logs');
      final unavailable = Directory('${tmp.path}/unavailable');
      final dropped = <Log>[];
      var movedDirectory = false;
      final storage = FileLogStorage(
        directory: logs.path,
        sessionId: 's1',
        maxSessionSize: 1200,
        maxChunkSize: 600,
        onError: (error, stackTrace) {
          if (!movedDirectory) {
            movedDirectory = true;
            logs.renameSync(unavailable.path);
          }
        },
        onDropped: dropped.addAll,
      );
      await storage.ready;
      File('${logs.path}/s1.2.jsonl').writeAsStringSync('occupied');

      final storedMessage = 'stored ${'a' * 700}';
      final lostMessage = 'lost ${'b' * 700}';
      _logger(storage)
        ..i(storedMessage)
        ..i(lostMessage)
        ..i('also lost');
      await expectLater(
        storage.flush().timeout(_timeout),
        throwsA(isA<FileSystemException>()),
      );
      unavailable.renameSync(logs.path);

      expect(
        dropped.map((log) => log.message),
        [lostMessage, 'also lost'],
      );
      expect(
        File('${logs.path}/s1.1.jsonl').readAsStringSync(),
        contains(storedMessage),
      );
      expect(File('${logs.path}/s1.2.jsonl').readAsStringSync(), 'occupied');

      await expectLater(
        storage.close().timeout(_timeout),
        throwsA(isA<FileSystemException>()),
      );
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
