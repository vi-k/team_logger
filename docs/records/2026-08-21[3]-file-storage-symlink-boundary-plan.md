# File Storage Symlink Boundary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

> **Состояние на 2026-08-21:** план готов после одобрения спеки, реализация не
> начата.
> **Что это:** TDD-план исправления находок ревью №2 и №12.
> **Связанные записи:** `2026-08-21[2]-file-storage-symlink-boundary-design.md`,
> `2026-08-21[1]-project-review.md`.

**Goal:** Не позволять chunk-symlink читать или изменять файлы вне каталога
логов и завершать `close()` только после всего файлового lifecycle.

**Architecture:** Reader принимает только regular files по no-follow
проверке при листинге и повторяет проверку непосредственно перед чтением или
удалением. Writer эксклюзивно создаёт каждый чанк, держит один
`RandomAccessFile` открытым до ротации и пишет только через него; `close()`
дожидается init, drain и закрытия handle.

**Tech Stack:** Dart 3.6+, `dart:io`, `package:test`, существующие
`logger_builder` и `archive`; новых зависимостей нет.

**Spec:** `docs/records/2026-08-21[2]-file-storage-symlink-boundary-design.md`

## Global Constraints

- Публичные сигнатуры и JSONL-формат не меняются.
- Каталог логов — приватный доверенный каталог приложения; чистый Dart даёт
  best-effort защиту, но не атомарный `O_NOFOLLOW` и не защиту от hostile
  concurrent actor или hardlink.
- Минимальный SDK остаётся `^3.6.0`; платформенный FFI и новые зависимости не
  добавляются.
- Ошибка записи по-прежнему уходит в `onError`, а соответствующий батч не
  retry'ится; изменение результата `flush()` относится к находке №3.
- Квоты oversized record и память ZIP относятся к находкам №4 и №5 и здесь
  не меняются.
- Публичные README, CHANGELOG и dartdoc пишутся по-английски; записи в
  `docs/records/` и handoff — по-русски.
- Все shell-команды в этой среде запускаются через `rtk`; работа идёт прямо
  в `main`, как требует `AGENTS.md`.

## Карта файлов

- `lib/src/file_storage/file_log_sessions.dart` — no-follow листинг,
  повторная проверка чанка перед read/delete.
- `lib/src/file_storage/file_log_storage.dart` — эксклюзивная резервация,
  открытый writer handle, recovery и полный close lifecycle.
- `test/file_storage/file_log_sessions_test.dart` — reader/export/archive/
  delete regression tests на реальной файловой системе.
- `test/file_storage/file_log_storage_test.dart` — writer, cleanup и close
  regression tests.
- `README.md`, `CHANGELOG.md`, `docs/architecture.md` и dartdoc двух классов
  — публичный и устойчивый контракт.
- `docs/records/2026-08-21[1]-project-review.md` — вердикты находок №2/№12.
- `docs/records/2026-08-21[2]-file-storage-symlink-boundary-design.md`, этот
  план, новый итоговый report и `docs/handoff.md` — состояние работы.

---

### Task 1: No-follow reader and cleanup

**Files:**

- Modify: `test/file_storage/file_log_sessions_test.dart`
- Modify: `test/file_storage/file_log_storage_test.dart`
- Modify: `lib/src/file_storage/file_log_sessions.dart:50-246`
- Modify: `lib/src/file_storage/file_log_storage.dart:250-285,345-357`
- Modify: `docs/handoff.md`

**Interfaces:**

- Consumes: существующие `FileLogSessions.list()`, `FileLogSession.read()`,
  `readMeta()` и `delete()`.
- Produces: reader helper `_isRegularFile(File file) -> bool`; writer helpers
  `_entityTypeNoFollow(String path) -> FileSystemEntityType` и
  `_isRegularFilePath(String path) -> bool`. Все reader/cleanup пути
  пропускают сущность, если no-follow type не равен
  `FileSystemEntityType.file`.

- [ ] **Step 1: Add a real-filesystem symlink helper to both test files**

  Перед телом теста назвать мутацию: удаление no-follow проверки должно
  включить ссылку обратно в session или открыть её target.

  ```dart
  Future<bool> _createLinkOrSkip(Link link, String target) async {
    try {
      await link.create(target);
      return true;
    } on FileSystemException catch (error) {
      markTestSkipped('Symlink creation is unavailable: $error');
      return false;
    }
  }
  ```

- [ ] **Step 2: Write failing reader boundary tests**

  В `file_log_sessions_test.dart` добавить отдельные тесты:

  ```dart
  test('list ignores symlinks with chunk names', () async {
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

  test('read and readMeta skip a chunk replaced by a symlink', () async {
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
  ```

  Добавить ещё два независимых теста с тем же arrange:

  - `exportTo skips a chunk replaced by a symlink` — передать snapshot-session
    в `sessions:` и проверить, что созданный JSONL не содержит
    `outside-secret`;
  - `archiveTo skips a chunk replaced by a symlink` — распаковать ZIP через
    `ZipDecoder` и проверить содержимое `s1.jsonl`.

  Добавить `delete skips a chunk replaced by a symlink`: после snapshot
  заменить путь ссылкой, вызвать `session.delete()` и проверить литералами,
  что victim всё ещё равен `outside-secret`, а no-follow type пути равен
  `FileSystemEntityType.link`.

- [ ] **Step 3: Write a failing startup-cleanup test**

  В группе `FileLogStorage cleanup`:

  ```dart
  test('startup cleanup ignores symlinks with chunk names', () async {
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
  ```

- [ ] **Step 4: Run the RED tests**

  Run:

  ```bash
  rtk dart test test/file_storage/file_log_sessions_test.dart \
    -n 'symlink'
  rtk dart test test/file_storage/file_log_storage_test.dart \
    -n 'startup cleanup ignores symlinks'
  ```

  Expected: old `list()` exposes `leak`, late reads contain
  `outside-secret`, and startup cleanup removes the link. A test that errors
  for setup reasons must be corrected until it fails on the unsafe behavior.

- [ ] **Step 5: Implement no-follow listing and late validation**

  В `file_log_sessions.dart` добавить:

  ```dart
  bool _isRegularFile(File file) =>
      FileSystemEntity.typeSync(file.path, followLinks: false) ==
      FileSystemEntityType.file;
  ```

  Перечислять `dir.list(followLinks: false)`, преобразовывать entry в
  `File(entity.path)` и принимать его только при `_isRegularFile(file)`.
  После `statSync()` ещё раз требовать regular-file type, чтобы сузить окно
  между list и snapshot.

  `readMeta()` должен искать первый всё ещё regular чанк и вернуть `{}`, если
  безопасных чанков не осталось. В `read()` переменная `first` переключается
  только после успешной проверки regular file, чтобы первый безопасный чанк
  сохранил meta-строку:

  ```dart
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
  ```

  В `delete()` вызывать `file.delete()` только для `_isRegularFile(file)`.
  `exportTo()` и `archiveTo()` менять не нужно: они потребляют безопасный
  `session.read()`.

- [ ] **Step 6: Apply the same policy to writer-owned path scans**

  В `file_log_storage.dart` определить локальные helpers:

  ```dart
  FileSystemEntityType _entityTypeNoFollow(String path) =>
      FileSystemEntity.typeSync(path, followLinks: false);

  bool _isRegularFilePath(String path) =>
      _entityTypeNoFollow(path) == FileSystemEntityType.file;
  ```

  `_existingSessionIds()` использует
  `Directory(directory).listSync(followLinks: false)` и принимает только
  regular files. `_deleteOldestChunks()` удаляет путь только после такой же
  проверки; map размера очищается даже при подменённом/исчезнувшем пути.

- [ ] **Step 7: Run GREEN and the complete file-storage suite**

  Run:

  ```bash
  rtk dart test test/file_storage/file_log_sessions_test.dart
  rtk dart test test/file_storage/file_log_storage_test.dart
  rtk dart analyze
  rtk dart format --output=none --set-exit-if-changed \
    lib/src/file_storage test/file_storage
  ```

  Expected: all tests pass, analyzer and formatter exit 0.

- [ ] **Step 8: Update handoff and commit Task 1**

  В handoff записать RED-сценарии, новые no-follow инварианты, фактические
  проверки и следующий шаг — writer handle. Commit:

  ```bash
  rtk git add lib/src/file_storage/file_log_sessions.dart \
    lib/src/file_storage/file_log_storage.dart \
    test/file_storage/file_log_sessions_test.dart \
    test/file_storage/file_log_storage_test.dart docs/handoff.md
  rtk git commit -m "fix: ignore symlink log chunks"
  ```

---

### Task 2: Exclusive chunks, persistent writer handle, and complete close

**Files:**

- Modify: `test/file_storage/file_log_storage_test.dart`
- Modify: `lib/src/file_storage/file_log_storage.dart:68-359`
- Modify: `docs/handoff.md`

**Interfaces:**

- Consumes: Task 1 no-follow path policy and existing
  `AsyncPublisherWithBufferBase<Log>` lifecycle.
- Produces: `_currentChunk: RandomAccessFile?`, cached
  `_closeFuture: Future<void>?`, `_reserveCurrentChunk()`,
  `_appendToCurrent(List<int>) -> Future<void>`,
  `_closeCurrentChunk({required bool reportErrors}) -> Future<void>` and
  async `_recoverAfterWriteError() -> Future<void>`.

- [ ] **Step 1: Write the failing next-chunk symlink test**

  Мутация: возврат к path-based `writeAsBytes(...writeOnlyAppend)` должен
  снова изменить victim и провалить тест.

  ```dart
  test('skips a symlink occupying the next chunk path', () async {
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
    expect(File('${tmp.path}/s1.3.jsonl').readAsStringSync(), contains('safe'));
    expect(reports, hasLength(1));
    await storage.close();
  });
  ```

- [ ] **Step 2: Write the failing open-handle path-swap test**

  На Windows тест объявить `skip`, потому что платформа может запрещать
  rename открытого файла. На остальных системах:

  ```dart
  test(
    'keeps writing to the opened chunk after its path is replaced',
    () async {
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
    skip: Platform.isWindows
        ? 'Windows may not rename an opened file'
        : null,
  );
  ```

- [ ] **Step 3: Write the failing close lifecycle test**

  Мутация: удаление `await ready` из close должно оставить
  `readyCompleted == false` после возврата.

  ```dart
  test('close waits for initialization before it completes', () async {
    final logs = Directory('${tmp.path}/logs');
    final storage = FileLogStorage(directory: logs.path, sessionId: 's1');
    var readyCompleted = false;
    storage.ready.whenComplete(() => readyCompleted = true);

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
  ```

- [ ] **Step 4: Make the write-recovery test compatible with handle ownership**

  До production-правки заменить chmod открытого чанка на детерминированный
  сбой создания следующего чанка. Использовать вложенный `logs` directory:
  записать oversized line, дождаться ротации и закрытия чанка 1, переименовать
  `logs` в `unavailable`, опубликовать теряемый батч, вернуть каталог на
  место, затем проверить, что следующий лог записан в более поздний индекс.
  Переименовать тест в
  `recovers into a new chunk after chunk creation failure`.

- [ ] **Step 5: Run RED and characterize recovery**

  Run:

  ```bash
  rtk dart test test/file_storage/file_log_storage_test.dart \
    -n 'next chunk path|opened chunk|close waits|chunk creation failure'
  ```

  Expected: три новых regression-теста падают на старом writer/close;
  обновлённый recovery test проходит и подтверждает существующий переход к
  следующему индексу после I/O failure.

- [ ] **Step 6: Introduce explicit writer ownership**

  Добавить поля:

  ```dart
  RandomAccessFile? _currentChunk;
  Future<void>? _closeFuture;
  ```

  Первый чанк: отдельно выполнить `create(exclusive: true)`, затем открыть
  `FileMode.writeOnlyAppend`, сохранить handle и записать meta через общий
  helper. Ошибку `open()` не трактовать как обычную коллизию session id.

  Следующие чанки резервировать лениво перед первой записью:

  ```dart
  Future<void> _reserveCurrentChunk() async {
    while (true) {
      final file = File(
        '$directory/${chunkName(_sessionId, _chunkIndex)}',
      );
      try {
        await file.create(exclusive: true);
      } on FileSystemException catch (error, stackTrace) {
        if (_entityTypeNoFollow(file.path) ==
            FileSystemEntityType.notFound) {
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
  ```

  `_appendToCurrent(bytes)` вызывает только
  `RandomAccessFile.writeFrom(bytes)` и `flush()`, затем обновляет
  `_chunkSize`/`_chunkSizes`. `_write()` больше не создаёт `File` в
  `commit()`; при null handle вызывает `_reserveCurrentChunk()`, затем общий
  append helper.

- [ ] **Step 7: Close handles at every ownership boundary**

  Перед увеличением индекса при ротации закрыть текущий handle. После write
  failure async `_recoverAfterWriteError()` получает фактическую длину через
  открытый handle, best-effort закрывает его, обнуляет ownership и только
  затем увеличивает индекс; path-based `statSync()` удалить.

  `close()` сохранить как одну cached операцию:

  ```dart
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
  ```

  `_closeCurrentChunk(reportErrors: false)` на ротации пробрасывает ошибку в
  существующий write-error path. В recovery и финальном close использовать
  `reportErrors: true`: helper обнуляет `_currentChunk` до `await close()`, а
  исключение передаёт в `_report`, не пытаясь повторно закрыть тот же handle.

  Ошибка финального close передаётся в `_report` и не оставляет запланированных
  файловых операций. В `handle()` ждать async recovery через `await`.

- [ ] **Step 8: Run GREEN and regression tests**

  Run:

  ```bash
  rtk dart test test/file_storage/file_log_storage_test.dart
  rtk dart test test/file_storage/file_log_sessions_test.dart
  rtk dart analyze
  rtk dart format --output=none --set-exit-if-changed \
    lib/src/file_storage test/file_storage
  ```

  Expected: file-storage suite passes with no warnings. Повторить targeted
  symlink tests отдельно и убедиться, что victim literals не меняются.

- [ ] **Step 9: Update handoff and commit Task 2**

  Записать в handoff фактические RED/GREEN результаты и оставшиеся проверки.
  Commit:

  ```bash
  rtk git add lib/src/file_storage/file_log_storage.dart \
    test/file_storage/file_log_storage_test.dart docs/handoff.md
  rtk git commit -m "fix: keep log chunk handles open"
  ```

---

### Task 3: Public contract, review verdicts, and full verification

**Files:**

- Modify: `lib/src/file_storage/file_log_storage.dart:17-44,66-72`
- Modify: `lib/src/file_storage/file_log_sessions.dart:50-58,166-177`
- Modify: `README.md:1396-1491`
- Modify: `CHANGELOG.md` under `0.7.0`
- Modify: `docs/architecture.md:190-209`
- Modify: `docs/records/2026-08-21[1]-project-review.md`
- Modify: `docs/records/2026-08-21[2]-file-storage-symlink-boundary-design.md`
- Modify: `docs/records/2026-08-21[3]-file-storage-symlink-boundary-plan.md`
- Create: `docs/records/2026-08-21[4]-file-storage-symlink-boundary-report.md`
- Modify: `docs/handoff.md`

**Interfaces:**

- Consumes: Task 1 no-follow reader и Task 2 exclusive/open-handle writer.
- Produces: документированный best-effort security/lifecycle contract и
  закрытые вердикты ревью №2/№12.

- [ ] **Step 1: Update public English documentation**

  В dartdoc `FileLogStorage` и README после описания directory добавить по
  смыслу следующий текст:

  ```text
  Use an application-private directory. Symlinks and other non-regular
  entries are ignored, and each chunk is created exclusively and kept open
  while active. This is best-effort protection against accidental or
  pre-existing links, not a sandbox against another process that can race
  filesystem operations in the same directory.
  ```

  В lifecycle-описании явно указать: `close()` waits for initialization,
  drains accepted logs, and closes the active chunk handle. В dartdoc
  `FileLogSessions` указать, что list/read/delete игнорируют non-regular
  entries.

  В CHANGELOG добавить два `Fixed`-пункта: chunk symlinks больше не выводят
  чтение/append за каталог; immediate close больше не завершается до init и
  закрытия текущего handle.

- [ ] **Step 2: Run preliminary complete verification**

  Run:

  ```bash
  rtk dart format .
  rtk dart format --output=none --set-exit-if-changed .
  rtk dart analyze
  rtk dart test
  rtk dart pub publish --dry-run
  rtk scripts/screenshots.sh --check
  ```

  Then from `example/`:

  ```bash
  rtk dart pub get
  rtk dart analyze
  rtk dart run example.dart
  rtk dart run bin/file_storage_example.dart
  ```

  Expected: formatter changes 0 files on second run; root/example analyze
  clean; all tests pass; dry-run has 0 warnings; 41 screenshot frames match;
  both examples exit 0.

- [ ] **Step 3: Inspect the complete diff and request code review**

  Run:

  ```bash
  rtk git diff --check
  rtk git status --short
  rtk git diff HEAD~2 -- lib test README.md CHANGELOG.md docs
  ```

  Apply `superpowers:requesting-code-review` to the complete implementation.
  Исправить все подтверждённые замечания отдельным RED/GREEN циклом и
  отдельным кодовым коммитом; повторить затронутые проверки.

- [ ] **Step 4: Run final verification after review**

  Применить `superpowers:verification-before-completion` и заново выполнить
  весь набор команд Step 2 после последних исправлений. Только этот свежий
  вывод использовать как итоговое доказательство.

- [ ] **Step 5: Update stable architecture and live records**

  В `docs/architecture.md` кратко зафиксировать private-directory threat
  model, exclusive chunk reservation, open writer handle и no-follow reader.

  Не меняя исходный текст ревью, дописать к находкам №2 и №12 вердикты:
  поведение закрыто real-filesystem regression-тестами; полная защита от
  hostile TOCTOU/hardlink не заявляется. Шапки design и plan перевести в
  состояние «реализовано и проверено».

  Создать report с разделами: исходный дефект, принятое решение, изменения,
  фактически наблюдавшиеся RED-ошибки, свежие GREEN/полные проверки,
  ограничения и созданные коммиты. Handoff оставить restart-ready и назвать
  следующий открытый пункт ревью №3 только после описания самой находки.

- [ ] **Step 6: Commit documentation and final status**

  Добавить только файлы этой работы и создать документальный коммит:

  ```bash
  rtk git add README.md CHANGELOG.md docs/architecture.md \
    lib/src/file_storage/file_log_storage.dart \
    lib/src/file_storage/file_log_sessions.dart \
    'docs/records/2026-08-21[1]-project-review.md' \
    'docs/records/2026-08-21[2]-file-storage-symlink-boundary-design.md' \
    'docs/records/2026-08-21[3]-file-storage-symlink-boundary-plan.md' \
    'docs/records/2026-08-21[4]-file-storage-symlink-boundary-report.md' \
    docs/handoff.md
  rtk git commit -m "docs: record symlink-safe file storage"
  rtk git status --short --branch
  ```

  Expected: working tree clean; `main` ahead of `origin/main`; push не
  выполнять без запроса владельца.
