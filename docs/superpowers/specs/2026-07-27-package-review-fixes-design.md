# Полное ревью пакета team_logger 0.4.0 — план исправлений

Дата: 2026-07-27
Статус: одобрено 2026-07-28 (решения по вопросам зафиксированы ниже)

## Как проводилось ревью

Четыре независимых адверсариальных ревьюера по зонам: (1) loggable,
(2) ядро логгера + трассировка + LogStorage + преформаттеры, (3) printer +
theme + utils, (4) пакет как продукт (API, доки, публикация, покрытие).
Каждый баг подтверждён repro-скриптом (скрипты — в scratchpad сессии,
конвертируются в тесты при исправлении). Базовая линия: 161 тест зелёный,
`dart analyze` чистый — все находки ниже невидимы для текущего сьюта.

## Реестр находок

### Блокеры публикации

- **PKG-C1 (critical, security)** — в публикуемый архив попадают
  чувствительные данные: `example/lib/data.dart` содержит полный Bearer
  JWT (payload: user_id/session_id), реальный хост `test-api.tezapp.org`,
  device-id, реальные адреса и названия заведений; то же видно на
  `screenshots/flutter_team_logger.png` (вставлен в README) и в
  `data_*.png`. `pub publish --dry-run` подтверждает включение в архив.
  Отмечено в TODO.md, но не сделано.
- **PKG-M3 (major)** — `pub publish --dry-run` даёт warning (папка `docs`
  вместо `doc`); в архив попадают CLAUDE.md, TODO.md, внутренние спеки
  `docs/superpowers/*`, `scripts/`, 3 МБ скриншотов. Нужен `.pubignore`.
- **PKG-M1 (major)** — CHANGELOG 0.4.0 не фиксирует волну breaking
  changes: `sequenceNum`→`num` (Log/LogSequenceNum→LogNum/numStyle/
  indexByNum), `collectionShowLength`→`collectionShowCount`,
  `LoggableResolvedConfig`→`LoggableEffectiveConfig`,
  `resolved()`→`toEffectiveConfig()`, приватизация `TypeProp`, новые
  экспорты.
- **PKG-M4 (major)** — README:580 не компилируется:
  `activeNamespaces: ['net']` — параметр типа `Set<String>?`.

### Критические и высокие баги рантайма

- **FMT-B1 (critical)** — циклические структуры (`l.add(l)`) валят процесс
  StackOverflowError в `objectToString` и `objectToJson`
  (`loggable.dart:160-252`) — SDK такие структуры печатает `[...]`.
- **CORE-1 (high)** — `BbCodeFormatter` молча обрезает сообщение: при
  `style == null` — `return m[0]!` вместо продолжения цикла
  (`bb_code_formatter.dart:29-31`). Достижимо в штатном `noColors`
  (пустой union стилей матчит `[]…[/]`) и через неэкранированные
  спецсимволы в ключах стилей. Фикс: `RegExp.escape` ключей, пустой
  union → текст как есть, `style == null` → write + continue.
- **PRN-B1 (high)** — односимвольное сообщение печатается пробелом:
  `LogBox.fromText` всегда резервирует место под `lineBreak`
  (`log_block.dart:113-120`). Фикс: резервировать только при реальном
  переносе.
- **PRN-B2 (high)** — если tail шире `maxLength`, вся строка лога молча
  выбрасывается (`console_log_printer.dart:111,127-130,162`). Фикс:
  ограничивать tail и учитывать его в `linesCount`.
- **PRN-B3 (high)** — все дефолтные темы добавляют тег `#log` каждому
  логу: `LogMainTheme._` жёстко задаёт `tags = const {'log'}`
  (`log_main_theme.dart:137`) — отладочный остаток.

### Средние баги

- **FMT-B2** — `LoggableMultiView.toJson` склеивает Map'ы в строку
  (`loggable.dart:1305-1306`); структура JSON теряется.
- **FMT-B3** — `LoggableTypeConverter.toJson`/`toLogString` никогда не
  вызываются; README:1249-1272 документирует несуществующие
  `call(...)`/`LoggableResolvedConfig`. Решение: вызывать методы
  конвертера (see: открытый вопрос 3).
- **FMT-B4** — `ControlCodeFormatter` вставляет голый `ESC[0m` даже в
  noColors (`Style.close` безусловен) — ломает файловые логи/парсеры.
  Фикс: `paddingStyle(escapedSymbol)` вместо ручных open/close.
- **FMT-B5** — совместные `collectionMaxCount`+`collectionMaxStringLength`
  превышают бюджет длины (`, …` пишется сверх лимита).
- **CORE-2** — `LogStorage(maxCount: 0)` → RangeError при первом publish.
- **CORE-3** — `publish`/`clear` после `dispose()` бросают StateError
  прямо из `log.i(...)`.
- **CORE-4** — `reversed.reversed` не возвращает исходный порядок.
- **CORE-5** — `tags: <Object>['a']` бросает исключение из `log.i()`
  (паттерн `Iterable<String>()` проверяет тип коллекции, не элементов).
- **CORE-7 = PRN-perf** — regex-кэш BbCode мёртв: `LogMainTheme[level]`
  создаёт новый `LogTheme` на каждый лог → перекомпиляция регулярки на
  каждое сообщение (~5,5×). Фикс: кэшировать 6 `LogTheme` в
  `LogMainTheme` — чинит и Expando.
- **PRN-B4** — утечка ANSI (`\e[0m`) при `noColorsNoTags` и
  `noColors.copyWith(...)`: проверка бесцветности по identity
  (`console_log_printer.dart:98`). Фикс: признак «бесцветная» в теме.
- **PRN-B5** — обрезка режет суррогатную пару → одиночный суррогат в
  выводе (mojibake); ширина считается в code units (CJK/эмодзи ломают
  выравнивание — фикс-минимум: не резать внутри пары).
- **PRN-B6** — подтверждён TODO-баг: ellipsis на каждой строке, включая
  невидимые филлеры. Фикс: `showEllipsis: false` для филлеров.
- **PRN-B7** — подтверждён TODO-баг: stackTrace-фрейм не переносится;
  длинный member выбрасывает имя файла целиком.
- **PRN-B8** — в noColors-темах «скрытые» time/path/num видимо
  повторяются на continuation-строках (hiddenStyle = NoStyle). Фикс:
  филлер деградирует в пробелы той же ширины (see: вопрос 4).
- **PRN-B10** — `minLevel` активной темы отбрасывает именно активные
  логи, фоновые того же уровня печатаются. Фикс: фильтр до выбора темы
  по `min(minLevel обеих тем)` + документация.

### Minor

- **FMT-B6** — `LoggableWrapper`/`LoggableMultiData` в коллекциях
  сбрасывают `depth` (цвета скобок).
- **FMT-B7** — `LoggableView(null).toJson` → строка `'null'` вместо null.
- **FMT-B8** — `unregisterTypeConverter<T>` — тихий no-op при неверном T;
  собственный пример пакета им злоупотребляет.
- **FMT-B9** — конвертеры строго по `runtimeType`: наследники не
  конвертируются (и это не документировано); `LoggableView.convert<T>`
  наследников поддерживает — непоследовательность.
- **FMT-B10** — служебные ключи `:k`/`:v` неотличимы от пользовательских
  данных; в `LoggableMultiData` пользовательский `':k'` затирает маркер.
- **FMT-B11** — не-finite double: строка теряет units, JSON сохраняет.
- **FMT-B12** — дубликаты имён prop: строка показывает оба, JSON молча
  теряет.
- **FMT-B13** — `@name`-ключи mapBuilder не документированы и конфликтуют
  с настоящими prop.
- **FMT-B14** — `fixed()` в JSON теряет числовое значение (только строка).
- **CORE-8** — `snapshot()` пустого storage — fixed-length список,
  непустого — growable.
- **PRN-B9** — `LogTime.dateTime(microseconds: true)` — дрожание ширины
  (нулевые микросекунды опускаются).
- **PRN-B11** — фантомные параметры `LogThemeData.copyWith`
  (colon/ellipsis/lineBreak/padding молча игнорируются).
- **PRN-misc** — LogTags печатает скобки при нуле тегов (маскируется
  PRN-B3); обрезанная ellipsis-строка на 1 колонку уже; `depthThemes: []`
  не запрещён (StateError при первом объекте); мёртвые `utils/cut.dart`
  (пустой extension), `utils/wrap.dart` (не используется);
  `output`-мутация после первого лога действует частично.
- **PKG-minor** — pubspec без `topics`/`screenshots`/`issue_tracker`;
  типы `ansi.Style` торчат в сигнатурах без реэкспорта; имя `Constraints`
  конфликтует с Flutter; `AnsiStringExtensions on String` в общем
  неймспейсе; `Log.num` затеняет core-тип.

### Документация и контракты (зафиксировать словами)

Бросающие message/data/tags-замыкания роняют вызов `log.i()`; `\n` в
message превращается в литерал; `TraceId.auto` игнорирует `initial` для
не-первых resolve, `_autoNums` растёт без reset; порядок событий Add→Remove
при вытеснении в LogStorage; изоляты имеют независимые счётчики; «дыры»
в `Log.num` от отфильтрованных логов; `copyWith` логгера создаёт
live-linked саблоггер, `tags` шарятся по ссылке; вложенный одинаковый
BBCode-тег не поддерживается; `zonedTraceIds` отдаёт мутабельный список;
doc `TraceId` обещает `{…}`-формат, которого нет; `LogFn` всегда
возвращает true.

### Вне скоупа этого плана (отдельные решения)

- **CORE-6** — split-brain наследования publisher при точечном override
  уровня — корень в `logger_builder` (единый `_publisherLinked`): фикс в
  logger_builder 0.3.2 отдельной задачей.
- **Map не обрезается лимитами коллекций** — фича, не баг; отдельное
  обсуждение.
- **ANSI-инъекция из значений по умолчанию** — безопасный режим
  блокируется двойным форматированием в `Prop.toLogString`; требует
  архитектурного решения, вместе с TODO-пунктом про default/force-конфиги.
- Кастомные уровни, `activeNamespaces`-семантика — см. открытые вопросы.

## План исправлений

Все фазы — в неопубликованную 0.4.0, по TDD (repro-скрипты ревьюеров
конвертируются в тесты). Порядок = приоритет; каждую фазу завершает
`dart analyze` + полный прогон + коммит.

**Фаза 0 — блокеры публикации.**
Заменить данные в `example/lib/data.dart` синтетикой (fake-JWT из явно
фейковых частей, хост `example.com`, вымышленные адреса), перегенерировать
затронутые скриншоты `scripts/ansi_screenshot.sh` (если прогон скрипта
невозможен в этой среде — удалить устаревшие PNG из README до
перегенерации); `.pubignore` (docs/, CLAUDE.md, TODO.md, scripts/,
screenshots/ — картинки README pub.dev резолвит через `repository`);
дополнить CHANGELOG 0.4.0 (PKG-M1); исправить README:580 (PKG-M4);
pubspec: `topics`, `issue_tracker`, `screenshots`. Проверка:
`dart pub publish --dry-run` без warning'ов и без чувствительных файлов.
Отзыв JWT-токена, если он когда-либо был боевым, — на вашей стороне.

**Фаза 1 — critical/high рантайм.**
FMT-B1 (защита от циклов: Set посещаемых по identity, при повторе
`[...]`/`{":k":"cycle"}` — в обоих путях); CORE-1 (BbCode: RegExp.escape,
пустой union, continue вместо return); PRN-B1 (резерв lineBreak только при
переносе); PRN-B2 (ограничение tail + linesCount с учётом tail);
PRN-B3 (`tags = const {}` в `LogMainTheme._`).

**Фаза 2 — средние баги.**
FMT-B2, FMT-B3 (сократить интерфейс до `convertToData`), FMT-B4, FMT-B5;
CORE-2 (assert), CORE-3 (guard после dispose), CORE-4, CORE-5
(поэлементная конвертация tags); CORE-7 (кэш LogTheme в LogMainTheme);
PRN-B4 (признак бесцветности), PRN-B5 (не резать суррогатные пары),
PRN-B6 (showEllipsis: false у филлеров), PRN-B7 (перенос
stackTrace-фреймов — закрывает пункт TODO), PRN-B10 (min двух minLevel до
выбора темы); префикс-матчинг `activeNamespaces` (решение 2).

**Фаза 3 — minor и консистентность.**
FMT-B6…B14 (в т.ч. решения: B11 — добавить units в строку; B12 —
последний prop побеждает в обоих видах; B13 — документировать `@`-префикс;
B10 — экранировать пользовательские ключи с `:` и спредить данные до
маркера); CORE-8 (growable всегда); PRN-B9, PRN-B11, LogTags без скобок
при нуле тегов, assert `depthThemes.isNotEmpty`, удалить `utils/cut.dart`
и `utils/wrap.dart`, компенсация ширины ellipsis-строки; pubspec-minor;
`zonedTraceIds` — unmodifiable; поправить doc `TraceId`; пример
`unregisterTypeConverter` в example.

**Фаза 4 — документация и тесты.**
Dartdoc ключевых публичных классов на английском (Logger/LevelLogger/Log,
ConsoleLogPrinter/LogRow/элементы, LogMainTheme/LogTheme/LogThemeData,
LogStorage, преформаттеры) + перевод существующих русских dartdoc
(Loggable/LoggableConfig) — цель: покрыть главные точки входа, не 100%;
задокументировать контракты из раздела выше; базовые тестовые сьюты для
непокрытых подсистем на основе repro-скриптов: printer (layout,
constraints, active/inactive, через `output:`), core (LogStorage
brute-force сценарии, zones/TraceId, BbCode), preformatters. Обновить
TODO.md (закрытые пункты).

## Решения по открытым вопросам (утверждены)

1. **`Constraints` → `LogConstraints`** — переименовать (Фаза 3).
2. **`activeNamespaces`** — префикс-матчинг по иерархии с учётом
   `pathSeparator`: `'app'` активирует `'app'` и `'app/…'`, но не
   `'application'` (Фаза 2).
3. **`LoggableTypeConverter`** — сократить интерфейс до `convertToData`
   (убрать `toJson`/`toLogString`); синхронизировать README и example
   (Фаза 2).
4. **Филлеры при noColors** (PRN-B8) — оставить текущее поведение
   (видимый повтор time/path на continuation-строках), задокументировать
   (Фаза 4).
5. **Реэкспорт стилей** — реэкспортировать из team_logger минимальный
   набор `ansi_escape_codes` (Style и базовые конструкторы стилей),
   чтобы темы настраивались без прямой зависимости (Фаза 3).

## Критерии готовности

- `dart pub publish --dry-run` — чисто, без чувствительных данных.
- Все фазовые баги закрыты тестами (бывшие repro), сьют зелёный,
  analyze чистый, example работает.
- CHANGELOG полон, README-примеры компилируются.
- TODO.md актуализирован (два принтерных пункта закрыты).
