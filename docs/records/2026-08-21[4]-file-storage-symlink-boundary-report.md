> **Состояние на 2026-08-21:** реализовано, проверено и задокументировано;
> кодовые изменения — `ac40ae9` и `08aa5c0`.
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

## Ограничения и открытый concern

Полной защиты от hostile TOCTOU и hardlink нет, и публичная документация её
не обещает. Отдельно остаётся deferred Minor: унаследованный `isClosed`
синхронно остаётся `false` между вызовом `close()` и `super.close()`. Эта
работа его не меняла; широкое итоговое ревью должно независимо решить,
существенно ли это для публичного lifecycle-контракта.

## Созданные коммиты

- `ac40ae9 fix: ignore symlink log chunks`
- `08aa5c0 fix: keep log chunk handles open`
- `docs: record symlink-safe file storage` — этот итоговый документальный
  commit.
