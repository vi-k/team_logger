import 'dart:convert';
import 'dart:io';

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
///
/// Throws [ArgumentError] if the resulting id is empty.
String sanitizeSessionId(String raw) {
  final sanitized = raw.replaceAll(_invalidIdCharsRe, '_');
  if (sanitized.isEmpty) {
    throw ArgumentError.value(raw, 'raw', 'Session id must not be empty');
  }
  return sanitized;
}

/// `<sessionId>.<index>.jsonl`
String chunkName(String sessionId, int index) => '$sessionId.$index.jsonl';

/// Parses a chunk file name.
///
/// Returns `null` for files that are not chunks, including numeric indexes
/// outside the range of a Dart [int].
({String sessionId, int index})? parseChunkName(String fileName) {
  final m = _chunkNameRe.firstMatch(fileName);
  if (m == null) return null;
  final index = int.tryParse(m[2]!);
  if (index == null) return null;

  return (sessionId: m[1]!, index: index);
}

bool _isRegularFile(File file) =>
    FileSystemEntity.typeSync(file.path, followLinks: false) ==
    FileSystemEntityType.file;

String _normalizedAbsolutePath(String path) {
  final normalized = File(path).absolute.uri.normalizePath().toFilePath();
  return Platform.isWindows ? normalized.toLowerCase() : normalized;
}

/// Reader for log sessions stored in a directory by `FileLogStorage`.
///
/// Listing, reading, and deletion ignore non-regular entries, including
/// symlinks. Use an application-private directory. This is best-effort
/// protection against accidental or pre-existing links, not a sandbox against
/// another process that can race filesystem operations in the same directory.
///
/// Deleting the current session of an active `FileLogStorage` is unsupported.
/// Await that storage's `close()` before deleting the session.
final class FileLogSessions {
  final String directory;

  FileLogSessions(this.directory);

  /// All sessions in [directory], sorted from oldest to newest
  /// (by last activity).
  ///
  /// Non-regular directory entries, including symlinks, are ignored.
  Future<List<FileLogSession>> list() async {
    final dir = Directory(directory);
    if (!dir.existsSync()) return const [];

    final chunksById =
        <String, List<({int index, File file, FileStat stat})>>{};
    await for (final entity in dir.list(followLinks: false)) {
      final file = File(entity.path);
      final parsed = parseChunkName(file.uri.pathSegments.last);
      if (parsed == null) continue;
      if (!_isRegularFile(file)) continue;
      final stat = file.statSync();
      // The file may have been deleted between list() and statSync
      // (rotation or cleanup by another process) — otherwise the session
      // would get size -1 and a lastModified near the epoch.
      if (stat.type == FileSystemEntityType.notFound) continue;
      if (!_isRegularFile(file)) continue;
      chunksById
          .putIfAbsent(parsed.sessionId, () => [])
          .add((index: parsed.index, file: file, stat: stat));
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

  /// Compresses the given [sessions] (all by default) into one GZIP-compressed
  /// JSON Lines file [target].
  ///
  /// Sessions are concatenated in their given order. Each keeps its own meta
  /// line, so session boundaries remain identifiable after decompression. The
  /// input and output are streamed with bounded memory. An existing [target]
  /// is overwritten. The target must not be one of the selected session chunks
  /// or an alias to one; an [ArgumentError] is thrown before writing if it is.
  Future<void> gzipTo(
    File target, {
    Iterable<FileLogSession>? sessions,
  }) async {
    final selected = sessions?.toList() ?? await list();

    final normalizedTargetPath = _normalizedAbsolutePath(target.path);
    for (final session in selected) {
      for (final chunk in session.files) {
        if (normalizedTargetPath == _normalizedAbsolutePath(chunk.path)) {
          throw ArgumentError.value(
            target.path,
            'target',
            'Must not alias a selected session chunk',
          );
        }
      }
    }

    final targetType = FileSystemEntity.typeSync(
      target.path,
      followLinks: false,
    );
    if (targetType != FileSystemEntityType.notFound) {
      final identityPath = targetType == FileSystemEntityType.link
          ? await Link(target.path).resolveSymbolicLinks()
          : target.path;
      for (final session in selected) {
        for (final chunk in session.files) {
          if (!_isRegularFile(chunk)) continue;
          if (await FileSystemEntity.identical(identityPath, chunk.path)) {
            throw ArgumentError.value(
              target.path,
              'target',
              'Must not alias a selected session chunk',
            );
          }
        }
      }
    }

    await target.parent.create(recursive: true);
    final sink = target.openWrite();
    Object? primaryError;
    StackTrace? primaryStackTrace;
    try {
      await sink.addStream(_combinedSessions(selected).transform(gzip.encoder));
    } on Object catch (error, stackTrace) {
      primaryError = error;
      primaryStackTrace = stackTrace;
    }

    try {
      await sink.close();
    } on Object catch (error, stackTrace) {
      if (primaryError == null) {
        Error.throwWithStackTrace(error, stackTrace);
      }
    }

    if (primaryError != null) {
      Error.throwWithStackTrace(primaryError, primaryStackTrace!);
    }
  }

  Stream<List<int>> _combinedSessions(
    Iterable<FileLogSession> sessions,
  ) async* {
    var hasOutput = false;
    var endsWithNewline = true;

    for (final session in sessions) {
      var sessionStarted = false;
      await for (final block in session.read()) {
        if (block.isEmpty) continue;
        if (!sessionStarted) {
          if (hasOutput && !endsWithNewline) yield const [0x0A];
          sessionStarted = true;
        }
        yield block;
        hasOutput = true;
        endsWithNewline = block.last == 0x0A;
      }
    }
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
    for (final file in files) {
      if (!_isRegularFile(file)) continue;

      final firstLine = await file
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
        // Not a meta line — treat the session as having no metadata.
      }

      return const {};
    }

    return const {};
  }

  /// The whole session as a byte stream: chunks concatenated in order,
  /// meta lines of chunks after the first are skipped. Non-regular entries
  /// that replace a chunk after listing are ignored.
  Stream<List<int>> read() async* {
    var first = true;
    for (final file in files) {
      if (!_isRegularFile(file)) continue;
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

  /// Deletes all regular chunk files of this session. Non-regular entries
  /// that replace a chunk after listing are ignored.
  ///
  /// Deleting the current session of an active `FileLogStorage` is
  /// unsupported. Await that storage's `close()` first.
  Future<void> delete() async {
    for (final file in files) {
      if (_isRegularFile(file)) {
        await file.delete();
      }
    }
  }

  Stream<List<int>> _skipMetaLine(File file) async* {
    final candidate = <int>[];
    var skipUntilNewline = false;
    var passThrough = false;

    await for (final block in file.openRead()) {
      if (passThrough) {
        yield block;
        continue;
      }

      var offset = 0;
      if (!skipUntilNewline) {
        while (offset < block.length && candidate.length < _metaPrefix.length) {
          final byte = block[offset++];
          candidate.add(byte);
          if (byte != _metaPrefix[candidate.length - 1]) {
            passThrough = true;
            yield candidate;
            if (offset < block.length) yield block.sublist(offset);
            break;
          }
        }

        if (passThrough) continue;
        if (candidate.length < _metaPrefix.length) continue;
        skipUntilNewline = true;
      }

      final newline = block.indexOf(0x0A, offset);
      if (newline == -1) continue;

      passThrough = true;
      if (newline + 1 < block.length) yield block.sublist(newline + 1);
    }

    // The file is shorter than the meta prefix and has no trailing \n.
    if (!passThrough && !skipUntilNewline && candidate.isNotEmpty) {
      yield candidate;
    }
  }
}
