# Executive summary

> Состояние на 2026-08-21: ревью завершено на срезе `a175dd7`. Находки №1,
> №2, №3, №5, №6, №7, №8, №9 и №12 исправлены; №4 принят как исходный
> контракт и документирован. Остаются 6 исходных находок (1 Medium, 5 Low).

Проект в целом аккуратно устроен и необычно хорошо покрыт тестами для
библиотеки такого размера: платформенно-независимое ядро отделено от
`dart:io`, публичные примеры собираются для VM и web, а 434 теста проходят.
Sanitizer, циклы, layout и асинхронное хранилище имеют содержательные
контрактные тесты, а не только happy path.

Тем не менее текущую `0.7.0` нельзя считать готовой к production-релизу без
явного принятия рисков ниже. Найдено **16 проблем: 1 High, 9 Medium и 6 Low**.
Главный блокер — сверхлинейный BBCode-парсер в стандартной теме: незакрытые
теги длиной всего 2,4 КБ синхронно занимают isolate примерно на 4,16 секунды.
Второй кластер был в файловом хранилище: запись и чтение следовали по symlink,
`flush()` подтверждал уже потерянные логи, а ZIP-экспорт держал весь исходный
и сжатый архив в памяти. Превышение size targets одной атомарной записью после
сверки признано исходным контрактом, а не отдельным дефектом реализации; три
остальные проблемы этого кластера исправлены.

Ниже отделены подтверждённые дефекты от архитектурных ограничений и
предположений. Старый черновик не принимался за источник истины: дерево,
контракты и сценарии были перечитаны и воспроизведены заново.

# Project overview

Проверены:

- публичные библиотеки `lib/team_logger.dart` и `lib/team_logger_io.dart`;
- весь код `lib/src/`: logger, transformer, trace ids, `Loggable`, sanitizer,
  printer/themes, память и файловое хранилище;
- 21 тестовый файл, оба example entrypoint'а и восемь групп README-кадров;
- `pubspec.yaml`, lock-файлы, analysis options, package layout, README,
  CHANGELOG, внутренние документы и release dry-run;
- зависимости, импортные границы core/IO, ошибки, lifecycle, конкуренция,
  квоты, сериализация, безопасность терминала и файловой системы.

Три независимых read-only прохода отдельно разбирали архитектуру/API,
`Loggable`/рендеринг и file storage. Корневой проход затем перепроверил
кандидатов кодом, существующими тестами и временными probe-сценариями в
`/private/tmp`.

Не анализировались как исходный код `.dart_tool/`, `build/`, `.git/` и
бинарное содержимое PNG. Сгенерированные кадры проверены штатным
воспроизводимым pipeline. Внешний пакет `logger_builder` оценивался через его
публичный контракт и фактическую интеграцию, но не как отдельный репозиторий.

## Architecture and data flow

Поток данных короткий и понятный:

`Logger` → lazy resolution → `Log` → transformer → publisher → console,
кольцевой `LogStorage` или асинхронный `FileLogStorage`.

Сильные решения:

- `team_logger.dart` не импортирует `dart:io`; файловый API вынесен в
  `team_logger_io.dart`, и core успешно компилируется в JavaScript;
- дочерние logger'ы наследуют уровень/publisher/transformer, а trace context
  передаётся через `Zone`;
- `Loggable` централизует строковый и JSON-рендер, защиту от циклов,
  ограничения коллекций и redaction;
- `FileLogStorage` отделяет codec, session reader и writer, имеет bounded
  queue, exclusive reservation первого чанка и recovery после write error;
- API в основном документирован примерами, а release archive проверяется
  dry-run'ом.

Основной maintainability-риск — концентрация логики в
`lib/src/loggable/loggable.dart` (более 2 тысяч строк) и тесная связь его
приватного traversal-state с несколькими альтернативными render entrypoint'ами.
Сейчас это удерживается тестами, но новые режимы вывода легко рассинхронизировать.

## Сводка находок

| № | Приоритет | Область | Кратко |
| --- | --- | --- | --- |
| 1 | High / P1 | Performance, security | Незакрытые BBCode-теги дают примерно кубическое время |
| 2 | Medium / P2 | File security | Symlink позволяет читать и дописывать файлы вне каталога логов |
| 3 | Medium / P2 | Durability | `flush()` успешно подтверждает потерю принятых логов |
| 4 | Medium / P2 | Resource limits | Одна строка обходит `maxChunkSize` и `maxSessionSize` |
| 5 | Medium / P2 | Memory | ZIP-экспорт буферизует все сессии и весь архив |
| 6 | Medium / P2 | Data integrity | Строковое преобразование ключей `Map` теряет JSON-записи |
| 7 | Medium / P2 | API contract | Документированный immutable `Log` изменяем после публикации |
| 8 | Medium / P2 | File API | Session id создаёт невидимые файлы, большой индекс роняет parser |
| 9 | Medium / P2 | Runtime safety | Публичные предусловия существуют только в `assert` |
| 10 | Medium / P2 | Terminal security | Стандартный вывод допускает ANSI-инъекцию из данных |
| 11 | Low / P3 | Sanitizer | Корневая замена теряет config `builder`/`mapBuilder` |
| 12 | Low / P3 | Lifecycle | `close()` может завершиться раньше фоновой инициализации |
| 13 | Low / P3 | Mutable config | Публичные настройки расходятся с identity-кэшами |
| 14 | Low / P3 | Zone context | `zonedTags()` позволяет менять контекст соседнего кода |
| 15 | Low / P3 | Unicode/layout | `maxLength` считает code units, а не экранные колонки |
| 16 | Low / P3 | Documentation | README, CHANGELOG, architecture и dartdoc расходятся с кодом |

# Critical and high-severity findings

### 1. [High / P1] BBCode-парсер блокирует isolate на коротком adversarial input

**Где:** `lib/src/preformatters/bb_code_formatter.dart:28-34`,
`lib/src/theme/log_main_theme.dart:122-137`.

**Проблема.** Стандартная активная тема использует `BbCodeFormatter`.
Регулярное выражение содержит две ленивые произвольные группы — prefix и
content — и запускается через `allMatches()`. На множестве распознанных, но
незакрытых тегов движок перебирает огромное число разбиений.

**Воспроизведение.** После warm-up строка из повторов `[b]` дала:

| Символов | Время |
| ---: | ---: |
| 300 | 9,6 мс |
| 600 | 70 мс |
| 1 200 | 541 мс |
| 2 400 | 4 163 мс |

Удвоение входа увеличивает время примерно в восемь раз. Выход во всех
случаях остаётся исходной строкой; задержка — чистая цена неуспешного поиска.

**Последствия.** Сообщение из пользовательского ввода с несколькими сотнями
`[b]` блокирует единственный Dart isolate на секунды. Для серверного или UI
процесса это алгоритмический DoS; случайно оборванная markup-строка даёт тот
же эффект.

**Исправление.** Заменить regex линейным scanner/stack parser'ом либо хотя бы
ограничить объём и число тегов до разбора. Добавить regression benchmark на
закрытые, незакрытые и вложенные теги с проверкой линейного роста.

**Уверенность:** high.

**Вердикт (2026-08-21): исправлено в `431b277`.** Backtracking-regex заменён
scanner'ом, который монотонно ищет следующую `[` и сопоставляет полные
известные токены темы; вложенность хранится в явном LIFO-дереве и рендерится
без рекурсивного parser call stack. Совпадающие вложенные теги, произвольные
имена стилей и повреждённая разметка закреплены тестами. RED-сценарий на
2 400 символах занял 4,08 с; после исправления — около 0,65 мс. Stress-test
проходит 5 000 уровней, полный набор — 441 тест. Повторное независимое ревью
не нашло Critical, Important или Minor замечаний.

# Medium and low-severity findings

### 2. [Medium / P2] Chunk-symlink выводит file storage за пределы каталога

**Где:** `lib/src/file_storage/file_log_sessions.dart:58-74`,
`:180-217`; `lib/src/file_storage/file_log_storage.dart:211-238`,
`:289-301`.

**Проблема.** `Directory.list()` вызывается с `followLinks: true` по
умолчанию, поэтому symlink с именем chunk'а попадает в session как `File`.
Чтение, metadata, export и archive затем открывают target. Writer эксклюзивно
резервирует только первый чанк; последующие `writeAsBytes(...,
FileMode.writeOnlyAppend)` также следуют по заранее подложенной ссылке.

**Воспроизведение.** После ротации probe создал `s.2.jsonl` как ссылку на
соседний `victim.txt`. Следующий `flush()` завершился успешно и увеличил
внешний файл с 6 до 186 байт (`victimModified=true`). Аналогично session
reader может включить содержимое внешнего файла в export/ZIP.

**Последствия.** Процесс или пользователь с доступом к каталогу логов может
добиться дописывания произвольного доступного процессу файла или утечки его
содержимого в диагностический архив. Даже без противника случайная ссылка
нарушает изоляцию каталога.

**Исправление.** Зафиксировать threat model и требовать приватный каталог.
Для перечисления использовать `followLinks: false` и принимать только
обычные файлы по `lstat`. Каждый новый чанк резервировать эксклюзивно;
проверка типа до open сама по себе не закрывает race, поэтому нужен
no-follow/open-handle подход, доступный целевой платформе, либо безопасный
уникальный subdirectory с контролируемыми правами.

**Уверенность:** high для поведения, medium-high для exploitability — она
зависит от прав на каталог.

**Вердикт (2026-08-21): исправлено в `ac40ae9` и `08aa5c0`.** Реальные
filesystem-regression tests закрепляют, что reader/list/export/ZIP/delete и
startup cleanup пропускают symlink/non-regular entries, а writer эксклюзивно
резервирует каждый chunk и пишет через открытый handle. Это осознанно
best-effort защита для приватного каталога: полной защиты от hostile
TOCTOU-гонки или hardlink пакет не заявляет.

**Дополнение после broad review (2026-08-21):** `4005f65` добавляет
обязательную кроссплатформенную регрессию ordinary-file collision: занятый
индекс не меняется, тот же батч доходит до следующего свободного chunk, а
`onError` вызывается ровно один раз. Удаление текущей сессии при активном
writer явно объявлено неподдерживаемым; закреплена последовательность
list → `await storage.close()` → `session.delete()` без runtime registry.

### 3. [Medium / P2] `flush()` подтверждает уже потерянные принятые логи

**Где:** `lib/src/file_storage/file_log_storage.dart:27-44`, `:146-192`,
`:195-244`; `test/file_storage/file_log_storage_test.dart:241-260`,
`:516-543`; `README.md:1432-1440`.

**Проблема.** Dartdoc и README обещают, что всё принятое до `flush()` будет
на диске. Но ошибка инициализации ставит `_disabled`, после чего `handle()`
молча возвращается; write error сообщается в `onError`, batch не retry'ится
и не переводит flush в ошибку. Базовая очередь при этом считается
обработанной, поэтому `flush()` и `close()` завершаются успешно.

`onDropped` покрывает только отказ входящему логу при переполнении очереди.
Уже принятые логи после init/write failure через него не проходят.

**Сценарий.** Каталог нельзя создать либо текущий chunk становится
недоступен для записи. Приложение публикует лог и ожидает `flush()`; callback
получает ошибку, но сам `flush()` завершается нормально, а записи на диске
нет. Оба пути закреплены существующими тестами как текущее поведение.

**Последствия.** Вызывающий получает ложное подтверждение durability и может
удалить единственную альтернативную копию диагностики. Ошибка видна лишь в
необязательном side channel `onError`; после init failure последующие логи
исчезают без новых сигналов.

**Исправление.** Выбрать один контракт: либо запоминать failure generation и
завершать соответствующий `flush()` ошибкой/результатом с потерями, либо
явно ослабить обещание до «очередь обработана». Потери принятых записей
отдельно отдавать в `onDropped`/метрики. Закрепить тестом публичный результат,
а не только факт вызова `onError`.

**Уверенность:** high.

**Вердикт (2026-08-21): исправлено в `fb18264`.** Первая ошибка
инициализации или записи, оставившая принятые логи несохранёнными либо с
неопределённой сохранностью, закрепляется за экземпляром: `flush()` сначала
дожидается drain новых логов, а `close()` — drain и закрытия handle, после
чего оба завершаются исходной ошибкой. В `onDropped` без retry попадает
только незафиксированный хвост частично записанного батча; уже сохранённый
префикс и ошибки retention-cleanup durability не отравляют. `minLevel`
применяется до bounded queue. Четыре regression-теста прошли полный RED–GREEN,
повторное независимое ревью не нашло Critical/Important замечаний.

### 4. [Medium / P2] Одна запись обходит обе файловые квоты

**Где:** `lib/src/file_storage/file_log_storage.dart:19-25`, `:55-60`,
`:306-325`, `:343-354`; `test/file_storage/file_log_storage_test.dart:310-335`;
`README.md:1420-1430`.

**Проблема.** Строка кодируется и добавляется целиком, только затем чанк
коммитится и ротируется. `_deleteOldestChunks()` принципиально не удаляет
последний чанк. Поэтому одна запись не ограничена ни `maxChunkSize`, ни
`maxSessionSize`, хотя публичная документация описывает оба как size limits.

**Воспроизведение.** Существующий тест задаёт 600/1200 байт и пишет сообщение
из 2 000 символов; первый chunk ожидаемо получается больше 1 200 байт.

**Последствия.** Большой stack trace, object rendering или пользовательская
строка создаёт файл произвольного размера и может заполнить диск. Следующая
запись удалит oversized chunk, но пиковый размер уже не ограничен.

**Исправление.** Ввести документированную политику oversized record:
усечение с маркером, отказ с `onDropped` либо отдельный жёсткий предел.
Проверять размер до append.

**Уверенность:** high.

**Вердикт (2026-08-21): принят исходный контракт, публичная документация
уточнена.** Утверждённая до реализации спецификация
`2026-07-27[2]-file-log-storage-design.md` прямо требует не разрезать строку и
разрешает ей разово превысить `maxChunkSize`; реализация этого контракта вошла
в `12edda6`, а существующий тест намеренно его закрепляет. Владелец подтвердил
прежнее решение. `maxChunkSize` и `maxSessionSize` теперь публично описаны как
пороги ротации/retention, `maxTotalSize` — как startup retention budget; ни
один из них не обещает жёсткий потолок при oversized record. Для жёсткой
границы вызывающий код должен ограничить размер session metadata, сообщений,
ошибок, стеков и рендеримых данных.

### 5. [Medium / P2] `archiveTo()` масштабирует память по всему набору логов

**Где:** `lib/src/file_storage/file_log_sessions.dart:136-155`,
`lib/src/file_storage/file_log_storage.dart:24-25`, `:62-66`.

**Проблема.** Каждая session полностью собирается в `BytesBuilder`, затем её
байты остаются в `ArchiveFile.bytes`. После накопления всех sessions
`ZipEncoder().encode(archive)` по умолчанию создаёт ещё и полный
`OutputMemoryStream`, а `writeAsBytes` получает готовый архив. В разрешённой
версии `archive 4.1.0` это подтверждается реализациями `ArchiveFile.bytes` и
`ZipEncoder.encodeBytes`. При этом число sessions не ограничено, а
`maxTotalSize` по умолчанию равен `null`.

**Сценарий.** Долгоживущее приложение накапливает много sessions и по
запросу поддержки вызывает `archiveTo()` без предварительного ограничения
набора. В памяти одновременно остаются bytes каждой session и выходной ZIP.

**Последствия.** Экспорт диагностики может потребовать память порядка суммы
всех исходных файлов плюс ZIP и временные буферы. Именно в аварийной ситуации
с большим объёмом логов это способно завершиться OOM вместо создания архива.

**Исправление.** Писать ZIP потоково в file sink и подавать содержимое
sessions по stream, не удерживая предыдущие sessions. Если dependency API не
позволяет — ввести явный archive size cap и документировать memory bound.

**Уверенность:** high по текущей реализации, medium по фактическому порогу
OOM — он зависит от среды и сжимаемости.

**Вердикт (2026-08-21): исправлено breaking-заменой на потоковый GZIP.**
Владелец согласовал удалить `archiveTo()` и добавить `gzipTo()`: выбранные
сессии последовательно пишутся в один GZIP-сжатый JSONL, каждая сохраняет свою
meta-строку, поэтому границы остаются видны после распаковки. В памяти больше
нет `BytesBuilder`, `ArchiveFile.bytes` и полного output archive; остаются
только I/O- и compression-буферы. Четыре контрактных теста прошли RED–GREEN,
включая порядок/meta, subset+overwrite, symlink и разделитель после файла без
финального `\n`. Отдельный stress-прогон экспортировал 128 МБ под heap 32 МБ:
пиковый прирост RSS — около 5,4 МБ. Неиспользуемая зависимость `archive`
удалена. Независимое ревью нашло ещё три edge case: первая строка позднего
чанка могла целиком накопиться до `LF`, target-алиас выбранного чанка обнулял
источник, а ошибка `close()` маскировала первичную ошибку чтения. Все три
исправлены отдельными RED–GREEN циклами: meta распознаётся с ограниченным
prefix-state, path/symlink/hardlink алиасы отвергаются до `openWrite`, а
первичная ошибка сохраняется вместе с исходным stack trace. Повторный
stress-прогон на позднем meta-подобном чанке 128 МБ без `LF` под heap 32 МБ
завершился с пиковым приростом RSS около 8,3 МБ. Повторное ревью обнаружило
вариант, где snapshot chunk path уже заменён symlink'ом и одновременно передан
как target: прежняя type-based проверка пропускала его и меняла symlink victim.
Нормализованный snapshot path теперь отвергается независимо от текущего типа;
отдельный RED–GREEN тест проверяет сохранность victim.

### 6. [Medium / P2] Нормализация ключей `Map` молча теряет JSON-данные

**Где:** `lib/src/loggable/loggable.dart:1830-1863`.

**Проблема.** Нестроковый ключ превращается через `toString()`, `null` — в
строку `null`, после чего значение записывается в `Map<String, Object?>` без
проверки коллизии. Последняя запись побеждает.

**Воспроизведение.** Probe получил:

- `{null: 1, 'null': 2}` → `{"null":2}`;
- `{1: 'int', '1': 'string'}` → `{"1":"string"}`.

**Последствия.** `objectToJson()` и JSON-режим `FileLogStorage` теряют часть
структурированных данных без ошибки или маркера.

**Исправление.** Обнаруживать коллизию после нормализации и либо отклонять
неоднозначный map, либо использовать lossless список пар с типизированным
ключом. Тихое last-write-wins здесь небезопасно.

**Уверенность:** high.

**Вердикт (2026-08-21): исправлено в `fd3045f` fail-fast проверкой.** После
преобразования ключа через `toString()` и escaping `_mapToJson` проверяет уже
реально выводимый JSON-ключ через `containsKey`; коллизия даёт `ArgumentError`
вместо last-write-wins. Запись, удалённая sanitizer'ом, до проверки не доходит.
Прямые тесты закрепляют `1`/`'1'`, `null`/`'null'`, первое значение `null` и
sanitizer drop. В JSON-режиме `FileLogStorage` существующий encode fallback
пишет `encodeError: ArgumentError`, сообщает исходную ошибку в `onError` и
сохраняет соседние логи.

### 7. [Medium / P2] `Log` назван immutable, но его коллекции изменяемы

**Где:** `lib/src/logger/log.dart:14-44`, `:51-99`.

**Проблема.** Публичный контракт называет `Log` immutable record, однако
`traceIds` и `tags` публикуются как изменяемые `List`/`Set`. Конструктор и
`copyWith()` сохраняют переданные коллекции по ссылке.

**Воспроизведение.** После публикации в `LogStorage` вызов
`storage.first.tags.add('mutated')` изменил snapshot с `{original}` на
`{original, mutated}`.

**Последствия.** Transformer, один publisher или исходный владелец коллекции
может изменить объект, который позже увидит другой publisher. Фильтрация и
асинхронная запись становятся зависимыми от порядка и времени.

**Исправление.** Копировать коллекции в обоих конструкторах и хранить/выдавать
unmodifiable значения. Если изменяемость намеренна — убрать обещание
immutability и явно описать ownership, но это заметно слабее текущего дизайна.

**Уверенность:** high.

**Вердикт (2026-08-21): исправлено в `b20f797` immutable snapshots без
поэлементного копирования в горячем пути.** Публичный `Log` и новые коллекции
в `copyWith` делают defensive copy; обычный `Logger` передаёт свежие list/set
во владение приватного `_owned`, который выдаёт unmodifiable views. Пустые
коллекции в `Log` канонические, а `copyWith` без replacement сохраняет identity
snapshots.
Три исходных regression-теста и review-тест порядка lazy message/tags прошли
RED–GREEN. Сфокусированный probe не показал значимой регрессии, независимое
ревью не нашло Critical/Important.

### 8. [Medium / P2] API имён сессий не замкнут на собственном формате

**Где:** `lib/src/file_storage/file_log_sessions.dart:9-39`, `:58-74`;
`lib/src/file_storage/file_log_storage.dart:120-123`, `:195-244`.

**Проблема.** `sanitizeSessionId('')` возвращает пустую строку, а
`chunkName('', 1)` создаёт `.1.jsonl`; parser требует непустую группу и этот
же файл игнорирует. Обратная сторона: имя с очень длинным цифровым индексом
проходит regex, но `int.parse()` бросает `FormatException`.

**Воспроизведение.** Probe подтвердил `.1.jsonl -> null`; индекс из 100 цифр
дал `Positive input exceeds the limit of integer`.

**Последствия.** Библиотека создаёт session, невидимую через `sessions.list()`.
Повреждённый или подложенный filename с большим индексом срывает list, а при
startup cleanup отключает весь `FileLogStorage` через общий catch `_init()`.

**Исправление.** Запрещать пустой результат sanitization либо подставлять
безопасный default. Использовать `int.tryParse()` и считать непредставимый
индекс чужим/повреждённым файлом.

**Уверенность:** high.

**Вердикт (2026-08-21): исправлено в `4b8c9b4`.** Пустой результат
`sanitizeSessionId` теперь синхронно даёт `ArgumentError`, а
`parseChunkName` возвращает `null` для индекса вне диапазона Dart `int`.
Повреждённое имя не удаляется и больше не отключает listing/startup.
Три regression-теста прошли два RED–GREEN цикла; независимое ревью не нашло
Critical/Important.

### 9. [Medium / P2] Public API валидирует опасные параметры только через `assert`

**Где:** `lib/src/storage/log_storage.dart:71-77`,
`lib/src/file_storage/file_log_storage.dart:87-112`,
`lib/src/printer/console_log_printer.dart:46-68`,
`lib/src/theme/log_main_theme.dart:114-160`,
`lib/src/loggable/loggable.dart:1057-1063`, `:1497-1503`.

**Проблема.** Эти проверки исчезают в обычном production-запуске Dart.
После этого публичные конструкторы принимают конфигурации, которые код ниже
считает невозможными.

**Воспроизведение.** В стандартном `dart` probe подтвердил
`assertionsEnabled=false`. `LogStorage(maxCount: 0)` успешно создался, а
первая публикация бросила `RangeError` в точку логирования.
`ConsoleLogPrinter(activeTags: {...})` без `inactiveTheme` также создаётся,
но фильтр фактически не имеет смысла.

**Последствия.** Ошибка конфигурации проявляется далеко от конструктора:
падением production logger'а, молча неработающим фильтром или нарушенными
file-size invariants. Тесты с включёнными assertions этого не видят.

**Исправление.** Публичный пользовательский ввод проверять обычным кодом с
`ArgumentError.value`; `assert` оставить только для внутренних невозможных
состояний. Добавить тесты, не зависящие от режима assertions.

**Уверенность:** high.

**Вердикт (2026-08-21): исправлено в `1b9f1f0`.** Все перечисленные
публичные границы, а также обнаруженный в том же конструкторе
`FileLogStorage.maxQueueSize`, теперь синхронно дают `ArgumentError.value` в
production без assertions. Subprocess-тест запускает настоящий `dart` с
assertions disabled; прямые тесты проверяют имя, значение, отрицательные
границы и прежний порядок ошибок. Независимое ревью после исправления порядка
не оставило замечаний. AOT-probe оценил добавленную renderer-валидацию сверху
в 0,13% типичного рендера; publish/write path не изменён.

### 10. [Medium / P2] Стандартный terminal output допускает ANSI-инъекцию

**Где:** `lib/src/preformatters/control_code_formatter.dart:7-15`, `:24-40`,
`lib/src/theme/log_main_theme.dart:122-137`.

**Проблема.** `ControlCodeFormatter` по умолчанию исключает ESC из escaping,
чтобы сохранить ANSI-коды. Сам Dartdoc прямо отмечает, что это позволяет
user data инъецировать ANSI sequences. Сообщение проходит через
`BbCodeFormatter`, который ESC также не экранирует. Безопасного режима для
всего лога сейчас нет; задача уже отмечена в `docs/backlog.md`.

**Сценарий.** HTTP header, exception text или другое недоверенное поле
содержит ESC/OSC sequence и выводится стандартным console printer в terminal.

**Последствия.** Недоверенный текст может менять цвет, скрывать или
перезаписывать строки терминала, подделывать визуальную структуру лога и в
зависимости от terminal emulator задействовать более опасные control
sequences. Это особенно существенно для logger'а, который в примерах пишет
HTTP-данные.

**Исправление.** Зафиксировать trust boundary. Предпочтительно сделать
безопасный escaping mode целиком для message/data/error/path/tags и
рекомендовать его для недоверенных данных; сохранение raw ANSI должно быть
явной опцией. Добавить e2e-тесты на ESC, OSC и C0.

**Уверенность:** high по поведению; severity зависит от источников логов и
terminal emulator.

### 11. [Low / P3] Корневая sanitizer-замена теряет config builder'а

**Где:** `README.md:1583-1587`, `lib/src/loggable/loggable.dart:300-335`,
`:562-600`; `lib/src/loggable/loggable_data.dart:620-669`.

**Проблема.** Публичный контракт обещает рендерить корневую замену с
formatting config контейнера. `_rootConfig()` и `_rootJsonConfig()` умеют
достать config только из `LoggableMultiData`. У `_LoggableBuilder` и
`_LoggableMapBuilder` config также есть, но общий код его не видит.

**Воспроизведение.** Builder с `collectionMaxCount: 1` и sanitizer-заменой
корня на `[1, 2, 3]` вывел все три элемента:
`[₌₃ ₀:1, ₁:2, ₂:3]`, а не сокращённый список.

**Последствия.** Строковый и JSON-вывод нарушают обещанные лимиты/форматы
именно на redaction path; потенциально растёт объём лога.

**Исправление.** Дать всем контейнерам единый внутренний интерфейс effective
config либо развернуть builder до корневой sanitize-ветки. Добавить
симметричные string/JSON/e2e-тесты для builder, mapBuilder и multi-data.

**Уверенность:** high.

### 12. [Low / P3] `close()` не всегда закрывает фоновой lifecycle

**Где:** `lib/src/file_storage/file_log_storage.dart:68-72`, `:120-123`,
`:145-159`.

**Проблема.** При пустой очереди `close()` делегирует базовому publisher и не
ждёт `ready`. Инициализация, запущенная в конструкторе, продолжает создавать
каталог и первый chunk уже после завершившегося `await close()`.

**Воспроизведение.** В 25 из 25 немедленных create→close циклов `close`
завершился раньше `ready` (`closeBeatReady=25/25`).

**Последствия.** Shutdown/test cleanup может удалить каталог, а фоновая
инициализация создаст его заново; вызывающий ошибочно считает, что после
close побочных filesystem-операций больше нет.

**Исправление.** Делать `close()` async и всегда ждать `ready` перед
завершением, даже если публикаций не было. Отдельно решить, должен ли close
создавать первый chunk или отменять ещё не завершившийся init.

**Уверенность:** high.

**Вердикт (2026-08-21): исправлено в `08aa5c0`.** Реальные
filesystem-regression tests закрепляют, что `close()` ждёт `ready`, drain
принятых логов и закрытие текущего handle; два вызова возвращают один cached
Future. Этот вердикт касается завершения lifecycle; синхронное значение
унаследованного `isClosed` до `super.close()` остаётся отдельным deferred
Minor для широкого итогового ревью.

**Дополнение после broad review (2026-08-21): исправлено в `4005f65`.**
`isClosed` переключается синхронно при вызове `close()`, а `flush()` после
начала закрытия возвращает ровно тот же cached Future и потому не может
завершиться до закрытия активного handle.

### 13. [Low / P3] Mutable-конфигурации расходятся с identity-кэшами

**Где:** `lib/src/preformatters/bb_code_formatter.dart:11-33`,
`lib/src/theme/log_main_theme.dart:59-60`,
`lib/src/theme/log_theme_data.dart:8-15`,
`lib/src/printer/console_log_printer.dart:41-44`, `:125-131`.

**Проблема.** Regex BBCode кэшируется по identity `LogTheme`, но maps
`messageStyles` остаются изменяемыми: tag, добавленный после первого вызова,
не попадает в regex. `ConsoleLogPrinter.output` тоже изменяем, однако уже
созданный `StackedPrinter` навсегда хранит старый callback; новый уровень
может одновременно писать уже в новый.

**Сценарий.** После первой печати приложение меняет `output` или добавляет
BBCode-style в переданную mutable map. Повторный вызов того же уровня/theme
использует старый cache, а ещё не встречавшийся уровень — новую настройку.

**Последствия.** Формально допустимое изменение API применяется частично и
зависит от истории вызовов, что особенно неприятно при подмене sink в тесте
или runtime-конфигурации темы.

**Исправление.** Сделать настройки immutable/unmodifiable и `output` final
либо предоставить setter'ы, которые инвалидируют соответствующий cache.

**Уверенность:** high.

### 14. [Low / P3] `Logger.zonedTags()` возвращает изменяемое состояние зоны

**Где:** `lib/src/logger/logger.dart:235-260`.

**Проблема.** `zonedTraceIds()` защищает список через
`UnmodifiableListView`, а симметричный `zonedTags()` отдаёт исходный `Set`.

**Воспроизведение.** Внутри `trace(..., tags: {'original'})` вызов
`Logger.zonedTags().add('injected')` успешно изменил context на
`{original, injected}`.

**Последствия.** Любой читатель статического getter'а может скрыто менять
tags всех последующих логов в той же async zone.

**Исправление.** Возвращать `UnmodifiableSetView` или копию, симметрично
trace ids.

**Уверенность:** high.

### 15. [Low / P3] Width contract не соответствует экранной ширине Unicode

**Где:** `README.md:219-220`, `lib/src/printer/log_block.dart:39-49`,
`:107-170`, `lib/src/printer/surrogates.dart:1-29`.

**Проблема.** Layout использует длину parser'а/UTF-16 offsets. Код аккуратно
не разрезает surrogate pair, но не считает grapheme clusters и terminal
column width. CJK-символ обычно занимает две колонки, combining sequence —
одну, emoji может состоять из нескольких code points.

**Сценарий.** Сообщение или tag содержит CJK, combining mark либо ZWJ emoji,
а `LogRow.maxLength` используется для переноса и выравнивания tail.

**Последствия.** `maxLength`, alignment и tail positioning визуально
нарушаются на обычном международном вводе; строка может выйти за заявленную
ширину или получить лишние переносы.

**Исправление.** Вынести width abstraction и считать grapheme clusters плюс
wcwidth-подобную terminal width. Все slicing/alignment операции должны
использовать одну модель. Добавить CJK, combining и ZWJ emoji cases.

**Уверенность:** high.

### 16. [Low / P3] Документация не полностью соответствует API

**Где:** `README.md:160-162`, `:206-207`, `:1645`;
`example/README.md:18-22`; `docs/architecture.md:151-154`;
`CHANGELOG.md:130-146`; `lib/src/loggable/loggable.dart:1402-1411`.

**Проблемы.** README и architecture называют отсутствующий `LogElement`
вместо `LogBlock`; LICENSE ведёт на локальный `file:///Users/...`; example
README описывает ручное комментирование кадров, хотя pipeline запускает их
по одному; соседние пункты CHANGELOG сначала требуют `format ^4.1.0`, затем
говорят, что это больше не dependency. `dart doc --validate-links` добавляет
ещё одно предупреждение: текст `[a, b, c, d]` распознаётся как нерешённая
doc-reference.

**Сценарий.** Пользователь следует Deep Dive, ищет `LogElement`, открывает
LICENSE или пытается понять frame pipeline; отдельно maintainer генерирует
API docs с `--validate-links`.

**Последствия.** Пользователь ищет несуществующий тип, получает битую ссылку
и неверно понимает воспроизводимость примеров/историю dependency. Пакетный
dartdoc формально генерируется, но не чист.

**Исправление.** Синхронизировать названия и frame-runner, сделать LICENSE
относительным, переписать changelog как последовательную историю итогового
решения и экранировать квадратные скобки в dartdoc.

**Уверенность:** high.

# Architecture review

Разделение core и IO удачное: web-потребитель не тянет `dart:io` и
`archive`, а publisher boundary позволяет подключать console, память и диск
без зависимости logger'а от конкретного sink. Zone-based tracing и
наследование настроек дочерними logger'ами также образуют связный публичный
контракт.

Главная слабость — несколько разных представлений «одного принятого лога».
`Log` и его данные остаются изменяемыми, sanitizer исполняется во время
рендера, publisher'ы работают в разное время, а `flush()` не несёт результата
durability. Поэтому sync console и async JSONL могут законно увидеть разные
состояния, хотя API внешне выглядит как передача immutable record.

Второй архитектурный риск — концентрация traversal и rendering policy в
одном крупном `loggable.dart`. Приватный config живёт в разных subtype'ах,
root sanitizer имеет отдельные string/JSON/multi-data entrypoint'ы, а
ограничения ширины и коллекций реализованы несколькими ветками. Находка №11
показывает уже возникшую рассинхронизацию.

File storage хорошо разделён на codec/sessions/writer, но security boundary
каталога и семантика потерь не выражены типами или результатами API.
Exclusive create защищает только первый chunk, а дальнейший lifecycle снова
переходит к path-based операциям. Это требует системного решения, а не
локальной проверки одного filename.

Зависимости немногочисленны и соответствуют назначению. `archive` правильно
изолирован в IO barrel; `format` не попадает в граф потребителя. При этом
отсутствие CI оставляет заявленный SDK floor и эти границы без постоянной
проверки.

# Testing review

Финальное состояние на коммите `a175dd7`:

| Проверка | Результат |
| --- | --- |
| `dart analyze` | чисто |
| `dart test` | 434 теста, все прошли |
| `dart format --output=none --set-exit-if-changed .` | 94 файла, изменений нет |
| `cd example && dart analyze` | чисто |
| `cd example && dart run example.dart` | успешно |
| `cd example && dart run bin/file_storage_example.dart` | успешно |
| `cd example && dart compile exe example.dart` | успешно |
| `cd example && dart compile js example.dart` | успешно |
| `dart run tool/playground.dart` | успешно |
| `scripts/screenshots.sh --check` | все 41 кадр совпали |
| `dart pub outdated` | устаревших разрешимых зависимостей нет |
| `dart pub publish --dry-run` | 0 warnings, архив 152 КБ |
| `dart doc --validate-links` | 0 errors, 1 warning (находка №16) |

`shellcheck` в среде отсутствует, поэтому два bash-скрипта им не проверялись;
функциональный screenshot-check прошёл.

### Сильные стороны тестов

- sanitizer проверяется сквозь console и JSONL, включая cycles, replacement,
  drop, map keys и error paths;
- file storage тестирует collision, cleanup, rotation, bounded queue,
  encoding/write failure и recovery;
- printer тестирует wrapping, tail, truncation и целостность surrogate pair;
- screenshot pipeline детерминирован и реально исполняет все README frames;
- export barrels отдельно проверяются, core подтверждён web-компиляцией.

### Существенные пробелы

Нет regression-тестов на:

- асимптотику BBCode и длинные незакрытые теги;
- symlink/hardlink и race вокруг каждого chunk;
- публичные preconditions при отключённых assertions;
- семантику ошибки `flush()` после init/write failure;
- collision нормализованных JSON keys;
- немедленный `close()` до `ready`;
- автоматизированный RSS/heap ceiling потокового GZIP-экспорта;
- wide/combining/ZWJ Unicode;
- mutation уже опубликованного `Log`, zone tags и cached configuration.

В репозитории нет CI-конфигурации. Локально всё зелёное на Dart 3.13.0, но
заявленный floor Dart 3.6 и будущие stable SDK автоматически не проверяются.
Минимальная матрица должна включать Dart 3.6 и current stable, analyze, test,
format-check, web compile, screenshot-check и publish dry-run.

# Performance and reliability

Исходный главный performance-риск был измерен напрямую: BBCode на adversarial
input масштабировался примерно как O(n³) и блокировал isolate. Оба измеренных
риска закрыты: BBCode теперь сканируется за линейное время, а `gzipTo()`
передаёт session streams в один compressor/file sink без накопления набора.
Stress-прогон 128 МБ дал около 5,4 МБ пикового прироста RSS.

В steady state console layout и обычный `Loggable` traversal ограничиваются
размером фактически выводимых данных; cycle protection и collection limits
реализованы. Атомарная oversized JSONL record по принятому контракту может
превысить rotation/retention targets; жёсткую дисковую границу обязан задать
вызывающий код. `maxTotalSize: null` оставляет число и общий размер
экспортируемых sessions неограниченными, но потоковый GZIP больше не связывает
этот объём с потреблением RAM.

Асинхронный publisher имеет bounded queue и не блокирует call site диском —
это хороший базовый выбор. Его reliability contract слабее документации:
ошибки init/write превращаются в успешный drain, а немедленный `close()` не
завершает init lifecycle. В коде нет многопоточного shared-memory race
(обычная модель — один isolate), но есть временные гонки с файловой системой
и другими процессами через path-based chunk operations.

# Maintainability

Публичные типы и основные потоки читаемы, naming последователен, сложные
решения снабжены объясняющими комментариями. Основная стоимость изменений
сосредоточена в `loggable.dart` и больших таблицах theme data; новый renderer
или config source требует синхронного изменения нескольких приватных веток.
Systemic use of `assert` для public preconditions и mutable fields рядом с
identity-cache создают неявные контракты, которые трудно удерживать тестами.

## Dependency management and package hygiene

- `dart pub outdated` не нашёл доступных обновлений при текущих constraints;
- core dependency graph мал и оправдан: ANSI/style, builder, clock, meta,
  stack trace; после потоковой GZIP-замены `archive` удалён совсем;
- `format` корректно остался dev dependency для теста документированного
  formatter recipe;
- package archive не содержит `docs/`, scripts, screenshots и внутренний
  playground; dry-run не выдал предупреждений;
- root и example lock-файлы присутствуют, но воспроизводимость Dart 3.6 не
  подтверждена автоматизацией.

Отдельный vulnerability scanner для pub dependencies не запускался; вывод
«обновлений нет» не равен утверждению «известных уязвимостей нет».

## Архитектурные ограничения и предположения

Это не дополнительные дефекты, а границы оценки:

- symlink-находка предполагает, что иной actor может менять каталог логов;
  при приватном каталоге impact ниже, но нарушение directory boundary
  остаётся;
- `Loggable.sanitizer` намеренно применяется во время рендера, а не при
  создании `Log` (`README.md:1636-1639`). Mutable `data` и глобальное правило
  должны оставаться стабильными до завершения всех async publishers;
- пустой renderer после удаления всех свойств не равен root
  `Sanitize.drop`, поэтому console сохраняет двоеточие. Код трактует это как
  сознательное различие между «пусто» и «отброшено»; UX остаётся спорным;
- trace-id counters живут весь isolate, safe ANSI mode, Map limits и часть
  configuration ergonomics уже отмечены владельцем в backlog;
- измерения производительности сделаны на текущей машине и Dart 3.13.0;
  абсолютные числа меняются, но рост 8× при удвоении входа и многосекундная
  блокировка воспроизводимы.

# Positive findings

- Core/IO boundary реальна, а не декларативна: основной barrel собирается в
  JavaScript и не подтягивает файловые зависимости.
- 434 теста покрывают сложные contracts sanitizer'а, cycles, rendering,
  transformer, buffer и file recovery; тесты читаются как спецификация.
- Bounded async queue отказывает новой записи, сохраняя уже принятую работу,
  и предоставляет `onDropped` для наблюдаемого backpressure.
- Ошибка кодирования одной записи изолируется fallback-строкой и не теряет
  соседний batch; throwing `onError` не ломает pipeline.
- Exclusive reservation первого chunk закрывает collision двух storage
  instances на старте; recovery после partial write переходит в новый chunk.
- README frames воспроизводимы: 41 сценарий исполняется отдельными процессами
  под фиксированными часами и совпадает byte-for-byte.
- Package hygiene хорош: analyze, format, VM/web build и pub dry-run чисты,
  release archive мал и не содержит внутреннюю кухню.

# Prioritized action plan

| Priority | Problem | Impact | Recommended action | Estimated effort |
| --- | --- | --- | --- | --- |
| Now | Кубическое время BBCode | Isolate блокируется коротким input | Линейный parser, adversarial benchmark и regression tests | M |
| Now | Symlink boundary у chunks | Запись/утечка файлов вне log directory | No-follow listing/open, exclusive reservation каждого chunk, private directory policy | M–L |
| Now | Ложная гарантия `flush()` | Незаметная потеря принятой диагностики | Вернуть failure/loss result или ошибку, связать потери с `onDropped` | M |
| Accepted | Одна запись превышает size targets | Атомарная запись может дать неограниченный пик | Контракт документирован; для hard cap вызывающий код ограничивает input | — |
| Fixed | ZIP держал весь набор в RAM | OOM при сборе диагностики | `archiveTo()` заменён потоковым `gzipTo()` | — |
| Fixed | Public validation только в `assert` | Production crash и тихая неверная конфигурация | Runtime `ArgumentError` на согласованных public boundaries | — |
| Fixed | JSON key collisions | Тихая потеря structured data | Коллизия после нормализации даёт `ArgumentError` | — |
| Fixed | Mutable `Log` | Publisher'ы видят разные версии записи | Unmodifiable snapshots с owned hot path | — |
| Fixed | Невалидные session filenames | Невидимая session или disabled storage | Empty id rejected, unrepresentable index ignored | — |
| Next | Raw ANSI из untrusted input | Подмена terminal output | Сквозной safe mode и явный opt-in для raw ANSI | M |
| Later | Config/cache/lifecycle/zone defects | Непоследовательное runtime-поведение | Закрыть находки 11–14 отдельными regression tests | M |
| Later | Unicode width | Съезжают columns и `maxLength` | Единая grapheme/wcwidth abstraction | M–L |
| Later | Docs drift и нет CI | Ошибки использования и непроверенный SDK floor | Исправить ссылки/термины; CI для Dart 3.6 и stable | S–M |

После исправления или явного принятия пунктов 1–10 нужен повторный
security/reliability review с adversarial тестами, а не только повтор текущего
happy-path набора.
