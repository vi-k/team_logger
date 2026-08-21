import 'dart:convert';
import 'dart:io';

import 'package:team_logger/src/file_storage/file_log_sessions.dart';
import 'package:test/test.dart';

String _metaLine(String id) =>
    '{":meta":{"sessionId":"$id","started":"2026-01-01T00:00:00.000Z"}}';

File _chunk(
  Directory dir,
  String id,
  int index,
  List<String> lines, {
  DateTime? modified,
}) {
  final file = File('${dir.path}/$id.$index.jsonl')
    ..writeAsStringSync(lines.map((l) => '$l\n').join());
  if (modified != null) {
    file.setLastModifiedSync(modified);
  }
  return file;
}

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
  group('chunk names', () {
    test('chunkName/parseChunkName roundtrip', () {
      expect(chunkName('s1', 12), 's1.12.jsonl');
      expect(parseChunkName('s1.12.jsonl'), (sessionId: 's1', index: 12));
    });

    test('parseChunkName rejects foreign files', () {
      expect(parseChunkName('foo.txt'), isNull);
      expect(parseChunkName('bar.jsonl'), isNull);
      expect(parseChunkName('a.b.3.jsonl'), isNull);
      expect(parseChunkName('x..jsonl'), isNull);
      expect(parseChunkName('x.1.jsonl.bak'), isNull);
      expect(parseChunkName('x.1x.jsonl'), isNull);
    });

    test('parseChunkName rejects an index larger than int', () {
      // Mutation: int.parse accepts the regex match, then throws instead of
      // treating an unrepresentable chunk index as a foreign file name.
      final fileName = 's1.${'9' * 100}.jsonl';
      ({String sessionId, int index})? parsed;

      expect(() => parsed = parseChunkName(fileName), returnsNormally);
      expect(parsed, isNull);
    });

    test('defaultSessionId format and lexicographic ordering', () {
      final id =
          defaultSessionId(DateTime.utc(2026, 7, 27, 9, 30, 59, 482, 913));
      expect(id, '20260727-093059-482913');

      final earlier =
          defaultSessionId(DateTime.utc(2026, 7, 27, 9, 30, 59, 482));
      expect(earlier.compareTo(id), lessThan(0));
    });

    test('sanitizeSessionId replaces invalid characters', () {
      expect(sanitizeSessionId('a.b/c:d e'), 'a_b_c_d_e');
      expect(sanitizeSessionId('AB-9_x'), 'AB-9_x');
    });

    test('sanitizeSessionId rejects an empty id', () {
      // Mutation: returning the empty string lets FileLogStorage create
      // `.1.jsonl`, which its own session parser cannot discover.
      expect(
        () => sanitizeSessionId(''),
        throwsA(
          isA<ArgumentError>()
              .having((error) => error.name, 'name', 'raw')
              .having((error) => error.invalidValue, 'invalidValue', ''),
        ),
      );
    });
  });

  group('FileLogSessions', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('team_logger_test');
    });

    tearDown(() async {
      if (tmp.existsSync()) {
        await tmp.delete(recursive: true);
      }
    });

    test('list groups chunks by session, sorts sessions and chunks', () async {
      _chunk(
        tmp,
        's1',
        9,
        [_metaLine('s1'), '{"num":1}'],
        modified: DateTime(2026, 1, 1),
      );
      _chunk(
        tmp,
        's1',
        10,
        [_metaLine('s1'), '{"num":2}'],
        modified: DateTime(2026, 1, 2),
      );
      _chunk(
        tmp,
        's2',
        1,
        [_metaLine('s2'), '{"num":3}'],
        modified: DateTime(2026, 1, 3),
      );

      final sessions = await FileLogSessions(tmp.path).list();

      expect(sessions.map((s) => s.id), ['s1', 's2']);

      final s1 = sessions.first;
      expect(
        s1.files.map((f) => f.uri.pathSegments.last),
        ['s1.9.jsonl', 's1.10.jsonl'],
      );
      expect(
        s1.size,
        File('${tmp.path}/s1.9.jsonl').lengthSync() +
            File('${tmp.path}/s1.10.jsonl').lengthSync(),
      );
      expect(s1.lastModified, DateTime(2026, 1, 2));
    });

    test('list ignores foreign files', () async {
      _chunk(tmp, 's1', 1, [_metaLine('s1')]);
      File('${tmp.path}/notes.txt').writeAsStringSync('hi');
      File('${tmp.path}/export.jsonl').writeAsStringSync('{}');

      final sessions = await FileLogSessions(tmp.path).list();

      expect(sessions.map((s) => s.id), ['s1']);
    });

    test('list ignores symlinks with chunk names', () async {
      // Mutation: removing the no-follow check includes leak in a session.
      _chunk(tmp, 'safe', 1, [_metaLine('safe'), '{"num":1}']);
      final victim = File('${tmp.path}/victim.txt')
        ..writeAsStringSync('outside-secret');
      if (!await _createLinkOrSkip(
        Link('${tmp.path}/leak.1.jsonl'),
        victim.path,
      )) {
        return;
      }

      final sessions = await FileLogSessions(tmp.path).list();

      expect(sessions.map((session) => session.id), ['safe']);
    });

    test('list returns empty list for missing directory', () async {
      final sessions =
          await FileLogSessions('${tmp.path}/does_not_exist').list();

      expect(sessions, isEmpty);
    });

    test('readMeta returns the meta object', () async {
      _chunk(tmp, 's1', 1, [_metaLine('s1'), '{"num":1}']);

      final session = (await FileLogSessions(tmp.path).list()).single;

      expect(await session.readMeta(), {
        'sessionId': 's1',
        'started': '2026-01-01T00:00:00.000Z',
      });
    });

    test('read and readMeta skip a chunk replaced by a symlink', () async {
      // Mutation: removing the late no-follow check opens the link target.
      final chunk = _chunk(
        tmp,
        's1',
        1,
        [_metaLine('s1'), '{"message":"safe"}'],
      );
      final session = (await FileLogSessions(tmp.path).list()).single;
      final original = await chunk.rename('${tmp.path}/original.jsonl');
      final victim = File('${tmp.path}/victim.txt')
        ..writeAsStringSync('outside-secret');
      if (!await _createLinkOrSkip(Link(chunk.path), victim.path)) return;

      expect(await session.readMeta(), isEmpty);
      expect(await session.readAsString(), isNot(contains('outside-secret')));
      expect(original.readAsStringSync(), contains('safe'));
    });

    test('read concatenates chunks, skipping duplicate meta lines', () async {
      _chunk(tmp, 's1', 1, [_metaLine('s1'), '{"num":1}']);
      _chunk(tmp, 's1', 2, [_metaLine('s1'), '{"num":2}', '{"num":3}']);

      final session = (await FileLogSessions(tmp.path).list()).single;
      final content = await session.readAsString();

      expect(
        const LineSplitter().convert(content),
        [_metaLine('s1'), '{"num":1}', '{"num":2}', '{"num":3}'],
      );
    });

    test('read keeps first line of a chunk without meta line', () async {
      _chunk(tmp, 's1', 1, [_metaLine('s1'), '{"num":1}']);
      _chunk(tmp, 's1', 2, ['{"num":2}']);

      final session = (await FileLogSessions(tmp.path).list()).single;
      final content = await session.readAsString();

      expect(
        const LineSplitter().convert(content),
        [_metaLine('s1'), '{"num":1}', '{"num":2}'],
      );
    });

    test('read does not buffer a long first line of a later chunk', () async {
      // Mutation: accumulating bytes until LF emits this whole file at once.
      _chunk(tmp, 's1', 1, [_metaLine('s1'), '{"num":1}']);
      const longLineLength = 2 * 1024 * 1024;
      File('${tmp.path}/s1.2.jsonl').writeAsBytesSync(
        List<int>.filled(longLineLength, 0x61),
      );

      final session = (await FileLogSessions(tmp.path).list()).single;
      final blocks = await session.read().toList();

      expect(
        blocks.expand((block) => block).length,
        greaterThan(longLineLength),
      );
      expect(
        blocks.map((block) => block.length),
        everyElement(lessThan(1024 * 1024)),
      );
    });

    test('exportTo writes each session as a separate plain file', () async {
      _chunk(
        tmp,
        's1',
        1,
        [_metaLine('s1'), '{"num":1}'],
        modified: DateTime(2026, 1, 1),
      );
      _chunk(
        tmp,
        's1',
        2,
        [_metaLine('s1'), '{"num":2}'],
        modified: DateTime(2026, 1, 1),
      );
      _chunk(
        tmp,
        's2',
        1,
        [_metaLine('s2'), '{"num":3}'],
        modified: DateTime(2026, 1, 2),
      );

      final target = Directory('${tmp.path}/out');
      final files = await FileLogSessions(tmp.path).exportTo(target);

      expect(
        files.map((f) => f.uri.pathSegments.last),
        ['s1.jsonl', 's2.jsonl'],
      );
      expect(
        const LineSplitter()
            .convert(File('${target.path}/s1.jsonl').readAsStringSync()),
        [_metaLine('s1'), '{"num":1}', '{"num":2}'],
      );
      expect(
        const LineSplitter()
            .convert(File('${target.path}/s2.jsonl').readAsStringSync()),
        [_metaLine('s2'), '{"num":3}'],
      );
    });

    test('exportTo exports only the given sessions', () async {
      _chunk(tmp, 's1', 1, [_metaLine('s1'), '{"num":1}']);
      _chunk(tmp, 's2', 1, [_metaLine('s2'), '{"num":2}']);

      final all = await FileLogSessions(tmp.path).list();
      final target = Directory('${tmp.path}/out');
      final files = await FileLogSessions(tmp.path).exportTo(
        target,
        sessions: all.where((s) => s.id == 's2'),
      );

      expect(files.map((f) => f.uri.pathSegments.last), ['s2.jsonl']);
      expect(File('${target.path}/s1.jsonl').existsSync(), isFalse);
    });

    test('exportTo skips a chunk replaced by a symlink', () async {
      // Mutation: removing the late no-follow check exports the link target.
      final chunk = _chunk(
        tmp,
        's1',
        1,
        [_metaLine('s1'), '{"message":"safe"}'],
      );
      final session = (await FileLogSessions(tmp.path).list()).single;
      await chunk.rename('${tmp.path}/original.jsonl');
      final victim = File('${tmp.path}/victim.txt')
        ..writeAsStringSync('outside-secret');
      if (!await _createLinkOrSkip(Link(chunk.path), victim.path)) return;

      final target = Directory('${tmp.path}/out');
      final files = await FileLogSessions(tmp.path).exportTo(
        target,
        sessions: [session],
      );

      expect(
        files.single.readAsStringSync(),
        isNot(contains('outside-secret')),
      );
    });

    test('exportTo overwrites existing target files', () async {
      _chunk(tmp, 's1', 1, [_metaLine('s1'), '{"num":1}']);
      final target = Directory('${tmp.path}/out')..createSync();
      File('${target.path}/s1.jsonl').writeAsStringSync('garbage garbage');

      await FileLogSessions(tmp.path).exportTo(target);

      expect(
        const LineSplitter()
            .convert(File('${target.path}/s1.jsonl').readAsStringSync()),
        [_metaLine('s1'), '{"num":1}'],
      );
    });

    test('export into the log directory does not affect listing', () async {
      _chunk(tmp, 's1', 1, [_metaLine('s1'), '{"num":1}']);

      await FileLogSessions(tmp.path).exportTo(tmp);

      expect(File('${tmp.path}/s1.jsonl').existsSync(), isTrue);
      final sessions = await FileLogSessions(tmp.path).list();
      expect(sessions.map((s) => s.id), ['s1']);
    });

    test('gzipTo combines sessions in order with every meta line', () async {
      _chunk(
        tmp,
        's1',
        1,
        [_metaLine('s1'), '{"num":1}'],
        modified: DateTime(2026, 1, 1),
      );
      _chunk(
        tmp,
        's1',
        2,
        [_metaLine('s1'), '{"num":2}'],
        modified: DateTime(2026, 1, 1),
      );
      _chunk(
        tmp,
        's2',
        1,
        [_metaLine('s2'), '{"num":3}'],
        modified: DateTime(2026, 1, 2),
      );

      final target = File('${tmp.path}/out/logs.jsonl.gz');
      await FileLogSessions(tmp.path).gzipTo(target);

      expect(
        const LineSplitter().convert(
          utf8.decode(gzip.decode(target.readAsBytesSync())),
        ),
        [
          _metaLine('s1'),
          '{"num":1}',
          '{"num":2}',
          _metaLine('s2'),
          '{"num":3}',
        ],
      );
    });

    test('gzipTo includes only the given sessions and overwrites target',
        () async {
      _chunk(tmp, 's1', 1, [_metaLine('s1'), '{"num":1}']);
      _chunk(tmp, 's2', 1, [_metaLine('s2'), '{"num":2}']);

      final target = File('${tmp.path}/logs.jsonl.gz')
        ..writeAsStringSync('garbage');
      final all = await FileLogSessions(tmp.path).list();
      await FileLogSessions(tmp.path).gzipTo(
        target,
        sessions: all.where((s) => s.id == 's2'),
      );

      expect(
        const LineSplitter().convert(
          utf8.decode(gzip.decode(target.readAsBytesSync())),
        ),
        [_metaLine('s2'), '{"num":2}'],
      );
    });

    test('gzipTo skips a chunk replaced by a symlink', () async {
      // Mutation: removing the late no-follow check compresses the link target.
      final chunk = _chunk(
        tmp,
        's1',
        1,
        [_metaLine('s1'), '{"message":"safe"}'],
      );
      final session = (await FileLogSessions(tmp.path).list()).single;
      await chunk.rename('${tmp.path}/original.jsonl');
      final victim = File('${tmp.path}/victim.txt')
        ..writeAsStringSync('outside-secret');
      if (!await _createLinkOrSkip(Link(chunk.path), victim.path)) return;

      final target = File('${tmp.path}/logs.jsonl.gz');
      await FileLogSessions(tmp.path).gzipTo(target, sessions: [session]);

      expect(
        utf8.decode(gzip.decode(target.readAsBytesSync())),
        isNot(contains('outside-secret')),
      );
    });

    test('gzipTo separates sessions when the previous one has no newline',
        () async {
      File('${tmp.path}/s1.1.jsonl').writeAsStringSync('{"num":1}');
      _chunk(tmp, 's2', 1, [_metaLine('s2'), '{"num":2}']);

      final target = File('${tmp.path}/logs.jsonl.gz');
      await FileLogSessions(tmp.path).gzipTo(target);

      expect(
        const LineSplitter().convert(
          utf8.decode(gzip.decode(target.readAsBytesSync())),
        ),
        ['{"num":1}', _metaLine('s2'), '{"num":2}'],
      );
    });

    test('gzipTo rejects a target that is a selected chunk', () async {
      final chunk = _chunk(
        tmp,
        's1',
        1,
        [_metaLine('s1'), '{"message":"keep me"}'],
      );
      final original = chunk.readAsBytesSync();
      final session = (await FileLogSessions(tmp.path).list()).single;

      await expectLater(
        FileLogSessions(tmp.path).gzipTo(chunk, sessions: [session]),
        throwsArgumentError,
      );
      expect(chunk.readAsBytesSync(), original);
    });

    test('gzipTo rejects a symlink target to a selected chunk', () async {
      final chunk = _chunk(
        tmp,
        's1',
        1,
        [_metaLine('s1'), '{"message":"keep me"}'],
      );
      final original = chunk.readAsBytesSync();
      final target = Link('${tmp.path}/logs.jsonl.gz');
      if (!await _createLinkOrSkip(target, chunk.path)) return;
      final session = (await FileLogSessions(tmp.path).list()).single;

      await expectLater(
        FileLogSessions(tmp.path).gzipTo(
          File(target.path),
          sessions: [session],
        ),
        throwsArgumentError,
      );
      expect(chunk.readAsBytesSync(), original);
    });

    test('gzipTo rejects a selected chunk path replaced by a symlink',
        () async {
      final chunk = _chunk(
        tmp,
        's1',
        1,
        [_metaLine('s1'), '{"message":"keep me"}'],
      );
      final session = (await FileLogSessions(tmp.path).list()).single;
      await chunk.rename('${tmp.path}/original.jsonl');
      final victim = File('${tmp.path}/victim.txt')
        ..writeAsStringSync('outside-secret');
      if (!await _createLinkOrSkip(Link(chunk.path), victim.path)) return;

      await expectLater(
        FileLogSessions(tmp.path).gzipTo(chunk, sessions: [session]),
        throwsArgumentError,
      );
      expect(victim.readAsStringSync(), 'outside-secret');
    });

    test('gzipTo rejects a hardlink target to a selected chunk', () async {
      if (Platform.isWindows) {
        markTestSkipped('POSIX hardlink creation is required');
        return;
      }

      final chunk = _chunk(
        tmp,
        's1',
        1,
        [_metaLine('s1'), '{"message":"keep me"}'],
      );
      final original = chunk.readAsBytesSync();
      final target = File('${tmp.path}/logs.jsonl.gz');
      expect(
        (await Process.run('ln', [chunk.path, target.path])).exitCode,
        0,
      );
      final session = (await FileLogSessions(tmp.path).list()).single;

      await expectLater(
        FileLogSessions(tmp.path).gzipTo(target, sessions: [session]),
        throwsArgumentError,
      );
      expect(chunk.readAsBytesSync(), original);
    });

    test('gzipTo preserves a source read error when closing the target',
        () async {
      if (Platform.isWindows) {
        markTestSkipped('POSIX file permissions are required');
        return;
      }

      final chunk = _chunk(tmp, 's1', 1, [_metaLine('s1'), '{"num":1}']);
      final session = (await FileLogSessions(tmp.path).list()).single;
      final target = File('${tmp.path}/logs.jsonl.gz');
      expect((await Process.run('chmod', ['000', chunk.path])).exitCode, 0);

      try {
        var sourceIsReadable = false;
        try {
          await chunk.openRead().drain<void>();
          sourceIsReadable = true;
        } on FileSystemException {
          // Expected on a POSIX filesystem that enforces the mode bits.
        }
        if (sourceIsReadable) {
          markTestSkipped('The filesystem does not enforce mode bits');
          return;
        }

        await expectLater(
          FileLogSessions(tmp.path).gzipTo(target, sessions: [session]),
          throwsA(
            isA<FileSystemException>().having(
              (error) => error.path,
              'path',
              chunk.path,
            ),
          ),
        );
      } finally {
        expect((await Process.run('chmod', ['600', chunk.path])).exitCode, 0);
      }
    });

    test('delete removes all session files and nothing else', () async {
      _chunk(tmp, 's1', 1, [_metaLine('s1')]);
      _chunk(tmp, 's1', 2, [_metaLine('s1')]);
      final other = _chunk(tmp, 's2', 1, [_metaLine('s2')]);

      final sessions = await FileLogSessions(tmp.path).list();
      await sessions.firstWhere((s) => s.id == 's1').delete();

      expect(File('${tmp.path}/s1.1.jsonl').existsSync(), isFalse);
      expect(File('${tmp.path}/s1.2.jsonl').existsSync(), isFalse);
      expect(other.existsSync(), isTrue);
    });

    test('delete skips a chunk replaced by a symlink', () async {
      // Mutation: removing the late no-follow check deletes the symlink.
      final chunk = _chunk(tmp, 's1', 1, [_metaLine('s1')]);
      final session = (await FileLogSessions(tmp.path).list()).single;
      await chunk.rename('${tmp.path}/original.jsonl');
      final victim = File('${tmp.path}/victim.txt')
        ..writeAsStringSync('outside-secret');
      if (!await _createLinkOrSkip(Link(chunk.path), victim.path)) return;

      await session.delete();

      expect(victim.readAsStringSync(), 'outside-secret');
      expect(
        FileSystemEntity.typeSync(chunk.path, followLinks: false),
        FileSystemEntityType.link,
      );
    });
  });
}
