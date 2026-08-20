> **Состояние на 2026-08-20:** сделано; коммиты `aee6092`, `f909f7e`,
> `cc0a3d0` в `main`, документы — этим же заходом. Входит в невыпущенную
> 0.7.0.
> **Что это:** отчёт об уборке `example/`.
> **Связанные записи:** `2026-08-20[6]-example-cleanup-design.md` (спека),
> `2026-08-20[7]-example-cleanup-plan.md` (план).

# Уборка example/

Сделано по спеке и плану. Отклонение одно, техническое, — про него ниже.

## Что изменилось

**Кухня уехала.** `example/bin/example.dart` (288 строк «всё подряд») —
теперь `tool/playground.dart`, вместе со своими данными
(`example/lib/data.dart` → `tool/playground_data.dart`). `tool/` добавлен
в `.pubignore` рядом с `docs/`, `scripts/` и `screenshots/`, так что в
pub-архив не попадает. Запускается из корня: `dart run tool/playground.dart`.

**Главным стал `example/example.dart`** — один запрос к API, пять логов,
self-contained. Вывод:

```
(1) [i] [app] Application started: {version: "1.2.3", env: "demo"}
(2) [d] [app/api] {req-1} POST /addresses                              #http
        HEADERS: {content-type: …, authorization: "Bearer ***", …}
        BODY: {point: {lat: 12.345678, lon: 23.456789}, radius: 500}
(3) [i] [app/api] {req-1} 200 OK: Address(id: 1704, …, point:
        (12.34947, 23.43932), distance: 1240m/1.24km)                  #http
(4) [e] [app/api] {req-1} request failed: FormatException: …           #http
        STACKTRACE: …
(5) [i] [app] Done
```

В пяти строках видно всё, ради чего пакет и делался: путь `app/api` и тег
`#http` от подлоггера, `{req-1}` — trace id, переживший два `await`,
секции HEADERS/BODY, объект, сам решающий, как он печатается,
`1240m/1.24km` из `LoggableMultiView`, замаскированный `authorization` и
ошибка со стеком.

Файл self-contained намеренно: pub.dev рендерит ровно один файл, и
читатель вкладки Example не должен упираться в импорты, за которыми не
может пройти.

**Маскирование — санитайзером, а не трансформером.** В первом наброске
был трансформер; это была ошибка выбора инструмента: он работает с логом
целиком и ради одного значения внутри `HEADERS` переписывал бы весь
`Log.data`. В примере это одна строка:

```dart
Loggable.sanitizer =
    (ctx) => ctx.name == 'authorization' ? 'Bearer ***' : ctx.value;
```

**Вкладка Example на pub.dev.** До уборки там лежала болванка `dart
create` — «A sample command-line application with an entrypoint in `bin/`,
library code in `lib/`, and example unit test in `test/`», причём каталога
`test/` не существовало никогда. Проверено на выпущенной версии: pub.dev
показывал ровно этот текст, а `bin/example.dart` не показывал вовсе —
он ищет пример по фиксированным путям, и `bin/` среди них нет. Теперь
`example/README.md` рассказывает, что показывает пример и как его
запустить, а `example/example.dart` лежит на пути, который pub.dev
показывает целиком.

**Выброшено:** `example/CHANGELOG.md` (болванка `## 1.0.0 Initial version`
у пакета с `publish_to: none`), пустой каталог `example/example/`, и
четыре зависимости примера — `equatable` и `path` (ими не пользовался
никто), `test` (при отсутствующем каталоге `test/`) и `stack_trace`
(нужен был только уехавшей кухне).

## Отклонение от плана

`dart fix --apply --code=…` в корне ушёл шире, чем задумано: `--code`
отфильтровал правило, но не каталог, и заодно поправил 14 файлов в
`example/`, включая `readme_examples/`, которые план запрещает трогать.
Хуже того, добавленные им `const` в примере тут же стали
`unnecessary_const` — у примера свой, более мягкий `analysis_options.yaml`.
Откачено `git checkout -- example/`; в `tool/playground.dart` правки
(четыре запятые и три `const`) оставлены — они там и были нужны, потому
что под корневым анализатором правила строже, чем под тем, под которым
файл жил раньше.

Вывод на будущее: `dart fix` в корне репозитория задевает вложенный пакет
`example/`, у которого другие правила. Применять его точечно —
`dart fix --apply tool/` — или проверять `git status` сразу после.

## Что не трогали

`bin/readme_examples/` и `lib/readme_examples/` — ни одной строки.
Скриншоты не переснимались: они постановочные и сейчас актуальны.
Основной `README.md` пакета не менялся.

Автоматизация съёмки скриншотов признана отдельной работой; набросок для
неё — в спеке `[6]`, раздел «Границы».

## Живые документы

`AGENTS.md`, раздел «Команды», и пункт 1 чеклиста «Релиз» в
`docs/conventions.md` оба велели запускать `dart run bin/example.dart` —
после переезда это неправда, обе строки поправлены. В `AGENTS.md` заодно
добавлены `bin/file_storage_example.dart` и `tool/playground.dart`.

`.vscode/launch.json` — конфигурация «example» указывала на
`bin/example.dart` и после переезда просто не запускалась. Указывает на
`example.dart`; добавлена конфигурация для `tool/playground.dart` (без
`cwd`, из корня). Все одиннадцать целей проверены на существование файла.
Ни спека, ни план этот файл не заметили — нашёл владелец.

Записи в `docs/records/` не правились, хотя пути в них устарели: по
`docs/conventions.md` текст записи — история и не переписывается.

## Проверки

- `dart analyze` — чисто в корне (теперь он видит `tool/`) и в `example/`.
- `dart test` — 434 теста зелёные.
- `dart format` — чисто.
- Запускается всё: `example/example.dart`,
  `example/bin/file_storage_example.dart`, восемь
  `example/bin/readme_examples/*.dart`, `tool/playground.dart`.
- `dart pub publish --dry-run` — в архиве есть `example/example.dart` и
  `example/README.md`, нет `example/CHANGELOG.md`, нет
  `example/bin/example.dart`, нет `tool/`.
