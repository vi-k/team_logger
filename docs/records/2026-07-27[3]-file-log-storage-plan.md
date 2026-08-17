> **Состояние на 2026-08-17:** выполнен полностью (`12edda6`), релиз 0.4.0.
> **Что это:** пошаговый план реализации `FileLogStorage` по спеке
> `2026-07-27[2]-file-log-storage-design.md`.
> **Связанные записи:** `2026-07-27[2]-file-log-storage-design.md`.

# FileLogStorage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Сессионное сохранение логов в JSONL-файлы с ротацией чанков, очисткой по TTL/суммарному размеру, листингом, экспортом и ZIP-архивацией — по спеке `docs/records/2026-07-27[2]-file-log-storage-design.md`.

**Architecture:** Новый publisher `FileLogStorage extends AsyncPublisherWithBufferBase<Log>` (батчевая асинхронная запись). Кодек Log→JSONL и meta-строка — отдельный модуль. Листинг/чтение/экспорт/архив — `FileLogSessions`/`FileLogSession`. Всё в `lib/src/file_storage/`, экспортируется новым `lib/team_logger_io.dart` (dart:io недопустим в `team_logger.dart`).

**Tech Stack:** Dart ^3.6.0, `dart:io`, `package:archive` ^4.0.9 (ZIP), `package:clock` (время в тестах), `package:test`.

## Global Constraints

- Версия пакета остаётся `0.4.0`; запись в CHANGELOG — в существующую секцию 0.4.0.
- `dart analyze` без замечаний (strict-casts/inference/raw-types, prefer_single_quotes, require_trailing_commas, omit_local_variable_types, cascade_invocations, sort_pub_dependencies и пр.).
- `dart format .` перед каждым коммитом.
- `lib/team_logger.dart` не должен импортировать/экспортировать ничего с dart:io.
- Имена файлов чанков: `<sessionId>.<index>.jsonl`, index с 1, монотонный.
- Meta-строка `{":meta":{...}}` — первой строкой каждого чанка, всегда.
- Работа ведётся на ветке `feature/file-log-storage`.

---

### Task 1: Кодек — Log → JSONL-строка, meta-строка

**Files:**
- Create: `lib/src/file_storage/file_log_codec.dart`
- Test: `test/file_storage/file_log_codec_test.dart`

**Interfaces (Produces):**
```dart
enum FileLogDataFormat { text, json }

final class FileLogCodec {
  FileLogCodec({
    FileLogDataFormat dataFormat = FileLogDataFormat.text,
    LogMainTheme? theme,                       // null -> LogMainTheme.noColors
    LoggableConfig config = const LoggableConfig(),
    LoggableJsonConfig jsonConfig = const LoggableJsonConfig(),
  });

  /// Без завершающего \n.
  String encode(Log log);

  /// {"​:meta":{"sessionId":...,"started":<UTC ISO>,...meta}} без \n.
  String encodeMeta({
    required String sessionId,
    required DateTime started,
    Map<String, Object?>? meta,
  });

  static const metaKey = ':meta';
}
```

- [ ] Тесты: полная схема (num/level/levelName/time UTC ISO-8601/path/traceIds/message/tags/data/error/stackTrace через jsonDecode); опускание пустых полей (пустые traceIds/tags/path? — path пишется если непустой; data только при hasData; error/stackTrace при наличии); data в text-режиме (строка `objectToString`) и json-режиме (объект `objectToJson`); ANSI сохраняется при цветной теме (defaultActiveTheme); BBCode `[b]…[/b]` компилируется в message (noColors → чистый текст); encodeMeta: авто-поля, пользовательские поля, перезапись зарезервированных `sessionId`/`started` пакетом.
- [ ] Реализация: message → `theme[log.level]` → `formatMessage(formatValue(...))`; data text → `Loggable.objectToString(log.data, theme: theme[log.level], config: config)`; data json → `Loggable.objectToJson(log.data, config: jsonConfig)`; time → `log.time.toUtc().toIso8601String()`; traceIds → `map(toString)`; сериализация — `dart:convert` jsonEncode. Логи создавать в тестах через реальный `Logger` с публикацией в буфер-заглушку (получить Log из publisher).
- [ ] `dart test test/file_storage/file_log_codec_test.dart` — PASS; `dart analyze` — clean.
- [ ] Commit `feat: add FileLogCodec (Log -> JSONL line, meta line)`.

### Task 2: Имена сессий/чанков + FileLogSessions (листинг, чтение, удаление)

**Files:**
- Create: `lib/src/file_storage/file_log_sessions.dart`
- Test: `test/file_storage/file_log_sessions_test.dart`

**Interfaces (Produces):**
```dart
final class FileLogSessions {
  FileLogSessions(String directory);
  final String directory;
  Future<List<FileLogSession>> list();                 // старые -> новые
  Future<List<File>> exportTo(Directory target, {Iterable<FileLogSession>? sessions}); // Task 6
  Future<void> archiveTo(File target, {Iterable<FileLogSession>? sessions});           // Task 7
}

final class FileLogSession {
  String get id;
  List<File> get files;
  int get size;
  DateTime get lastModified;
  Future<Map<String, Object?>> readMeta();
  Stream<List<int>> read();          // конкатенация; meta-строки чанков >1 пропускаются
  Future<String> readAsString();
  Future<void> delete();
}

// внутренние помощники (там же):
String defaultSessionId(DateTime nowUtc);     // yyyyMMdd-HHmmss-micro(6)
String sanitizeSessionId(String raw);         // недопустимые символы и '.' -> '_'
({String sessionId, int index})? parseChunkName(String fileName);
String chunkName(String sessionId, int index); // '<id>.<index>.jsonl'
```

- [ ] Тесты (файлы создаются вручную во временной папке): `parseChunkName`/`chunkName` раундтрип, отбрасывание чужих файлов (`foo.txt`, `bar.jsonl`, `a.b.c.jsonl` → sessionId `a.b`? нет: sessionId не содержит точек — `a.b.c.jsonl` не матчится т.к. `b`… матчится как id=`a.b`? Правило: имя матчится строго `^(.+)\.(\d+)\.jsonl$` и id дополнительно не должен содержать `.` — иначе игнор); `defaultSessionId` формат и лексикографический порядок; `sanitizeSessionId`; `list()` — группировка по id, порядок чанков по индексу (в т.ч. 9 < 10, т.е. численно), сортировка сессий по lastModified, size = сумма; `readMeta()`; `read()`/`readAsString()` — дедупликация meta-строк; `delete()` удаляет все чанки сессии.
- [ ] Реализация: list() через `Directory.list()`, `FileStat` для size/modified; сортировка сессий по max(lastModified чанков); read() — стрим по файлам, для чанков после первого пропустить первую строку (байтово: до первого 0x0A включительно).
- [ ] `dart test`, `dart analyze`; Commit `feat: add FileLogSessions listing and reading`.

### Task 3: FileLogStorage — инициализация и запись

**Files:**
- Create: `lib/src/file_storage/file_log_storage.dart`
- Test: `test/file_storage/file_log_storage_test.dart`

**Interfaces (Produces):** конструктор по спеке (directory, sessionId, meta, minLevel, maxSize, chunks, maxTotalSize, maxAge, dataFormat, theme, config, jsonConfig, onError); `String get directory`, `String get sessionId`, `FileLogSessions get sessions`; унаследованные `publish/flush/close`.

- [ ] Тесты: publish → flush → файл `<id>.1.jsonl` с meta-строкой + строками логов; логи до завершения инициализации не теряются; `minLevel` фильтрует; sessionId по умолчанию из времени старта (withClock), пользовательский — санитизация, коллизия → суффикс `-1`; повторный `flush` идемпотентен; `close()` дописывает всё; onError при недоступной папке (directory = путь существующего ФАЙЛА), storage отключается и не кидает.
- [ ] Реализация: `_init` future в конструкторе (mkdir recursive → cleanup (Task 5, пока заглушка) → выбор id без коллизий по существующим файлам); `handle(batch, retry)` — await init (если init упал: return), encode всех строк, lazy-открытие текущего чанка с meta-строкой, `writeAsString(..., mode: FileMode.append)` или IOSink append + flush; ошибки → onError, батч отброшен (retryBuffer не используется).
- [ ] `dart test`, `dart analyze`; Commit `feat: add FileLogStorage publisher (session files, batching)`.

### Task 4: Ротация чанков

**Files:**
- Modify: `lib/src/file_storage/file_log_storage.dart`
- Test: `test/file_storage/file_log_storage_test.dart` (группа `rotation`)

- [ ] Тесты (маленькие maxSize/chunks, например maxSize=400, chunks=4 → target=100): при переполнении открывается `.2.jsonl` с meta-строкой; старейшие чанки удаляются когда суммарный размер > maxSize; текущий чанк не удаляется даже если один больше maxSize; строка длиннее target пишется целиком; индексы монотонны (после удаления `.1` следующий — `.N+1`).
- [ ] Реализация: track текущий index и размер чанка; после записи батча: если размер ≥ target → закрыть sink, index++, при следующей записи создать новый чанк; после открытия нового — удалять чанки с минимальным индексом пока сумма размеров > maxSize (текущий не трогать).
- [ ] `dart test`, `dart analyze`; Commit `feat: chunk rotation in FileLogStorage`.

### Task 5: Очистка на старте — TTL и maxTotalSize

**Files:**
- Modify: `lib/src/file_storage/file_log_storage.dart`
- Test: `test/file_storage/file_log_storage_test.dart` (группа `cleanup`)

- [ ] Тесты (старые файлы создаются вручную + `File.setLastModified`): сессии старше maxAge удаляются целиком, свежие остаются; `maxAge: null` — не удаляет; maxTotalSize: старейшие удаляются пока сумма остальных > maxTotalSize − maxSize; текущая сессия не удаляется; чужие файлы (`notes.txt`) не трогаются.
- [ ] Реализация в `_init` (после mkdir, до выбора id — нет: id выбирается от коллизий с уже очищенным списком; порядок: mkdir → скан → TTL → totalSize → выбор id).
- [ ] `dart test`, `dart analyze`; Commit `feat: startup cleanup (TTL, max total size)`.

### Task 6: exportTo — файл на сессию

**Files:**
- Modify: `lib/src/file_storage/file_log_sessions.dart`
- Test: `test/file_storage/file_log_sessions_test.dart` (группа `export`)

- [ ] Тесты: по одному `<id>.jsonl` в target на сессию; содержимое = meta-строка (одна) + все строки чанков по порядку; подмножество через `sessions:`; перезапись существующего; target создаётся рекурсивно; возвращает созданные файлы; экспорт в саму папку логов не ломает последующий list().
- [ ] Реализация поверх `session.read()`.
- [ ] `dart test`, `dart analyze`; Commit `feat: export sessions to separate files`.

### Task 7: archiveTo — один ZIP на несколько сессий

**Files:**
- Modify: `pubspec.yaml` (dependencies: `archive: ^4.0.9`, соблюдая sort_pub_dependencies)
- Modify: `lib/src/file_storage/file_log_sessions.dart`
- Test: `test/file_storage/file_log_sessions_test.dart` (группа `archive`)

- [ ] Тесты: ZIP-раундтрип (`ZipDecoder`) — по entry `<id>.jsonl` на сессию, содержимое побайтно равно exportTo-файлу; подмножество сессий; перезапись существующего target.
- [ ] Реализация: собрать содержимое каждой сессии (через тот же код, что exportTo), `Archive` + `ArchiveFile` + `ZipEncoder` (API уточнить по archive 4.0.9), записать байты в target.
- [ ] `dart test`, `dart analyze`; Commit `feat: archive sessions into a single zip`.

### Task 8: Публичный экспорт team_logger_io.dart

**Files:**
- Create: `lib/team_logger_io.dart` (`export 'team_logger.dart';` + `export 'src/file_storage/...';`)
- Test: `test/file_storage/io_export_test.dart` — импорт только `package:team_logger/team_logger_io.dart` и использование FileLogStorage/FileLogSessions/FileLogDataFormat компилируется.

- [ ] Проверка: `team_logger.dart` не тянет dart:io (grep по export'ам).
- [ ] Полный прогон: `dart test`, `dart analyze`, `dart format .`.
- [ ] Commit `feat: add team_logger_io library export`.

### Task 9: Документация и пример

**Files:**
- Modify: `README.md` (раздел «Saving logs to files»), `CHANGELOG.md` (секция 0.4.0), `TODO.md` (при необходимости)
- Modify: `example/` — пример использования FileLogStorage + archiveTo (отдельный bin/file_storage_example.dart)

- [ ] README: мотивация, минимальный пример (создание, flush, экспорт/архив), описание формата файла и параметров.
- [ ] CHANGELOG 0.4.0: фича-запись.
- [ ] Пример запускается: `cd example && dart run bin/file_storage_example.dart`.
- [ ] Полный прогон тестов/analyze/format в корне и в example.
- [ ] Commit `docs: file storage docs and example`.

## Self-Review

- Покрытие спеки: формат строки (T1), meta (T1/T3), имена/листинг/чтение (T2), запись/жизненный цикл/ошибки (T3), ротация (T4), TTL+суммарный лимит (T5), exportTo (T6), archiveTo+зависимость (T7), io-экспорт/кроссплатформенность (T8), README/CHANGELOG/example (T9). Отправка логов — вне скоупа. ✓
- Типы/сигнатуры между задачами согласованы (FileLogCodec использует enum из T1; T6/T7 — методы объявлены в интерфейсе T2). ✓
