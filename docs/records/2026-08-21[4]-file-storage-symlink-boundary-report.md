> **Состояние на 2026-08-21:** реализовано, проверено и задокументировано;
> кодовые изменения — `ac40ae9`, `08aa5c0` и `4005f65`, финальное уточнение
> публичного контракта — `28b6ad9`.
> **Что это:** итог работ по находкам project review №2 (symlink boundary)
> и №12 (полный lifecycle `close()`).
> **Связанные записи:** `2026-08-21[1]-project-review.md`,
> `2026-08-21[2]-file-storage-symlink-boundary-design.md`,
> `2026-08-21[3]-file-storage-symlink-boundary-plan.md`.

# Symlink boundary и lifecycle файлового хранилища

Дата: 2026-08-21

## Исходный дефект

`FileLogSessions` следовал по chunk-symlink при листинге и path-based
чтении, поэтому `read()`, export и ZIP могли отдать target за пределами
каталога логов. Writer эксклюзивно резервировал лишь первый chunk; следующий
chunk открывался по имени в append-режиме и мог дописать target заранее
созданной ссылки.

Независимо от этого `close()` при пустой очереди мог завершиться до `ready`:
после `await close()` фоновая инициализация ещё создавала каталог и первый
chunk.

## Принятое решение

Каталог логов является приватным доверенным каталогом приложения. В этой
границе reader принимает только regular files по no-follow проверке, а writer
эксклюзивно создаёт каждый chunk и сохраняет его `RandomAccessFile` открытым
до ротации или закрытия. `close()` ждёт `ready`, drain принятых логов и
закрытие активного handle.

Это намеренно best-effort решение. Обычный переносимый `dart:io` не даёт
атомарный `O_NOFOLLOW | O_EXCL`, поэтому hostile процесс, непрерывно меняющий
каталог, всё ещё может попасть в TOCTOU-окно; hardlink от ordinary file
пакет также не отличает. Гарантия опирается на права приватного каталога.

## Изменения

- `FileLogSessions.list()` перечисляет каталог с `followLinks: false` и
  принимает только regular files; `readMeta()`, `read()` и `delete()`
  повторяют проверку непосредственно перед path-based операцией.
- Startup/rotation cleanup `FileLogStorage` пропускает non-regular entries.
  Каждый новый chunk резервируется через `create(exclusive: true)`; writer
  пишет и flush'ит через один открытый `RandomAccessFile`.
- При занятом следующем индексе writer сообщает ошибку через `onError`,
  пропускает индекс и сохраняет тот же батч в первом свободном chunk.
- `close()` возвращает cached Future, ждёт инициализацию и drain, затем
  закрывает активный handle даже при ошибке базового lifecycle.
- `flush()` после начала закрытия возвращает тот же cached close Future, а
  `isClosed` переключается синхронно.
- Удаление текущей сессии при активном writer объявлено неподдерживаемым;
  real-filesystem тест закрепляет последовательность close → delete.
- README, CHANGELOG и dartdoc объявляют private-directory best-effort
  contract и полный lifecycle `close()`; architecture, design, plan и
  project review синхронизированы с ним.

## Наблюдавшиеся RED-ошибки

Реальные symlink-тесты Task 1 на старом коде показали, что `list()` включал
ссылку, `read()`/export/ZIP читали её target, а startup cleanup удалял саму
ссылку. После no-follow фильтра и повторных проверок этот набор стал GREEN.

Целевой RED Task 2 дал ровно три ожидаемых падения: старый writer изменял
оба victim через symlink, а два вызова `close()` возвращали разные Future.
Уже существующий characterization recovery при этом проходил. После
exclusive reservation и open handle writer-regressions, cached close и
остальные tests стали GREEN.

## Предварительная полная проверка

На рабочем дереве с публичной документацией, до её commit, выполнены:

```text
rtk dart format .                                      94 files, 0 changed
rtk dart format --output=none --set-exit-if-changed .  94 files, 0 changed
rtk dart analyze                                       No issues found
rtk dart test                                          450 tests passed
rtk dart pub publish --dry-run                         archive 155 KB; 1 warning
rtk scripts/screenshots.sh --check                     exit 0; 41 frames match
cd example && rtk dart pub get                         exit 0
cd example && rtk dart analyze                         No issues found
cd example && rtk dart run example.dart                exit 0
cd example && rtk dart run bin/file_storage_example.dart  exit 0
```

Единственный warning dry-run был ожидаемым и не относился к архиву: Dart
обнаружил четыре ещё не закоммиченных tracked public files (`CHANGELOG.md`,
`README.md` и два dart-файла). Повторный fresh dry-run после документального
commit устраняет это предупреждение; его результат добавлен ниже.

## Финальная свежая проверка

После документального commit весь набор повторён на чистом дереве:

```text
rtk dart format .                                      94 files, 0 changed
rtk dart format --output=none --set-exit-if-changed .  94 files, 0 changed
rtk dart analyze                                       No issues found
rtk dart test                                          450 tests passed
rtk dart pub publish --dry-run                         0 warnings, archive 155 KB
rtk scripts/screenshots.sh --check                     exit 0; 41 frames match
cd example && rtk dart pub get                         exit 0
cd example && rtk dart analyze                         No issues found
cd example && rtk dart run example.dart                exit 0
cd example && rtk dart run bin/file_storage_example.dart  exit 0
```

`dart pub get` в example дополнительно сообщил о восьми более новых
несовместимых с ограничениями версиях; это информационный вывод resolver,
не warning analyze/publish и не ошибка команды. Только этот fresh вывод,
включая dry-run без warning о dirty tree, используется как итоговое
доказательство.

Проверки `rtk git diff --check`, `rtk git status --short` и полного diff от
`HEAD~2` уже выполнены; до commit замечания self-review отсутствовали.

## Ограничения и concern на первом закрытии

Полной защиты от hostile TOCTOU и hardlink нет, и публичная документация её
не обещает. Отдельно остаётся deferred Minor: унаследованный `isClosed`
синхронно остаётся `false` между вызовом `close()` и `super.close()`. Эта
работа его не меняла; широкое итоговое ревью должно независимо решить,
существенно ли это для публичного lifecycle-контракта.

Broad review подтвердил concern и закрыл его в `4005f65`: `isClosed` теперь
меняется синхронно. Тем же TDD-циклом `flush()` после начала закрытия
присоединён к полному close Future. Новая явно документированная граница:
удаление текущей сессии поддерживается только после `await storage.close()`;
runtime enforcement не заявляется.

## Созданные коммиты

- `ac40ae9 fix: ignore symlink log chunks`
- `08aa5c0 fix: keep log chunk handles open`
- `8899b94 docs: record symlink-safe file storage`
- `fe9567f docs: qualify symlink boundary guarantee`
- `4005f65 fix: complete file storage close state`
- `28b6ad9 docs: clarify file session lifecycle`

## Дополнение: final fix-wave после broad review

Целевой RED:

```text
rtk dart test test/file_storage/file_log_storage_test.dart \
  -n 'flush after close|isClosed flips|ordinary file occupying|current session after storage'
```

Результат до production-правки: exit 1, `+2 -2`. `flush()` вернул отличный
от close Future (`Actual: false` для identity), а `isClosed` остался `false`
сразу после `close()`. Ordinary-file collision и close→delete прошли сразу
как characterization/coverage.

После `4005f65` тот же набор прошёл `+4`. Финальная проверка после публичного
документального коммита:

```text
rtk dart test test/file_storage/file_log_storage_test.dart  36 passed
rtk dart test test/file_storage/file_log_sessions_test.dart 22 passed
rtk dart test                                             454 passed
rtk dart analyze                                          No issues found
rtk dart format --output=none --set-exit-if-changed .      94 files, 0 changed
rtk dart pub publish --dry-run                             0 warnings, 156 KB
rtk scripts/screenshots.sh --check                         exit 0, 41 frames
```

Broad review также обнаружил устаревшие live counts. После закрытия находок
№1, №2 и №12 остаются 13 исходных находок: 8 Medium и 5 Low.
