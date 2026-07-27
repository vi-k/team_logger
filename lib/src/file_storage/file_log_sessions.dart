import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'file_log_codec.dart';

final _chunkNameRe = RegExp(r'^([^.]+)\.([0-9]+)\.jsonl$');
final _invalidIdCharsRe = RegExp('[^A-Za-z0-9_-]');

final List<int> _metaPrefix = utf8.encode('{"${FileLogCodec.metaKey}"');

/// Session id derived from the session start time:
/// `yyyyMMdd-HHmmss-<microseconds>` (UTC, sorts lexicographically by time).
String defaultSessionId(DateTime now) {
  final t = now.toUtc();
  String pad2(int v) => v.toString().padLeft(2, '0');
  final micros =
      (t.millisecond * 1000 + t.microsecond).toString().padLeft(6, '0');

  return '${t.year.toString().padLeft(4, '0')}${pad2(t.month)}${pad2(t.day)}'
      '-${pad2(t.hour)}${pad2(t.minute)}${pad2(t.second)}-$micros';
}

/// Replaces characters that are not allowed in a session id (anything but
/// latin letters, digits, `-` and `_`) with `_`.
String sanitizeSessionId(String raw) => raw.replaceAll(_invalidIdCharsRe, '_');

/// `<sessionId>.<index>.jsonl`
String chunkName(String sessionId, int index) => '$sessionId.$index.jsonl';

/// Parses a chunk file name. Returns `null` for files that are not chunks.
({String sessionId, int index})? parseChunkName(String fileName) {
  final m = _chunkNameRe.firstMatch(fileName);
  if (m == null) return null;

  return (sessionId: m[1]!, index: int.parse(m[2]!));
}

bool _startsWith(List<int> bytes, List<int> prefix) {
  if (bytes.length < prefix.length) return false;
  for (var i = 0; i < prefix.length; i++) {
    if (bytes[i] != prefix[i]) return false;
  }

  return true;
}

/// Reader for log sessions stored in a directory by `FileLogStorage`.
final class FileLogSessions {
  final String directory;

  FileLogSessions(this.directory);

  /// All sessions in [directory], sorted from oldest to newest
  /// (by last activity).
  Future<List<FileLogSession>> list() async {
    final dir = Directory(directory);
    if (!dir.existsSync()) return const [];

    final chunksById =
        <String, List<({int index, File file, FileStat stat})>>{};
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final parsed = parseChunkName(entity.uri.pathSegments.last);
      if (parsed == null) continue;
      final stat = entity.statSync();
      // Файл могли удалить между list() и statSync (ротация/очистка другого
      // процесса) — иначе сессия получит size -1 и lastModified около эпохи.
      if (stat.type == FileSystemEntityType.notFound) continue;
      chunksById
          .putIfAbsent(parsed.sessionId, () => [])
          .add((index: parsed.index, file: entity, stat: stat));
    }

    final sessions = <FileLogSession>[];
    for (final MapEntry(key: id, value: chunks) in chunksById.entries) {
      chunks.sort((a, b) => a.index.compareTo(b.index));
      var size = 0;
      var lastModified = DateTime.fromMillisecondsSinceEpoch(0);
      for (final chunk in chunks) {
        size += chunk.stat.size;
        if (chunk.stat.modified.isAfter(lastModified)) {
          lastModified = chunk.stat.modified;
        }
      }
      sessions.add(
        FileLogSession._(
          id: id,
          files: List.unmodifiable(chunks.map((c) => c.file)),
          size: size,
          lastModified: lastModified,
        ),
      );
    }

    sessions.sort(
      (a, b) => switch (a.lastModified.compareTo(b.lastModified)) {
        0 => a.id.compareTo(b.id),
        final byTime => byTime,
      },
    );

    return sessions;
  }

  /// Exports each of the given [sessions] (all by default) as a separate
  /// plain file `<sessionId>.jsonl` into [target] (created recursively).
  ///
  /// Chunks are concatenated in order with exactly one meta line (the
  /// first). Existing target files are overwritten. Returns the created
  /// files, in the same order as the sessions.
  Future<List<File>> exportTo(
    Directory target, {
    Iterable<FileLogSession>? sessions,
  }) async {
    final selected = sessions?.toList() ?? await list();
    await target.create(recursive: true);

    final created = <File>[];
    for (final session in selected) {
      final file = File('${target.path}/${session.id}.jsonl');
      final sink = file.openWrite();
      try {
        await sink.addStream(session.read());
      } finally {
        await sink.close();
      }
      created.add(file);
    }

    return created;
  }

  /// Packs the given [sessions] (all by default) into a single ZIP archive
  /// [target]. Inside the archive every session is a separate file
  /// `<sessionId>.jsonl` with the same content [exportTo] would produce.
  /// An existing [target] is overwritten.
  Future<void> archiveTo(
    File target, {
    Iterable<FileLogSession>? sessions,
  }) async {
    final selected = sessions?.toList() ?? await list();

    final archive = Archive();
    for (final session in selected) {
      final builder = BytesBuilder(copy: false);
      await session.read().forEach(builder.add);
      archive
          .add(ArchiveFile.bytes('${session.id}.jsonl', builder.takeBytes()));
    }

    await target.parent.create(recursive: true);
    await target.writeAsBytes(ZipEncoder().encode(archive), flush: true);
  }
}

/// A single log session: an ordered chain of chunk files.
final class FileLogSession {
  final String id;

  /// Chunk files in ascending index order.
  final List<File> files;

  /// Total size in bytes at the moment of `list()`.
  final int size;

  /// Last activity at the moment of `list()`.
  final DateTime lastModified;

  FileLogSession._({
    required this.id,
    required this.files,
    required this.size,
    required this.lastModified,
  });

  /// The content of the session meta line, or an empty map if absent.
  Future<Map<String, Object?>> readMeta() async {
    if (files.isEmpty) return const {};

    final firstLine = await files.first
        .openRead()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .firstWhere((_) => true, orElse: () => '');

    try {
      final decoded = jsonDecode(firstLine);
      if (decoded is Map<String, Object?>) {
        final meta = decoded[FileLogCodec.metaKey];
        if (meta is Map<String, Object?>) return meta;
      }
    } on FormatException {
      // Не meta-строка — считаем, что метаданных нет.
    }

    return const {};
  }

  /// The whole session as a byte stream: chunks concatenated in order,
  /// meta lines of chunks after the first are skipped.
  Stream<List<int>> read() async* {
    var first = true;
    for (final file in files) {
      if (first) {
        first = false;
        yield* file.openRead();
      } else {
        yield* _skipMetaLine(file);
      }
    }
  }

  /// The whole session as a string (see [read]).
  Future<String> readAsString() => read().transform(utf8.decoder).join();

  /// Deletes all chunk files of this session.
  Future<void> delete() async {
    for (final file in files) {
      if (file.existsSync()) {
        await file.delete();
      }
    }
  }

  Stream<List<int>> _skipMetaLine(File file) async* {
    var buffer = <int>[];
    var newlineSeen = false;

    await for (final block in file.openRead()) {
      if (newlineSeen) {
        yield block;
        continue;
      }

      buffer.addAll(block);
      final nl = buffer.indexOf(0x0A);
      if (nl == -1) continue;

      newlineSeen = true;
      if (!_startsWith(buffer, _metaPrefix)) {
        yield buffer.sublist(0, nl + 1);
      }
      if (nl + 1 < buffer.length) {
        yield buffer.sublist(nl + 1);
      }
      buffer = const [];
    }

    // Файл из единственной строки без завершающего \n.
    if (!newlineSeen &&
        buffer.isNotEmpty &&
        !_startsWith(buffer, _metaPrefix)) {
      yield buffer;
    }
  }
}
