import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
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

    test('archiveTo packs sessions into a single zip file', () async {
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

      final target = File('${tmp.path}/out/logs.zip');
      await FileLogSessions(tmp.path).archiveTo(target);

      final archive = ZipDecoder().decodeBytes(target.readAsBytesSync());
      expect(
        archive.files.map((f) => f.name),
        unorderedEquals(['s1.jsonl', 's2.jsonl']),
      );
      expect(
        const LineSplitter()
            .convert(utf8.decode(archive.find('s1.jsonl')!.content)),
        [_metaLine('s1'), '{"num":1}', '{"num":2}'],
      );
      expect(
        const LineSplitter()
            .convert(utf8.decode(archive.find('s2.jsonl')!.content)),
        [_metaLine('s2'), '{"num":3}'],
      );
    });

    test('archiveTo archives only the given sessions and overwrites target',
        () async {
      _chunk(tmp, 's1', 1, [_metaLine('s1'), '{"num":1}']);
      _chunk(tmp, 's2', 1, [_metaLine('s2'), '{"num":2}']);

      final target = File('${tmp.path}/logs.zip')..writeAsStringSync('garbage');
      final all = await FileLogSessions(tmp.path).list();
      await FileLogSessions(tmp.path).archiveTo(
        target,
        sessions: all.where((s) => s.id == 's2'),
      );

      final archive = ZipDecoder().decodeBytes(target.readAsBytesSync());
      expect(archive.files.map((f) => f.name), ['s2.jsonl']);
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
  });
}
