import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:logger_builder/logger_builder.dart';

import '../loggable/loggable_config.dart';
import '../loggable/loggable_json_config.dart';
import '../logger/log_levels.dart';
import '../logger/logger.dart';
import '../theme/log_main_theme.dart';
import 'file_log_codec.dart';
import 'file_log_sessions.dart';

FileSystemEntityType _entityTypeNoFollow(String path) =>
    FileSystemEntity.typeSync(path, followLinks: false);

bool _isRegularFilePath(String path) =>
    _entityTypeNoFollow(path) == FileSystemEntityType.file;

int? _validateMaxQueueSize(int? maxQueueSize) {
  if (maxQueueSize != null && maxQueueSize <= 0) {
    throw ArgumentError.value(
      maxQueueSize,
      'maxQueueSize',
      'Must be null or positive',
    );
  }

  return maxQueueSize;
}

int _validateStorageSizes({
  required int maxChunkSize,
  required int maxSessionSize,
  required int? maxTotalSize,
}) {
  if (maxChunkSize <= 0) {
    throw ArgumentError.value(
      maxChunkSize,
      'maxChunkSize',
      'Must be positive',
    );
  }
  if (maxSessionSize < 2 * maxChunkSize) {
    throw ArgumentError.value(
      maxSessionSize,
      'maxSessionSize',
      'Must fit at least two chunks '
          '(maxSessionSize >= 2 * maxChunkSize)',
    );
  }
  if (maxTotalSize != null && maxTotalSize < maxSessionSize) {
    throw ArgumentError.value(
      maxTotalSize,
      'maxTotalSize',
      'Must be greater than or equal to maxSessionSize',
    );
  }

  return maxSessionSize;
}

typedef _EncodedLog = ({Log log, String line});
typedef _WriteFailure = ({
  Object error,
  StackTrace stackTrace,
  List<Log> uncommittedLogs,
});

/// A publisher that stores logs on disk, one session per application run.
///
/// Use an application-private directory. Symlinks and other non-regular
/// entries are ignored, and each chunk is created exclusively and kept open
/// while active. This is best-effort protection against accidental or
/// pre-existing links, not a sandbox against another process that can race
/// filesystem operations in the same directory.
///
/// A session is a chain of chunk files `<sessionId>.<index>.jsonl`.
/// [maxChunkSize] is its chunk-rotation target, and [maxSessionSize] is its
/// retention target: when the latter is exceeded, the oldest chunk is
/// deleted, so the most recent logs are always kept. On startup, sessions
/// older than [maxAge] are deleted, and, if [maxTotalSize] is set, the oldest
/// sessions are deleted until the rest fit into its retention budget. The
/// number of chunks and sessions is not limited.
///
/// These size settings are not hard byte ceilings. A JSON Lines record is
/// never split, truncated or dropped solely because of its size. A record
/// larger than [maxChunkSize] is written whole, and the newest chunk is never
/// deleted, so it and the current session can also exceed [maxSessionSize].
/// Consequently, [maxTotalSize] cannot guarantee a hard runtime ceiling.
/// Bound input sizes before publishing if the application requires one.
/// Construction throws [ArgumentError] unless [maxChunkSize] is positive,
/// [maxSessionSize] fits at least two chunks, and a non-null [maxTotalSize]
/// is at least [maxSessionSize]. [maxQueueSize] must be null or positive.
///
/// Logs are written in batches in the background; a successfully completed
/// `await flush()` guarantees everything published so far is on disk. After
/// [close] publications are silently ignored. [close] waits for
/// initialization, drains accepted logs, and closes the active chunk handle.
/// Once closing starts, [isClosed] is immediately true and [flush] returns
/// the same full-lifecycle Future as [close].
///
/// Deleting the current session through [FileLogSession.delete] while this
/// storage is active is unsupported. Await [close] before deleting it.
///
/// [onError] is called on initialization, encoding and write errors.
/// Initialization and write errors that make accepted logs unavailable also
/// make every subsequent [flush] and [close] complete with the first such
/// error. Exceptions thrown by [onError] itself are ignored.
///
/// The queue between `publish` and the disk is bounded by [maxQueueSize] —
/// 100 000 logs accepted and not yet written, the batch in flight included.
/// At the limit it is the *incoming* log that is refused, so a disk that
/// cannot keep up costs the newest logs rather than the process; everything
/// already accepted is still written, and [flush] and [close] keep their
/// meaning. A refused log goes to [onDropped], and with no [onDropped] set
/// the loss is announced on stdout rather than hidden — pass
/// `onDropped: (_) {}` for silence. A log that cannot be persisted after it
/// was accepted is also handed to [onDropped]. Failed writes are never
/// retried: the storage can recover for later logs, but the durability error
/// remains observable for the lifetime of this instance.
final class FileLogStorage extends AsyncPublisherWithBufferBase<Log> {
  /// The directory the session files are stored in (created recursively).
  final String directory;

  /// User fields of the metadata line written as the first line of every
  /// chunk.
  final Map<String, Object?>? meta;

  final int minLevel;

  /// Retained-size target for one session, in bytes.
  ///
  /// The newest chunk is always kept, so an oversized record can make the
  /// session exceed this target. See the class documentation.
  final int maxSessionSize;

  /// Rotation-size target for one chunk file, in bytes.
  ///
  /// When a chunk reaches it, the next chunk is started. One JSON Lines record
  /// is never split, so it can make a chunk exceed this target. Must fit into
  /// [maxSessionSize] at least twice.
  final int maxChunkSize;

  /// Startup retention budget for all sessions together, in bytes.
  ///
  /// This is not a hard runtime ceiling because the current session can exceed
  /// [maxSessionSize]. `null` disables this cleanup.
  final int? maxTotalSize;

  /// Sessions older than this are deleted on startup. `null` — keep forever.
  final Duration? maxAge;

  /// Completes when the storage is initialized: the directory is created,
  /// old sessions are cleaned up, the session id is resolved and the first
  /// chunk with the metadata line is reserved on disk. Never completes with
  /// an error. Awaiting it is optional: logs published earlier are buffered.
  late final Future<void> ready;

  final FileLogCodec _codec;
  final DateTime _started;

  late String _sessionId;
  late final List<int> _metaLineBytes;
  var _disabled = false;
  var _closed = false;
  var _chunkIndex = 1;
  var _chunkSize = 0;
  RandomAccessFile? _currentChunk;
  Future<void>? _closeFuture;
  (Object, StackTrace)? _durabilityFailure;

  /// Sizes of the current session's chunks on disk (index -> bytes).
  final Map<int, int> _chunkSizes = {};

  // Explicit callback and queue parameters let the super invocation keep
  // write retries fixed at zero without adding maxRetries to this API.
  // ignore: use_super_parameters
  FileLogStorage({
    required this.directory,
    String? sessionId,
    this.meta,
    this.minLevel = LogLevels.all,
    this.maxTotalSize,
    int maxSessionSize = 10 * 1024 * 1024,
    this.maxChunkSize = 1024 * 1024,
    this.maxAge = const Duration(days: 7),
    FileLogDataFormat dataFormat = FileLogDataFormat.text,
    LogMainTheme? theme,
    LoggableConfig config = const LoggableConfig(),
    LoggableJsonConfig jsonConfig = const LoggableJsonConfig(),
    void Function(Object error, StackTrace stackTrace)? onError,
    void Function(List<Log> logs)? onDropped,
    int? maxQueueSize = 100000,
  })  : maxSessionSize = _validateStorageSizes(
          maxChunkSize: maxChunkSize,
          maxSessionSize: maxSessionSize,
          maxTotalSize: maxTotalSize,
        ),
        _codec = FileLogCodec(
          dataFormat: dataFormat,
          theme: theme,
          config: config,
          jsonConfig: jsonConfig,
        ),
        _started = clock.now(),
        super(
          onError: onError,
          onDropped: onDropped,
          maxRetries: 0,
          maxQueueSize: _validateMaxQueueSize(maxQueueSize),
        ) {
    _sessionId = sanitizeSessionId(sessionId ?? defaultSessionId(_started));
    // Initialization starts in the background; its future is kept in
    // [ready].
    // ignore: discarded_futures
    ready = _init();
  }

  /// The id of the current session.
  ///
  /// May get a numeric suffix during initialization if a session with the
  /// same id already exists on disk (see [ready]).
  String get sessionId => _sessionId;

  @override
  bool get isClosed => _closed;

  /// Reader for the sessions stored in [directory], including the current
  /// one.
  FileLogSessions get sessions => FileLogSessions(directory);

  @override
  void publish(Log log) {
    // After close, publishing is a no-op: the base publish would throw a
    // StateError into the logging call, and the buffer would never be
    // drained.
    if (_closed || log.level < minLevel) return;

    super.publish(log);
  }

  @override
  Future<void> flush() {
    final closeFuture = _closeFuture;
    if (closeFuture != null) return closeFuture;

    return _flush();
  }

  Future<void> _flush() async {
    // flush guarantees not only that what was published is written (the
    // drain semantics of the base flush), but that initialization finished:
    // the first chunk, with its meta line, is already on disk.
    await ready;
    await super.flush();
    _throwIfDurabilityFailed();
  }

  @override
  Future<void> close() {
    _closed = true;

    return _closeFuture ??= _close();
  }

  Future<void> _close() async {
    await ready;
    try {
      await super.close();
    } finally {
      await _closeCurrentChunk(reportErrors: true);
    }
    _throwIfDurabilityFailed();
  }

  @override
  Future<void> handle(List<Log> logs, List<Log> retryBuffer) async {
    List<Log>? persistedLogs;
    try {
      await ready;
      persistedLogs = [
        for (final log in logs)
          if (log.level >= minLevel) log,
      ];
      if (_disabled) {
        retryBuffer.addAll(persistedLogs);
        return;
      }

      final encodedLogs = <_EncodedLog>[];
      for (final log in persistedLogs) {
        try {
          encodedLogs.add((log: log, line: _codec.encode(log)));
        } on Object catch (error, stackTrace) {
          // A failure encoding one log (a throwing toString and the like)
          // must not lose its neighbours in the batch.
          _report(error, stackTrace);
          encodedLogs.add((log: log, line: _encodeFallback(log, error)));
        }
      }

      if (encodedLogs.isNotEmpty) {
        final failure = await _write(encodedLogs);
        if (failure != null) {
          _rememberDurabilityFailure(failure.error, failure.stackTrace);
          retryBuffer.addAll(failure.uncommittedLogs);
          _report(failure.error, failure.stackTrace);
          await _recoverAfterWriteError();
        }
      }
    } on Object catch (error, stackTrace) {
      _rememberDurabilityFailure(error, stackTrace);
      if (retryBuffer.isEmpty && persistedLogs != null) {
        retryBuffer.addAll(persistedLogs);
      }
      _report(error, stackTrace);
    }
  }

  Future<void> _init() async {
    try {
      await Directory(directory).create(recursive: true);
      await _cleanupOnStartup();

      // A free id: first by the existing files (including sessions whose
      // first chunk rotation has already deleted)...
      final existingIds = _existingSessionIds();
      final base = _sessionId;
      var n = 0;
      var candidate = _sessionId;
      while (existingIds.contains(candidate)) {
        n++;
        candidate = '$base-$n';
      }

      // ...then the session is reserved by creating its first chunk
      // exclusively — protection against two instances racing on the same
      // id before either has written anything.
      late File file;
      while (true) {
        file = File('$directory/${chunkName(candidate, 1)}');
        try {
          await file.create(exclusive: true);
          break;
        } on FileSystemException {
          if (_entityTypeNoFollow(file.path) == FileSystemEntityType.notFound) {
            rethrow;
          }
          n++;
          candidate = '$base-$n';
        }
      }
      _sessionId = candidate;

      _metaLineBytes = utf8.encode(
        '${_codec.encodeMeta(
          sessionId: candidate,
          started: _started,
          meta: meta,
        )}\n',
      );
      _currentChunk = await file.open(mode: FileMode.writeOnlyAppend);
      await _appendToCurrent(_metaLineBytes);
    } on Object catch (error, stackTrace) {
      _disabled = true;
      _rememberDurabilityFailure(error, stackTrace);
      _report(error, stackTrace);
      await _closeCurrentChunk(reportErrors: true);
    }
  }

  /// Deletes sessions older than [maxAge], then the oldest sessions until
  /// the rest fit into `maxTotalSize - maxSessionSize` (the reserve for the
  /// current session to grow into).
  Future<void> _cleanupOnStartup() async {
    final maxAge = this.maxAge;
    final maxTotalSize = this.maxTotalSize;
    if (maxAge == null && maxTotalSize == null) return;

    // Oldest to newest.
    final kept = await sessions.list().then(List.of);

    if (maxAge != null) {
      final deadline = clock.now().subtract(maxAge);
      for (final session in [...kept]) {
        if (session.lastModified.isBefore(deadline)) {
          await session.delete();
          kept.remove(session);
        }
      }
    }

    if (maxTotalSize != null) {
      final allowed = maxTotalSize - maxSessionSize;
      var total = kept.fold(0, (sum, session) => sum + session.size);
      for (final session in kept) {
        if (total <= allowed) break;
        await session.delete();
        total -= session.size;
      }
    }
  }

  Set<String> _existingSessionIds() => {
        for (final entity in Directory(directory).listSync(followLinks: false))
          if (_isRegularFilePath(entity.path))
            if (parseChunkName(entity.uri.pathSegments.last) case final parsed?)
              parsed.sessionId,
      };

  /// Appends a batch's lines to chunks, splitting the batch by
  /// [maxChunkSize] so that one large batch neither inflates a chunk nor
  /// gets discarded whole by rotation. Append only: files are never
  /// truncated.
  Future<_WriteFailure?> _write(List<_EncodedLog> logs) async {
    final target = maxChunkSize;
    final pending = BytesBuilder(copy: false);
    final pendingLogs = <Log>[];

    Future<_WriteFailure?> commit(int nextLogIndex) async {
      if (pending.isEmpty) return null;

      final bytes = pending.takeBytes();
      final committingLogs = List<Log>.of(pendingLogs);
      pendingLogs.clear();
      try {
        await _appendToCurrent(bytes);
      } on Object catch (error, stackTrace) {
        return (
          error: error,
          stackTrace: stackTrace,
          uncommittedLogs: [
            ...committingLogs,
            for (var i = nextLogIndex; i < logs.length; i++) logs[i].log,
          ],
        );
      }

      return null;
    }

    for (var i = 0; i < logs.length; i++) {
      final (:log, :line) = logs[i];
      if (_chunkSize == 0 && pending.isEmpty) {
        pending.add(_metaLineBytes);
      }
      pending.add(utf8.encode('$line\n'));
      pendingLogs.add(log);

      if (_chunkSize + pending.length >= target) {
        final failure = await commit(i + 1);
        if (failure != null) return failure;
        await _closeCurrentChunk(reportErrors: true);
        _chunkIndex++;
        _chunkSize = 0;
        await _deleteOldestChunksReported();
      }
    }

    final failure = await commit(logs.length);
    if (failure != null) return failure;
    if (_chunkSize >= target) {
      await _closeCurrentChunk(reportErrors: true);
      _chunkIndex++;
      _chunkSize = 0;
    }
    await _deleteOldestChunksReported();

    return null;
  }

  Future<void> _reserveCurrentChunk() async {
    while (true) {
      final file = File(
        '$directory/${chunkName(_sessionId, _chunkIndex)}',
      );
      try {
        await file.create(exclusive: true);
      } on FileSystemException catch (error, stackTrace) {
        if (_entityTypeNoFollow(file.path) == FileSystemEntityType.notFound) {
          rethrow;
        }
        _report(error, stackTrace);
        _chunkIndex++;
        continue;
      }
      _currentChunk = await file.open(mode: FileMode.writeOnlyAppend);
      return;
    }
  }

  Future<void> _appendToCurrent(List<int> bytes) async {
    if (_currentChunk == null) {
      await _reserveCurrentChunk();
    }
    await _currentChunk!.writeFrom(bytes);
    await _currentChunk!.flush();
    _chunkSize += bytes.length;
    _chunkSizes[_chunkIndex] = _chunkSize;
  }

  Future<void> _closeCurrentChunk({required bool reportErrors}) async {
    final chunk = _currentChunk;
    if (chunk == null) return;
    _currentChunk = null;
    try {
      await chunk.close();
    } on Object catch (error, stackTrace) {
      if (!reportErrors) rethrow;
      _report(error, stackTrace);
    }
  }

  /// After a write failure the current chunk may hold a partially written
  /// line, so the next chunk is started: otherwise the following record
  /// would join that fragment into invalid JSONL. The tracked size is
  /// reconciled with the actual one as well.
  Future<void> _recoverAfterWriteError() async {
    final chunk = _currentChunk;
    if (chunk != null) {
      try {
        _chunkSizes[_chunkIndex] = await chunk.length();
      } on Object catch (error, stackTrace) {
        _report(error, stackTrace);
      }
    }
    await _closeCurrentChunk(reportErrors: true);
    _chunkIndex++;
    _chunkSize = 0;
  }

  /// Deletes the oldest chunks while the session's total exceeds
  /// [maxSessionSize]. The most recently written chunk is never deleted.
  Future<void> _deleteOldestChunks() async {
    var total = _chunkSizes.values.fold(0, (sum, size) => sum + size);
    while (total > maxSessionSize && _chunkSizes.length > 1) {
      final oldest = _chunkSizes.keys.reduce((a, b) => a < b ? a : b);
      final file = File('$directory/${chunkName(_sessionId, oldest)}');
      if (_isRegularFilePath(file.path)) {
        await file.delete();
      }
      total -= _chunkSizes.remove(oldest)!;
    }
  }

  Future<void> _deleteOldestChunksReported() async {
    try {
      await _deleteOldestChunks();
    } on Object catch (error, stackTrace) {
      _report(error, stackTrace);
    }
  }

  /// A placeholder line for a log that failed to encode.
  ///
  /// Only the error TYPE reaches the file. The error text may carry the
  /// very data it was raised about — a sanitizer rule that refuses a
  /// value by throwing (`ArgumentError.value(ctx.value)` is the natural
  /// form) puts the secret straight into `toString()`, and the file is
  /// exactly where it must not end up. The full error object goes to
  /// [onError] and nowhere else.
  String _encodeFallback(Log log, Object error) => jsonEncode(<String, Object?>{
        'num': log.num,
        'level': log.level,
        'levelName': log.levelName,
        'time': log.time.toUtc().toIso8601String(),
        'encodeError': error.runtimeType.toString(),
      });

  void _rememberDurabilityFailure(Object error, StackTrace stackTrace) {
    _durabilityFailure ??= (error, stackTrace);
  }

  void _throwIfDurabilityFailed() {
    if (_durabilityFailure case (final error, final stackTrace)) {
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  void _report(Object error, StackTrace stackTrace) {
    try {
      onError?.call(error, stackTrace);
    } on Object {
      // A user's onError must not break the write pipeline or leave
      // flush() hanging.
    }
  }
}
