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

/// A publisher that stores logs on disk, one session per application run.
///
/// Use an application-private directory. Symlinks and other non-regular
/// entries are ignored, and each chunk is created exclusively and kept open
/// while active. This is best-effort protection against accidental or
/// pre-existing links, not a sandbox against another process that can race
/// filesystem operations in the same directory.
///
/// A session is a chain of chunk files `<sessionId>.<index>.jsonl`, each
/// limited by [maxChunkSize]. The session is limited by [maxSessionSize]:
/// when the limit is exceeded, the oldest chunk is deleted, so the most
/// recent logs are always kept. On startup, sessions older than [maxAge]
/// are deleted, and, if [maxTotalSize] is set, the oldest sessions are
/// deleted until the rest fit into the limit. The number of chunks and
/// sessions is not limited — only sizes are.
///
/// Logs are written in batches in the background; `await flush()` guarantees
/// everything published so far is on disk. After [close] publications are
/// silently ignored. [close] waits for initialization, drains accepted logs,
/// and closes the active chunk handle.
///
/// [onError] is called on initialization, encoding and write errors. Errors
/// are never thrown; exceptions thrown by the callback itself are ignored.
///
/// The queue between `publish` and the disk is bounded by [maxQueueSize] —
/// 100 000 logs accepted and not yet written, the batch in flight included.
/// At the limit it is the *incoming* log that is refused, so a disk that
/// cannot keep up costs the newest logs rather than the process; everything
/// already accepted is still written, and [flush] and [close] keep their
/// meaning. A refused log goes to [onDropped], and with no [onDropped] set
/// the loss is announced on stdout rather than hidden — pass
/// `onDropped: (_) {}` for silence. This is the only way a log is lost
/// after being accepted: a failed write is reported to [onError] and never
/// retried, so the retry budget of the base class does not come into play
/// here.
final class FileLogStorage extends AsyncPublisherWithBufferBase<Log> {
  /// The directory the session files are stored in (created recursively).
  final String directory;

  /// User fields of the metadata line written as the first line of every
  /// chunk.
  final Map<String, Object?>? meta;

  final int minLevel;

  /// Total size limit of one session, in bytes.
  final int maxSessionSize;

  /// Size limit of one chunk file, in bytes. When a chunk reaches it, the
  /// next chunk is started. Must fit into [maxSessionSize] at least twice.
  final int maxChunkSize;

  /// Total size limit of all sessions together, in bytes. `null` — no limit.
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

  /// Размеры чанков текущей сессии на диске (индекс -> байты).
  final Map<int, int> _chunkSizes = {};

  FileLogStorage({
    required this.directory,
    String? sessionId,
    this.meta,
    this.minLevel = LogLevels.all,
    this.maxTotalSize,
    this.maxSessionSize = 10 * 1024 * 1024,
    this.maxChunkSize = 1024 * 1024,
    this.maxAge = const Duration(days: 7),
    FileLogDataFormat dataFormat = FileLogDataFormat.text,
    LogMainTheme? theme,
    LoggableConfig config = const LoggableConfig(),
    LoggableJsonConfig jsonConfig = const LoggableJsonConfig(),
    super.onError,
    super.onDropped,
    super.maxQueueSize,
  })  : assert(maxChunkSize > 0, 'maxChunkSize must be positive'),
        assert(
          maxSessionSize >= 2 * maxChunkSize,
          'maxSessionSize must fit at least two chunks '
          '(maxSessionSize >= 2 * maxChunkSize)',
        ),
        assert(
          maxTotalSize == null || maxTotalSize >= maxSessionSize,
          'maxTotalSize must be >= maxSessionSize',
        ),
        _codec = FileLogCodec(
          dataFormat: dataFormat,
          theme: theme,
          config: config,
          jsonConfig: jsonConfig,
        ),
        _started = clock.now() {
    _sessionId = sanitizeSessionId(sessionId ?? defaultSessionId(_started));
    // Инициализация стартует в фоне, future сохраняется в [ready].
    // ignore: discarded_futures
    ready = _init();
  }

  /// The id of the current session.
  ///
  /// May get a numeric suffix during initialization if a session with the
  /// same id already exists on disk (see [ready]).
  String get sessionId => _sessionId;

  /// Reader for the sessions stored in [directory], including the current
  /// one.
  FileLogSessions get sessions => FileLogSessions(directory);

  @override
  void publish(Log log) {
    // После close публикация — no-op: базовый publish бросил бы StateError
    // в точку логирования, а буфер никогда не был бы обработан.
    if (_closed) return;

    super.publish(log);
  }

  @override
  Future<void> flush() async {
    // flush гарантирует не только запись опубликованного (drain-семантика
    // базового flush), но и завершение инициализации: первый чанк с
    // meta-строкой уже на диске.
    await ready;
    await super.flush();
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
  }

  @override
  Future<void> handle(List<Log> logs, List<Log> retryBuffer) async {
    // Батч не возвращается в retryBuffer: при недоступном диске это дало бы
    // бесконечные повторы и рост памяти.
    try {
      await ready;
      if (_disabled) return;

      final lines = <String>[];
      for (final log in logs) {
        if (log.level < minLevel) continue;
        try {
          lines.add(_codec.encode(log));
        } on Object catch (error, stackTrace) {
          // Ошибка кодирования одного лога (бросающий toString и т.п.)
          // не должна терять соседние логи батча.
          _report(error, stackTrace);
          lines.add(_encodeFallback(log, error));
        }
      }

      if (lines.isNotEmpty) {
        try {
          await _write(lines);
        } on Object catch (error, stackTrace) {
          _report(error, stackTrace);
          await _recoverAfterWriteError();
        }
      }
    } on Object catch (error, stackTrace) {
      _report(error, stackTrace);
    }
  }

  Future<void> _init() async {
    try {
      await Directory(directory).create(recursive: true);
      await _cleanupOnStartup();

      // Свободный id: сначала по существующим файлам (включая сессии,
      // у которых первый чанк уже удалён ротацией)...
      final existingIds = _existingSessionIds();
      final base = _sessionId;
      var n = 0;
      var candidate = _sessionId;
      while (existingIds.contains(candidate)) {
        n++;
        candidate = '$base-$n';
      }

      // ...затем резервируем сессию, эксклюзивно создавая первый чанк, —
      // защита от гонки двух инстансов с одинаковым id, ещё не успевших
      // ничего записать.
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
      _report(error, stackTrace);
      await _closeCurrentChunk(reportErrors: true);
    }
  }

  /// Удаляет сессии старше [maxAge], затем — старейшие сессии, пока
  /// остальные не влезут в `maxTotalSize - maxSessionSize` (резерв под
  /// рост текущей сессии).
  Future<void> _cleanupOnStartup() async {
    final maxAge = this.maxAge;
    final maxTotalSize = this.maxTotalSize;
    if (maxAge == null && maxTotalSize == null) return;

    // Старые -> новые.
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

  /// Дописывает строки батча в чанки, режа батч по [maxChunkSize],
  /// чтобы один большой батч не раздувал чанк и не выбрасывался ротацией
  /// целиком. Только append: файлы никогда не усекаются.
  Future<void> _write(List<String> lines) async {
    final target = maxChunkSize;
    final pending = BytesBuilder(copy: false);

    Future<void> commit() async {
      if (pending.isEmpty) return;
      await _appendToCurrent(pending.takeBytes());
    }

    for (final line in lines) {
      if (_chunkSize == 0 && pending.isEmpty) {
        pending.add(_metaLineBytes);
      }
      pending.add(utf8.encode('$line\n'));

      if (_chunkSize + pending.length >= target) {
        await commit();
        await _closeCurrentChunk(reportErrors: false);
        _chunkIndex++;
        _chunkSize = 0;
        await _deleteOldestChunks();
      }
    }

    await commit();
    if (_chunkSize >= target) {
      await _closeCurrentChunk(reportErrors: false);
      _chunkIndex++;
      _chunkSize = 0;
    }
    await _deleteOldestChunks();
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

  /// После ошибки записи текущий чанк может содержать частично записанную
  /// строку — переходим на новый чанк, чтобы следующая запись не склеилась
  /// с обрывком в невалидный JSONL, и сверяем учтённый размер с фактическим.
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

  /// Удаляет старейшие чанки, пока суммарный размер сессии превышает
  /// [maxSessionSize]. Последний записанный чанк не удаляется никогда.
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

  void _report(Object error, StackTrace stackTrace) {
    try {
      onError?.call(error, stackTrace);
    } on Object {
      // Пользовательский onError не должен ронять конвейер записи
      // и подвешивать flush().
    }
  }
}
