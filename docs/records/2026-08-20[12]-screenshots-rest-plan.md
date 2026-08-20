> **Состояние на 2026-08-20:** план согласован, к реализации не
> приступали.
> **Что это:** план перевода оставшихся семи групп скриншотов на кадры.
> **Связанные записи:** `2026-08-20[9]-screenshots-pipeline-design.md`
> (спека), `2026-08-20[11]-screenshots-pipeline-report.md` (пилот).

# Screenshot pipeline (остальные семь групп) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Перевести на кадры оставшиеся семь групп (37 картинок) и
включить то, что до сих пор было выключено: проверку сирот и
`--check` в чеклисте «Релиз».

**Architecture:** Форма задана пилотом — `example/bin/readme_examples/trace.dart`
служит образцом и в плане не повторяется: файл группы объявляет
`final frames = <String, Frame>{…}` и отдаёт её `runFrames(frames, args)`,
каждый блок логов становится функцией, имя кадра — имя картинки без
расширения.

**Tech Stack:** Dart, bash, `scripts/screenshots.sh`.

**Spec:** `docs/records/2026-08-20[9]-screenshots-pipeline-design.md`

## Global Constraints

- `dart analyze` чист в корне и в `example/`; `dart test` и
  `dart format .` в корне не должны пострадать.
- `README.md` не менять: имена картинок те же.
- Каждый кадр сверяется со своей картинкой глазами. Отличаться должно
  **только время** — оно стало синтетическим.
- Подписи, нарисованные поверх логов (закомментированные блоки
  `// For README: …`), — часть кадра: раскомментировать и печатать.
- Съёмка только через `scripts/screenshots.sh`, без `script(1)`.
- Публикацию не запускать и не предлагать. Версия остаётся 0.7.0.

## Инвентарь: какой блок каким кадром становится

Разобрано по файлам и картинкам заранее. Шесть групп режутся по блокам,
седьмая (`quick_start`) собирается заново.

| группа | кадров | как режется |
| --- | --- | --- |
| `themes` | 3 | три блока `print('----- … -----')`, один в один |
| `loggable` | 5 | пять блоков, один в один |
| `layout` | 6 | шесть блоков, один в один |
| `active` | 6 | шесть блоков, один в один |
| `bbcode` | 6 | **пять** заголовков, но шесть блоков: у последнего (`noColorsNoTags`) заголовка нет |
| `data` | 7 | четыре заголовка: блок до первого заголовка → `data_1`; «Deeply nested» → `data_2`; «Multi data» → `data_3`; «Collections» → `data_4`; «Formatting» распадается на три — enum → `data_5`, числа → `data_6`, строки → `data_7` |
| `quick_start` | 4 | заголовков нет; собирается заново, см. Task 7 |

---

### Task 1: `themes` (3 кадра)

**Files:**
- Modify: `example/bin/readme_examples/themes.dart`
- Modify: `screenshots/themes_{1,2,3}.png`, добавляются `.ansi`

- [ ] **Step 1: Разрезать файл на кадры**

По образцу `trace.dart`: карта `frames` из трёх записей
(`themes_1`, `themes_2`, `themes_3`), каждый блок между
`print('----- … -----')` — в свою функцию; сами `print` заголовков
убрать, их печатает `runFrames` в режиме «без аргументов».

- [ ] **Step 2: Проверить контракт**

Run: `cd example && dart run bin/readme_examples/themes.dart --list`
Expected: `themes_1`, `themes_2`, `themes_3`.

- [ ] **Step 3: Сверить каждый кадр с картинкой**

Run: `dart run bin/readme_examples/themes.dart themes_1` (и остальные)
Expected: то же, что на `screenshots/themes_N.png`, кроме времени.

- [ ] **Step 4: Пересобрать и посмотреть**

Run: `scripts/screenshots.sh --only themes`
Открыть три PNG и сравнить со старыми (`git show HEAD:screenshots/themes_1.png`).

- [ ] **Step 5: Анализ и коммит**

Run: `cd example && dart analyze`

```bash
git add example/bin/readme_examples/themes.dart screenshots/
git commit -m "feat(example): cut themes into frames"
```

---

### Task 2: `loggable` (5 кадров)

**Files:**
- Modify: `example/bin/readme_examples/loggable.dart`
- Modify: `screenshots/loggable_{1..5}.png`, добавляются `.ansi`

Шаги те же, что в Task 1, с именами `loggable_1`…`loggable_5` и
`--only loggable`. Особенность: файл собирает кадры из отдельных модулей
(`person1.dart`, `point2.dart`, `speed1.dart`, …), у каждого своя
`run()` — кадром становится вызов соответствующих `run()`, а не код на
месте.

- [ ] **Step 1: Разрезать файл на кадры**
- [ ] **Step 2: `--list` печатает пять имён**
- [ ] **Step 3: Сверить каждый кадр с картинкой**
- [ ] **Step 4: `scripts/screenshots.sh --only loggable`, посмотреть PNG**
- [ ] **Step 5: `dart analyze` и коммит**

```bash
git add example/bin/readme_examples/loggable.dart screenshots/
git commit -m "feat(example): cut loggable into frames"
```

---

### Task 3: `layout` (6 кадров)

**Files:**
- Modify: `example/bin/readme_examples/layout.dart`
- Modify: `screenshots/layout_{1..6}.png`, добавляются `.ansi`

Шаги как в Task 1, имена `layout_1`…`layout_6`, `--only layout`.
Особенность: `layout_4` и `layout_5` показывают стек-трейс, а он
содержит имена файлов и номера строк — после разрезания они сдвинутся.
Это ожидаемо и правильно (кадр изменился), но сверять с картинкой надо
по смыслу, а не буквально.

- [ ] **Step 1: Разрезать файл на кадры**
- [ ] **Step 2: `--list` печатает шесть имён**
- [ ] **Step 3: Сверить каждый кадр с картинкой**
- [ ] **Step 4: `scripts/screenshots.sh --only layout`, посмотреть PNG**
- [ ] **Step 5: `dart analyze` и коммит**

```bash
git add example/bin/readme_examples/layout.dart screenshots/
git commit -m "feat(example): cut layout into frames"
```

---

### Task 4: `active` (6 кадров)

**Files:**
- Modify: `example/bin/readme_examples/active.dart`
- Modify: `screenshots/active_{1..6}.png`, добавляются `.ansi`

Шаги как в Task 1, имена `active_1`…`active_6`, `--only active`.
Особенность: каждый блок зовёт `initLog(...)` со своей конфигурацией
фильтров — это и есть содержание кадра, переносить целиком.

- [ ] **Step 1: Разрезать файл на кадры**
- [ ] **Step 2: `--list` печатает шесть имён**
- [ ] **Step 3: Сверить каждый кадр с картинкой**
- [ ] **Step 4: `scripts/screenshots.sh --only active`, посмотреть PNG**
- [ ] **Step 5: `dart analyze` и коммит**

```bash
git add example/bin/readme_examples/active.dart screenshots/
git commit -m "feat(example): cut active into frames"
```

---

### Task 5: `bbcode` (6 кадров)

**Files:**
- Modify: `example/bin/readme_examples/bbcode.dart`
- Modify: `screenshots/bbcode_{1..6}.png`, добавляются `.ansi`

- [ ] **Step 1: Разрезать файл на шесть кадров**

Заголовков в файле пять, а блоков шесть: последний
(`initLog(theme: LogMainTheme.noColorsNoTags)` и пять логов) идёт без
`print('----- … -----')`. Он и есть `bbcode_6` — в README подписан «No
colors, no tags2».

- [ ] **Step 2: `--list` печатает шесть имён**
- [ ] **Step 3: Сверить каждый кадр с картинкой**
- [ ] **Step 4: `scripts/screenshots.sh --only bbcode`, посмотреть PNG**
- [ ] **Step 5: `dart analyze` и коммит**

```bash
git add example/bin/readme_examples/bbcode.dart screenshots/
git commit -m "feat(example): cut bbcode into frames"
```

---

### Task 6: `data` (7 кадров)

**Files:**
- Modify: `example/bin/readme_examples/data.dart`
- Modify: `screenshots/data_{1..7}.png`, добавляются `.ansi`

- [ ] **Step 1: Разрезать файл на семь кадров**

Заголовков четыре, кадров семь:

- `data_1` — блок до первого заголовка: `log.d('Person: $person')` и
  `log.d('Person', data: person)`;
- `data_2` — «Deeply nested objects»;
- `data_3` — «Multi data»;
- `data_4` — «Collections» (List, Set, Iterable);
- `data_5`, `data_6`, `data_7` — «Formatting» распадается на три: enum,
  числа, строки. В README они подписаны «Formatting settings. Enum»,
  «… Numbers», «… Strings».

- [ ] **Step 2: `--list` печатает семь имён**
- [ ] **Step 3: Сверить каждый кадр с картинкой**

Отдельно проверить `data_6`: он единственный зависит от форматтера чисел
в теме (`default_log.dart`), и на картинке должно остаться
`1.2346`, `123,456,789`, `0x75bcd15`.

- [ ] **Step 4: `scripts/screenshots.sh --only data`, посмотреть PNG**
- [ ] **Step 5: `dart analyze` и коммит**

```bash
git add example/bin/readme_examples/data.dart screenshots/
git commit -m "feat(example): cut data into frames"
```

---

### Task 7: `quick_start` (4 кадра, сборка заново)

**Files:**
- Modify: `example/bin/readme_examples/quick_start.dart`
- Modify: `screenshots/quick_start_{1..4}.png`, добавляются `.ansi`

Единственная группа, которую нельзя разрезать: заголовков в файле нет, а
кадры 2–4 показывают тот же прогон под разными фильтрами принтера,
которых в файле нет вовсе — они настраивались руками при съёмке.

- [ ] **Step 1: Сделать логгер собираемым на кадр**

Сейчас `final log = Logger('app')` лежит на верхнем уровне с одним
принтером. Кадры 2–4 требуют своего принтера, поэтому логгер строит
функция, принимающая настройки фильтра, и каждый кадр строит свой.
Логгеру нужен `tags: {'log'}` — на всех четырёх картинках справа `#log`.

- [ ] **Step 2: Собрать четыре кадра по картинкам**

- `quick_start_1` — без фильтра, все пять логов, плюс подпись-схема
  («sequence number / level / namespace path / trace ID / message with
  data / tags» и линейка «maxLength: 120»). Она лежит в файле
  закомментированной под `// For README: add description of log line` —
  раскомментировать.
- `quick_start_2` — фильтр по номеру: печатается только лог `(4)`.
  Сверху рамка `Filter: (4)` — она в файле под `// For README: add
  filter field`, с подставленным значением.
- `quick_start_3` — фильтр по trace id `{payment-1}`: логи `(2)`–`(5)`,
  первый отсеян. Рамка `Filter: {payment-1}`.
- `quick_start_4` — фильтр по тегу `#http`: логи `(3)` и `(4)`. Рамка
  `Filter: #http`.

Во всех трёх фильтрующих кадрах номера логов сохраняются (2,3,4,5 и так
далее) — значит логи создаются все, а принтер отсеивает при выводе, а не
логгер при записи.

- [ ] **Step 3: `--list` печатает четыре имени**
- [ ] **Step 4: Сверить каждый кадр с картинкой**

Особое внимание — выравниванию рамки `Filter:` и подписи-схемы: они
позиционируются пробелами в строковом литерале. Если разъехалось —
править литерал, а не картинку.

- [ ] **Step 5: `scripts/screenshots.sh --only quick_start`, посмотреть PNG**
- [ ] **Step 6: `dart analyze` и коммит**

```bash
git add example/bin/readme_examples/quick_start.dart screenshots/
git commit -m "feat(example): rebuild quick_start as frames"
```

---

### Task 8: Включить то, что было выключено, и записать

**Files:**
- Modify: `docs/conventions.md` (чеклист «Релиз»)
- Modify: `AGENTS.md` (убрать «переведена пока одна группа»)
- Modify: `docs/handoff.md`
- Modify: шапки записей `[9]`, `[10]`, `[12]`
- Create: `docs/records/2026-08-20[13]-screenshots-rest-report.md`

- [ ] **Step 1: Проверить, что пропускать больше нечего**

Run: `scripts/screenshots.sh`
Expected: ни одной строки `skip:`; проверка сирот **включилась** сама и
не назвала ни одной сироты (единственное исключение —
`flutter_team_logger.png`, оно зашито в скрипт).

- [ ] **Step 2: Проверить свежесть и воспроизводимость**

Run:
```bash
scripts/screenshots.sh --check; echo "exit=$?"
scripts/screenshots.sh && git status --short screenshots/
```
Expected: `exit=0`; повторная пересборка не меняет ни одного файла.

- [ ] **Step 3: `--check` в чеклист «Релиз»**

В `docs/conventions.md`, пункт 1 чеклиста «Релиз», дописать:
`scripts/screenshots.sh --check` проходит (картинки README собраны из
текущего кода).

- [ ] **Step 4: `AGENTS.md`**

Убрать абзац «Переведена пока одна группа — `trace`; остальные семь
снимались вручную и пропускаются с `skip:`» — он больше не верен.
Заменить на строку о том, что переведены все восемь групп, а
`flutter_team_logger.png` в конвейер не входит: это снимок
Flutter-приложения.

- [ ] **Step 5: Отчёт, handoff, шапки**

Создать `docs/records/2026-08-20[13]-screenshots-rest-report.md`:
сколько кадров вышло, где инвентарь разошёлся с ожиданиями, что
пришлось восстанавливать в `quick_start`, чем новые картинки отличаются
от старых. Обновить `docs/handoff.md` (волна 9) и шапки `[9]`, `[10]`,
`[12]`.

- [ ] **Step 6: Финальная проверка и коммит**

Run:
```bash
dart analyze && dart test && dart format --output=none --set-exit-if-changed .
cd example && dart analyze
dart pub publish --dry-run
```
Expected: всё зелёное, dry-run 0 предупреждений.

```bash
git add -A
git commit -m "docs: record the screenshot conversion"
```
