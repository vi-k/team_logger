> **Состояние на 2026-08-20:** план выполнен, одно техническое отклонение — см. отчёт; работа в `main`
> (`aee6092`, `f909f7e`, `cc0a3d0`), отчёт —
> `2026-08-20[8]-example-cleanup-report.md`.
> **Что это:** план работ по спеке уборки `example/`.
> **Связанные записи:** `2026-08-20[6]-example-cleanup-design.md`.

# Example cleanup — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Заменить 288-строчную кухню в `example/` одним коротким сквозным
примером, который pub.dev действительно показывает.

**Architecture:** Проверочный «всё подряд» переезжает в `tool/` и не
публикуется. Главным становится self-contained `example/example.dart` —
путь, по которому pub.dev ищет пример. `bin/readme_examples/` и
`lib/readme_examples/` не трогаются вовсе.

**Tech Stack:** Pure Dart. Пример — отдельный пакет с path-зависимостью на
корневой.

**Spec:** `docs/records/2026-08-20[6]-example-cleanup-design.md`

## Global Constraints

- `environment.sdk: ^3.6.0` в обоих пакетах — не поднимать.
- Зелёные проверки после каждой задачи: `dart analyze` в корне и в
  `example/`, `dart test` и `dart format .` в корне.
- Тестов у примеров нет — проверка это запуск. Каждая задача заканчивается
  прогоном всего, что запускается.
- `bin/readme_examples/`, `lib/readme_examples/` и `screenshots/` не
  трогать: скриншоты постановочные и сейчас актуальны, картинки —
  источник истины.
- Записи в `docs/records/` — история, их текст не переписывается; правятся
  только живые документы (`AGENTS.md`, `docs/conventions.md`,
  `docs/handoff.md`).
- Публикацию не запускать и не предлагать.
- Версия остаётся 0.7.0.

---

### Task 1: Кухня переезжает в `tool/`

**Files:**
- Create: `tool/playground.dart` (из `example/bin/example.dart`)
- Create: `tool/playground_data.dart` (из `example/lib/data.dart`)
- Delete: `example/bin/example.dart`, `example/lib/data.dart`
- Modify: `.pubignore`

**Interfaces:**
- Produces: `tool/playground.dart` запускается из корня как
  `dart run tool/playground.dart`; больше ничто в `example/` не
  ссылается на `package:example/data.dart`.

- [ ] **Step 1: Перенести оба файла**

```bash
mkdir -p tool
git mv example/bin/example.dart tool/playground.dart
git mv example/lib/data.dart tool/playground_data.dart
```

- [ ] **Step 2: Починить импорт**

В `tool/playground.dart` заменить

```dart
import 'package:example/data.dart';
```

на

```dart
import 'playground_data.dart';
```

Остальные импорты не трогать: `package:team_logger/team_logger.dart`
работает и из `tool/` — пакет вправе импортировать сам себя по
`package:`-URI, — а `package:format/format.dart` и
`package:stack_trace/stack_trace.dart` есть в корневом `pubspec.yaml`
(первый в `dev_dependencies`, второй в `dependencies`).

- [ ] **Step 3: Не публиковать `tool/`**

В `.pubignore` дописать в конец:

```
# Ручная проверочная кухня — не для pub-архива.
tool/
```

- [ ] **Step 4: Проверить, что всё запускается и анализируется**

Run:
```bash
dart analyze
dart run tool/playground.dart | tail -3
cd example && dart pub get && dart analyze
```
Expected: analyze чист в обоих пакетах; playground печатает свои ~376
строк и завершается кодом 0. `example/` анализируется чисто — ссылок на
удалённый `package:example/data.dart` не осталось.

- [ ] **Step 5: Проверить архив**

Run: `dart pub publish --dry-run 2>&1 | grep -E "tool|example/bin"`
Expected: строк с `tool/` нет; `example/bin/example.dart` тоже нет,
остались только `example/bin/file_storage_example.dart` и
`example/bin/readme_examples/*`.

- [ ] **Step 6: Коммит**

```bash
git add -A
git commit -m "chore: move the kitchen-sink example into tool/"
```

---

### Task 2: Новый `example/example.dart`

**Files:**
- Create: `example/example.dart`

**Interfaces:**
- Consumes: ничего из Task 1 — файл self-contained.
- Produces: `example/example.dart` — единственный файл, который pub.dev
  показывает на вкладке Example.

- [ ] **Step 1: Написать файл**

Создать `example/example.dart`:

```dart
// A single request through the logger: namespaces, a trace id that
// follows the async flow, structured data, a redacted header and an
// error with a stack trace.
//
// Run it with `dart run example.dart` from this directory.
import 'package:team_logger/team_logger.dart';

// The application's logger: one console printer, one row — number, level,
// time, namespace, trace id, message. Tags go to the right edge.
final log = Logger('app')
  ..level = LogLevels.all
  ..publisher = ConsoleLogPrinter(
    theme: LogMainTheme.defaultActiveTheme,
    rows: const [
      LogRow(
        maxLength: 100,
        children: [
          LogNum(),
          LogLevelName.short(),
          LogTime.onlyTime(),
          LogPath(),
          LogTraceId(),
          LogMessage(),
        ],
        tail: [LogTags()],
      ),
    ],
  );

/// The HTTP layer's sublogger: its path is `app/api`, and every log it
/// makes carries the `http` tag. It follows `log` — changing the parent's
/// level or publisher reaches it too.
final api = log.createChild(name: 'api', tags: {'http'});

Future<void> main() async {
  // Redaction is global and per value: the rule is offered every value on
  // its way to the output, under the name it is printed with.
  Loggable.sanitizer =
      (ctx) => ctx.name == 'authorization' ? 'Bearer ***' : ctx.value;

  log.i('Application started', data: {'version': '1.2.3', 'env': 'demo'});

  // Everything logged inside picks up the trace id — at any depth and
  // across any await.
  await log.trace(TraceId.auto('req'), () async {
    api.d(
      'POST /addresses',
      data: LoggableMultiData({'HEADERS': _headers, 'BODY': _body}),
    );

    final address = await _fetchAddress();
    api.i('200 OK', data: address);

    try {
      await _fetchAddress(fail: true);
    } on Object catch (error, stackTrace) {
      api.e('request failed', error: error, stackTrace: stackTrace);
    }
  });

  log.i('Done');
}

const _headers = {
  'content-type': 'application/json',
  'authorization': 'Bearer eyJhbGciOiJub25lIn0.super-secret.signature',
  'accept-language': 'en',
};

const _body = {
  'point': {'lat': 12.345678, 'lon': 23.456789},
  'radius': 500,
};

/// Stands in for an HTTP call.
Future<Address> _fetchAddress({bool fail = false}) async {
  await Future<void>.delayed(const Duration(milliseconds: 50));
  if (fail) {
    throw const FormatException('unexpected end of input');
  }

  return const Address(
    id: 1704,
    name: 'Cake Lab',
    street: 'Baker Street, 91',
    point: Point(12.349473, 23.439319),
    distance: 1240,
  );
}

/// A model that decides how it looks in a log.
///
/// Writing `collectLoggableData` is the whole job: the package renders the
/// properties, and every one of them passes the sanitizer.
final class Address with Loggable {
  final int id;
  final String name;
  final String street;
  final Point point;
  final int distance;

  const Address({
    required this.id,
    required this.name,
    required this.street,
    required this.point,
    required this.distance,
  });

  @override
  void collectLoggableData(LoggableData data) => data
    ..name = '$Address'
    ..prop('id', id)
    ..prop('name', name)
    ..prop('street', street)
    ..prop('point', point)
    ..prop(
      'distance',
      distance,
      units: 'm',
      view: LoggableMultiView([
        LoggableView(distance, units: 'm'),
        LoggableView(distance / 1000, units: 'km'),
      ]),
    );
}

final class Point with Loggable {
  final double lat;
  final double lon;

  const Point(this.lat, this.lon);

  @override
  void collectLoggableData(LoggableData data) => data
    ..name = 'Point'
    ..showName = false
    ..round('lat', lat, precision: 5, showName: false)
    ..round('lon', lon, precision: 5, showName: false);
}
```

- [ ] **Step 2: Запустить и посмотреть глазами**

Run: `cd example && dart run example.dart`
Expected: восемь строк лога; `app/api` в пути у четырёх из них, `#req-1`
в trace-колонке внутри `trace`, `#http` у правого края, `authorization`
показан как `Bearer ***`, а не как токен, `distance` — как `1240m/1.24km`,
последняя пара строк — ошибка со стеком.

Если `authorization` виден целиком — санитайзер не сработал: проверить,
что `ctx.name` для строкового ключа map'а действительно `'authorization'`,
и что правило поставлено **до** первого лога.

- [ ] **Step 3: Проверить анализ**

Run: `cd example && dart analyze`
Expected: чисто. Частая придирка здесь — `omit_local_variable_types` и
`prefer_const_constructors`; чинить по месту, а не отключать линт.

- [ ] **Step 4: Коммит**

```bash
git add example/example.dart
git commit -m "docs: make the example one request through the logger"
```

---

### Task 3: README примера, pubspec и мусор

**Files:**
- Modify: `example/README.md`
- Modify: `example/pubspec.yaml`
- Delete: `example/CHANGELOG.md`, `example/example/` (пустой каталог)

- [ ] **Step 1: Переписать `example/README.md`**

Заменить содержимое целиком:

```markdown
# team_logger examples

`example.dart` is one request through the logger, end to end: a namespace
sublogger with a tag, a trace id that follows the asynchronous flow, a
request logged as headers and body, a response object that decides how it
prints itself, a redacted `authorization` header and a failure with its
stack trace.

```bash
dart pub get
dart run example.dart
```

Also here:

- `bin/file_storage_example.dart` — the same logger writing JSONL session
  files to a temporary directory, then listing and archiving them.
- `bin/readme_examples/` — the code behind the sections of the package's
  main README. These are not standalone programs: the screenshots in the
  README were taken frame by frame, with the surrounding lines commented
  out by hand, so the pictures are the source of truth and this code is
  the material they were shot from.
```

- [ ] **Step 2: Почистить `example/pubspec.yaml`**

`description` — вместо `A sample command-line application`:

```yaml
description: Runnable examples for the team_logger package.
```

Убрать из `dependencies`: `equatable`, `path`, `stack_trace` — ими не
пользуется ни один оставшийся файл (`stack_trace` был нужен только
уехавшей кухне). Убрать из `dev_dependencies`: `test` — каталога `test/` в
примере нет.

Остаётся:

```yaml
dependencies:
  ansi_escape_codes: ^4.0.1
  format: ^4.1.0
  freezed_annotation: ^3.1.0
  team_logger:
    path: ../

dev_dependencies:
  build_runner: ^2.15.0
  freezed: ^3.0.0-0.0.dev
  lints: ^5.0.0
```

- [ ] **Step 3: Убрать мусор**

```bash
git rm example/CHANGELOG.md
rmdir example/example/bin example/example
```

(`example/example/` пуст, поэтому в git его нет — только на диске.)

- [ ] **Step 4: Проверить, что ничего не отвалилось**

Run:
```bash
cd example && dart pub get && dart analyze && dart run example.dart >/dev/null
dart run bin/file_storage_example.dart >/dev/null
for f in bin/readme_examples/*.dart; do dart run "$f" >/dev/null || echo "FAIL $f"; done
```
Expected: `pub get` резолвится без выброшенных пакетов, analyze чист, ни
одного FAIL. Если что-то упало на отсутствующем пакете — значит он всё же
кому-то нужен, вернуть его в `pubspec.yaml` и поправить таблицу
зависимостей в спеке.

- [ ] **Step 5: Проверить архив**

Run: `dart pub publish --dry-run 2>&1 | sed -n '/example/,/^├── lib/p'`
Expected: есть `example/example.dart` и `example/README.md`, нет
`example/CHANGELOG.md`, нет `example/bin/example.dart`, нет `tool/`.

- [ ] **Step 6: Коммит**

```bash
git add -A
git commit -m "docs: give the example package a README of its own"
```

---

### Task 4: Живые документы, CHANGELOG и отчёт

**Files:**
- Modify: `AGENTS.md` (раздел «Команды», строка про основной пример)
- Modify: `docs/conventions.md` (пункт 1 чеклиста «Релиз»)
- Modify: `CHANGELOG.md`
- Modify: `docs/handoff.md`
- Modify: `docs/records/2026-08-20[6]-example-cleanup-design.md` (шапка)
- Modify: `docs/records/2026-08-20[7]-example-cleanup-plan.md` (шапка)
- Create: `docs/records/2026-08-20[8]-example-cleanup-report.md`

- [ ] **Step 1: `AGENTS.md`, раздел «Команды»**

Заменить блок

````markdown
Пример — отдельный пакет, запускать из `example/`:

```bash
cd example && dart pub get
dart run bin/example.dart                 # основной пример
dart run build_runner build               # перегенерировать *.freezed.dart
```
````

на

````markdown
Пример — отдельный пакет, запускать из `example/`:

```bash
cd example && dart pub get
dart run example.dart                     # основной пример
dart run bin/file_storage_example.dart    # файловое хранилище
dart run build_runner build               # перегенерировать *.freezed.dart
```

Ручная проверочная кухня («всё подряд», не публикуется) — из корня:

```bash
dart run tool/playground.dart
```
````

- [ ] **Step 2: `docs/conventions.md`, чеклист «Релиз», пункт 1**

Заменить `` `dart run bin/example.dart` отрабатывает`` на
`` `dart run example.dart` отрабатывает``.

- [ ] **Step 3: Пункт в `CHANGELOG.md`**

В секцию `## 0.7.0`, последним пунктом:

```markdown
- The example package is one example again. `example/example.dart` is a
  single request through the logger — a namespace sublogger with a tag, a
  trace id across an async flow, a request as headers and body, a response
  object that prints itself, a redacted header, a failure with its stack
  trace — and it is what pub.dev shows on the Example tab, where the
  `dart create` boilerplate used to be. The 288-line "print everything"
  program that lived there has moved to `tool/` and is not published; the
  per-section code behind the README screenshots stays where it was.
```

- [ ] **Step 4: Отчёт**

Создать `docs/records/2026-08-20[8]-example-cleanup-report.md` по шаблону
`docs/conventions.md`: что переехало, что удалено, какие зависимости
выброшены и почему, как теперь выглядит вкладка Example, какие проверки
прошли. Отдельно записать, что автоматизация съёмки скриншотов признана
отдельной работой и её набросок лежит в спеке `[6]`.

- [ ] **Step 5: `docs/handoff.md`**

Волна 7 в «Где мы»; в «Статус проверок» строка про `example/` — новые
команды (`example.dart`, `file_storage_example.dart`, восемь
readme-примеров) и `tool/playground.dart`; в «Состояние дерева» — что
закоммичено и что не запушено. Убрать из статуса упоминание «376 строк
`bin/example.dart`» — этого файла больше нет.

- [ ] **Step 6: Шапки записей `[6]` и `[7]`**

Проставить «сделано и смержено в `main`» с номерами коммитов и ссылкой на
отчёт `[8]`.

- [ ] **Step 7: Финальная проверка и коммит**

Run:
```bash
dart analyze && dart test && dart format --output=none --set-exit-if-changed .
cd example && dart analyze
dart pub publish --dry-run
```
Expected: всё зелёное, dry-run — 0 предупреждений на чистом дереве.

```bash
git add -A
git commit -m "docs: record the example cleanup"
```
