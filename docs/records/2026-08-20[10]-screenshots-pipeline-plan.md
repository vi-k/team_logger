> **Состояние на 2026-08-20:** план пилота выполнен; отчёты —
> `2026-08-20[11]-screenshots-pipeline-report.md` (пилот) и
> `2026-08-20[13]-screenshots-rest-report.md` (остальные).
> **Что это:** план работ по спеке конвейера скриншотов, пилот на группе
> `trace`.
> **Связанные записи:** `2026-08-20[9]-screenshots-pipeline-design.md`.

# Screenshot pipeline (pilot) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Сделать кадр единицей кода и собрать скрипт пересборки
скриншотов; прогнать на группе `trace` (четыре кадра).

**Architecture:** Файл группы объявляет карту `имя кадра → функция` и
отдаёт её общей `runFrames`, которая умеет `--list`, один кадр под
фиксированными часами и «всё подряд» без аргументов. Кадр — отдельный
процесс, потому что счётчики логов и trace id глобальны на изолят.
`scripts/screenshots.sh` обходит группы, спрашивает список и рендерит
`.ansi` рядом с `.png`.

**Tech Stack:** Dart (`package:clock` для фиксированных часов), bash,
существующий `scripts/ansi_screenshot.sh` (swift/AppKit).

**Spec:** `docs/records/2026-08-20[9]-screenshots-pipeline-design.md`

## Global Constraints

- `environment.sdk: ^3.6.0` в обоих пакетах — не поднимать.
- `dart analyze` чист в корне и в `example/`; `dart test` и `dart format .`
  в корне не должны пострадать.
- `README.md` не менять: имена картинок те же.
- Семь непереведённых групп не трогать, кроме одной строки с тегом в
  `init_log.dart`.
- Съёмка — **без `script(1)`**: только перенаправление вывода.
- Проверку свежести в чеклист «Релиз» на этом этапе **не** добавлять.
- Публикацию не запускать и не предлагать. Версия остаётся 0.7.0.

---

### Task 1: `runFrames` и `trace.dart` на кадрах

**Files:**
- Create: `example/lib/readme_examples/frames.dart`
- Modify: `example/pubspec.yaml` (зависимость `clock`)
- Modify: `example/bin/readme_examples/trace.dart` (переписать)
- Modify: `example/lib/readme_examples/default_log.dart` (тег)
- Modify: `example/lib/readme_examples/init_log.dart` (тег)

**Interfaces:**
- Produces: `typedef Frame = FutureOr<void> Function();` и
  `Future<void> runFrames(Map<String, Frame> frames, List<String> args)` из
  `package:example/readme_examples/frames.dart`. Контракт аргументов:
  `--list` → имена по строке; `<имя>` → один кадр под фиксированными
  часами; пусто → все кадры с заголовками; неизвестное имя → сообщение в
  stderr и `exitCode = 2`.

- [ ] **Step 1: Зависимость `clock` в примере**

В `example/pubspec.yaml`, в `dependencies`, по алфавиту после
`ansi_escape_codes`:

```yaml
  clock: ^1.1.1
```

- [ ] **Step 2: Написать `frames.dart`**

Создать `example/lib/readme_examples/frames.dart`:

```dart
import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';

typedef Frame = FutureOr<void> Function();

/// Точка входа файла-группы примеров README.
///
/// - `--list` — печатает имена кадров, по одному на строку;
/// - `<имя кадра>` — исполняет один кадр под фиксированными часами;
/// - без аргументов — исполняет все кадры подряд, с заголовками.
///
/// Имя кадра — имя картинки в `screenshots/` без расширения.
Future<void> runFrames(Map<String, Frame> frames, List<String> args) async {
  if (args.contains('--list')) {
    frames.keys.forEach(print);

    return;
  }

  if (args.isEmpty) {
    for (final MapEntry(key: name, value: frame) in frames.entries) {
      print('----- $name -----');
      await frame();
    }

    return;
  }

  final name = args.first;
  final frame = frames[name];
  if (frame == null) {
    stderr.writeln('Unknown frame: $name. Known: ${frames.keys.join(', ')}');
    exitCode = 2;

    return;
  }

  await withClock(_frameClock(), frame);
}

/// Часы кадра: старт в фиксированной точке, шаг на каждое обращение.
///
/// Время в логах растёт, как в настоящем прогоне, но пересъёмка даёт тот
/// же вывод — поэтому `.ansi` рядом с картинкой не «дрожит», а
/// `scripts/screenshots.sh --check` может сравнивать его как текст.
///
/// Шаг привязан к обращению к часам, а не к логу: если пакет спросит
/// время дважды на один лог, соседние строки разойдутся на два шага.
Clock _frameClock() {
  var tick = 0;
  final base = DateTime(2026, 3, 14, 9, 26, 53, 589);

  return Clock(() => base.add(Duration(milliseconds: 37 * tick++)));
}
```

- [ ] **Step 3: Тег `log` в оба логгера примеров**

В `example/lib/readme_examples/default_log.dart`:

```dart
final log = Logger('app', tags: {'log'})
```

В `example/lib/readme_examples/init_log.dart`:

```dart
  log = Logger('app', tags: {'log'})
```

Это то, что владелец добавлял руками при съёмке: `LogTags()` в хвосте
раскладки печатает `#log` у правого края на всех существующих картинках.

- [ ] **Step 4: Переписать `trace.dart` на кадры**

Заменить `example/bin/readme_examples/trace.dart` целиком:

```dart
import 'dart:async';

import 'package:example/readme_examples/default_log.dart';
import 'package:example/readme_examples/frames.dart';
import 'package:team_logger/team_logger.dart';

final frames = <String, Frame>{
  'trace_1': _searchTrace,
  'trace_2': _traceIdConfigurations,
  'trace_3': _traceIdWithSuffix,
  'trace_4': _laziness,
};

void main(List<String> args) => runFrames(frames, args);

/// `log.trace` вокруг асинхронного куска: оба лога внутри подхватывают
/// один и тот же trace id.
Future<void> _searchTrace() async {
  final searchTrace = TraceId.auto('search'); // resolves to 'search-1'

  await log.trace(searchTrace, () async {
    log.d('Searching database...'); // captures and outputs 'search-1'
    await Future<void>.delayed(const Duration(milliseconds: 100));
    log.i('Database fetch completed'); // captures and outputs 'search-1'
  });
}

/// Три способа задать trace id.
void _traceIdConfigurations() {
  log.d('Global', traceId: TraceId.global());
  log.d('Auto', traceId: TraceId.auto('group'));
  log.d('Manual', traceId: const TraceId.manual('group', 123));
}

/// Повторы запроса под одним id с суффиксом.
Future<void> _traceIdWithSuffix() => _request(Uri.parse('https://example.com'));

Future<void> _request(Uri uri) async {
  final traceId = TraceId.auto('request');

  log.i('$uri', traceId: traceId);
  // ... request ...

  // if request failed, retry:
  for (var i = 0; i < 3; i++) {
    log.w('$uri. Attempt #${i + 2}', traceId: traceId.withSuffix('${i + 2}'));
    // ... retry ...
  }
}

/// Нумерация ленива: выключенный уровень номер не тратит.
void _laziness() {
  log.level = LogLevels.all;
  log.d('Debug message', traceId: TraceId.auto('lazy')); // lazy-1
  log.i('Info message', traceId: TraceId.auto('lazy')); // lazy-2
  log.w('Warning message', traceId: TraceId.auto('lazy')); // lazy-3

  log.level = LogLevels.warning;
  log.d('Debug message', traceId: TraceId.auto('lazy')); // not displayed
  log.i('Info message', traceId: TraceId.auto('lazy')); // not displayed
  log.w('Warning message', traceId: TraceId.auto('lazy')); // lazy-4

  print(
    Styles.rgb311('''
                          ─────┬
                               ╰─ lazy-4, not lazy-6'''),
  );
}
```

Подпись в конце `_laziness` была в файле закомментированной с пометкой
`// For README: add description` — на `screenshots/trace_4.png` она есть,
значит кадр обязан её печатать.

- [ ] **Step 5: Проверить контракт аргументов**

Run:
```bash
cd example && dart pub get
dart run bin/readme_examples/trace.dart --list
```
Expected: четыре строки — `trace_1`, `trace_2`, `trace_3`, `trace_4`.

Run: `dart run bin/readme_examples/trace.dart nope; echo "exit=$?"`
Expected: сообщение `Unknown frame: nope. Known: trace_1, …` в stderr,
`exit=2`.

Run: `dart run bin/readme_examples/trace.dart | head -3`
Expected: заголовок `----- trace_1 -----` и дальше логи — режим «всё
подряд» цел.

- [ ] **Step 6: Сверить каждый кадр с его картинкой**

Run: `dart run bin/readme_examples/trace.dart trace_1`
Expected: две строки, `(1)` и `(2)`, обе с `{search-1}`, справа `#log`,
время одинаковое от прогона к прогону. Сверить с
`screenshots/trace_1.png` — отличаться должно **только** время.

То же для остальных трёх:
- `trace_2` — три строки, `{1}`, `{group-1}`, `{group-123}`;
- `trace_3` — четыре строки, `{request-1}`, `{request-1.2}`,
  `{request-1.3}`, `{request-1.4}`;
- `trace_4` — четыре строки, `{lazy-1}`…`{lazy-4}`, и под ними подпись
  «lazy-4, not lazy-6». Отступ подписи должен подводить скобку под
  колонку trace id, как на `screenshots/trace_4.png`; если разъехалось —
  править отступ в строковом литерале, а не саму картинку.

Run дважды подряд: `dart run bin/readme_examples/trace.dart trace_1 > /tmp/a; dart run bin/readme_examples/trace.dart trace_1 > /tmp/b; diff /tmp/a /tmp/b && echo "воспроизводимо"`
Expected: `воспроизводимо`.

- [ ] **Step 7: Анализ и коммит**

Run: `cd example && dart analyze` и из корня `dart analyze && dart test`
Expected: чисто, 434 теста зелёные.

```bash
git add example/lib/readme_examples/frames.dart example/pubspec.yaml \
        example/bin/readme_examples/trace.dart \
        example/lib/readme_examples/default_log.dart \
        example/lib/readme_examples/init_log.dart
git commit -m "feat(example): make a screenshot frame a unit of code"
```

---

### Task 2: `scripts/screenshots.sh` и пересъёмка `trace`

**Files:**
- Create: `scripts/screenshots.sh`
- Create: `screenshots/trace_1.ansi` … `trace_4.ansi`
- Modify: `screenshots/trace_1.png` … `trace_4.png`
- Delete: `screenshots/quick_start3.png`

**Interfaces:**
- Consumes: контракт `--list` / `<кадр>` из Task 1.
- Produces: `scripts/screenshots.sh` с режимами по умолчанию, `--only
  <группа>` и `--check`.

- [ ] **Step 1: Написать скрипт**

Создать `scripts/screenshots.sh` (и `chmod +x`):

```bash
#!/usr/bin/env bash
set -euo pipefail

# Пересобирает скриншоты README из кадров example/bin/readme_examples/*.dart.
#
# Usage:
#   scripts/screenshots.sh                # все переведённые группы
#   scripts/screenshots.sh --only trace   # одну группу
#   scripts/screenshots.sh --check        # сравнить .ansi, ничего не писать
#
# Кадр — отдельный процесс: счётчики логов и trace id глобальны на изолят,
# и на картинках они всегда стартуют с единицы.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXAMPLE="$ROOT/example"
SHOTS="$ROOT/screenshots"

# Картинки, которые конвейер не делает и сиротами не считает.
NOT_GENERATED=("flutter_team_logger.png")

ONLY=""
CHECK=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --only)
      [[ $# -ge 2 ]] || { echo "Missing value for --only" >&2; exit 1; }
      ONLY="$2"
      shift 2
      ;;
    --check) CHECK=1; shift ;;
    -h|--help) sed -n '3,12p' "$0"; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [[ "$CHECK" == 1 ]]; then
  OUT="$(mktemp -d)"
  trap 'rm -rf "$OUT"' EXIT
else
  OUT="$SHOTS"
fi

claimed=()
skipped=0
failed=0

for file in "$EXAMPLE"/bin/readme_examples/*.dart; do
  group="$(basename "$file" .dart)"
  if [[ -n "$ONLY" && "$group" != "$ONLY" ]]; then
    continue
  fi

  if ! list="$(cd "$EXAMPLE" && dart run "bin/readme_examples/$group.dart" \
      --list 2>/dev/null)" || [[ -z "$list" ]]; then
    echo "skip: $group (кадры не объявлены)" >&2
    skipped=1
    continue
  fi

  while IFS= read -r frame; do
    [[ -z "$frame" ]] && continue
    claimed+=("$frame.png")
    echo "==> $frame"

    # Без script(1): pty не нужен, принтер отдаёт ANSI и в пайп.
    (cd "$EXAMPLE" && dart run "bin/readme_examples/$group.dart" "$frame") \
      > "$OUT/$frame.ansi"

    if [[ "$CHECK" == 1 ]]; then
      if ! diff -q "$SHOTS/$frame.ansi" "$OUT/$frame.ansi" >/dev/null 2>&1; then
        echo "изменился: $frame" >&2
        diff "$SHOTS/$frame.ansi" "$OUT/$frame.ansi" || true
        failed=1
      fi
    else
      "$ROOT/scripts/ansi_screenshot.sh" \
        --input "$OUT/$frame.ansi" --output "$SHOTS/$frame.png" >/dev/null
    fi
  done <<< "$list"
done

# Сироты считаются только когда обойдены все группы и ни одна не пропущена,
# иначе непереведённые группы дали бы 37 ложных срабатываний.
if [[ -z "$ONLY" && "$CHECK" == 0 ]]; then
  if [[ "$skipped" == 1 ]]; then
    echo "проверка сирот пропущена: переведены не все группы" >&2
  else
    for png in "$SHOTS"/*.png; do
      name="$(basename "$png")"
      known=0
      for c in "${claimed[@]}" "${NOT_GENERATED[@]}"; do
        [[ "$name" == "$c" ]] && known=1 && break
      done
      [[ "$known" == 0 ]] && echo "сирота: $name" >&2
    done
  fi
fi

exit "$failed"
```

- [ ] **Step 2: Пересобрать группу**

Run: `chmod +x scripts/screenshots.sh && scripts/screenshots.sh --only trace`
Expected: четыре строки `==> trace_N`; в `screenshots/` появились
`trace_1.ansi`…`trace_4.ansi`, а четыре PNG обновились.

- [ ] **Step 3: Посмотреть на новые картинки**

Открыть `screenshots/trace_1.png`…`trace_4.png` и сравнить со старыми
(они в `git`, поэтому `git stash`/`git diff` не нужен — достаточно
`git show HEAD:screenshots/trace_1.png > /tmp/old_trace_1.png`).
Expected: отличается только время; подпись под `trace_4` на месте и
выровнена.

- [ ] **Step 4: Проверить воспроизводимость и `--check`**

Run:
```bash
scripts/screenshots.sh --only trace
git status --short screenshots/
```
Expected: после второго прогона `.ansi` не изменились (в `git status`
только `.png`, если рендер недетерминирован, или вообще ничего).

Run: `scripts/screenshots.sh --check`
Expected: расхождений нет, код возврата 0; семь непереведённых групп
пропущены с `skip:`.

- [ ] **Step 5: Проверить полный прогон и сирот**

Run: `scripts/screenshots.sh`
Expected: `trace` пересобран, семь групп пропущены с `skip:`, и строка
«проверка сирот пропущена: переведены не все группы» — именно так и
задумано, пока переведена одна группа.

- [ ] **Step 6: Удалить сироту**

`screenshots/quick_start3.png` (без подчёркивания перед цифрой) не
упоминается в `README.md` — проверено `comm` по списку файлов и списку
ссылок.

Run: `grep -c "quick_start3" README.md` — Expected: `0`.

```bash
git rm screenshots/quick_start3.png
```

- [ ] **Step 7: Коммит**

```bash
git add scripts/screenshots.sh screenshots/
git commit -m "feat(scripts): rebuild README screenshots from frames"
```

---

### Task 3: Документы

**Files:**
- Modify: `AGENTS.md` (раздел «Команды»)
- Modify: `docs/handoff.md`
- Modify: `docs/records/2026-08-20[9]-screenshots-pipeline-design.md` (шапка)
- Modify: `docs/records/2026-08-20[10]-screenshots-pipeline-plan.md` (шапка)
- Create: `docs/records/2026-08-20[11]-screenshots-pipeline-report.md`

- [ ] **Step 1: `AGENTS.md`**

Заменить абзац

```markdown
`scripts/ansi_screenshot.sh` рендерит ANSI-вывод в PNG для `screenshots/`
(используются в README).
```

на

````markdown
Скриншоты README собираются из кадров: файл в
`example/bin/readme_examples/` объявляет карту «имя картинки → функция», и
каждый кадр снимается отдельным процессом под фиксированными часами,
поэтому пересъёмка воспроизводима.

```bash
scripts/screenshots.sh                 # пересобрать переведённые группы
scripts/screenshots.sh --only trace    # одну группу
scripts/screenshots.sh --check         # сверить .ansi, ничего не писать
```

Переведена пока одна группа — `trace`; остальные семь снимались вручную и
пропускаются с `skip:`. `scripts/ansi_screenshot.sh` остаётся под
скриптом выше и для ручных снимков.
````

- [ ] **Step 2: Отчёт**

Создать `docs/records/2026-08-20[11]-screenshots-pipeline-report.md` по
шаблону `docs/conventions.md`: что сделано, как выглядит контракт кадра,
что показал пилот, чем новые картинки отличаются от старых, что осталось
на следующий заход (семь групп, проверка свежести в чеклист «Релиз»).

- [ ] **Step 3: `docs/handoff.md`**

Волна 8 в «Где мы»; в «Статус проверок» — строка про
`scripts/screenshots.sh --check`; в «Состояние дерева» — что закоммичено.

- [ ] **Step 4: Шапки записей `[9]` и `[10]`**

«Сделано и смержено в `main`» с номерами коммитов и ссылкой на отчёт
`[11]`.

- [ ] **Step 5: Финальная проверка и коммит**

Run:
```bash
dart analyze && dart test && dart format --output=none --set-exit-if-changed .
cd example && dart analyze
dart pub publish --dry-run
```
Expected: всё зелёное; dry-run — 0 предупреждений на чистом дереве
(`screenshots/` в `.pubignore`, `.ansi` туда не поедут).

```bash
git add -A
git commit -m "docs: record the screenshot pipeline pilot"
```
