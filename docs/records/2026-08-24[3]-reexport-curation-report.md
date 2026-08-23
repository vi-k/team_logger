# Курация реэкспорта `logger_builder`

Состояние на 2026-08-24. Наблюдение владельца: «в team_logger используются
свои `LogLevels`, `Levels` из logger_builder берутся, но для экспорта не
нужны». Разбор показал, что это верно не только про `Levels`.

## Принцип

**`team_logger` — готовый логгер, а не конструктор.** Экспортировать надо то,
что пользователю придётся **назвать по имени**; остальное остаётся в
`logger_builder` — для тех, кто собирает свой логгер. Ничего не теряется:
пакет опубликован, импортируется напрямую.

## Было и стало

`export 'package:logger_builder/logger_builder.dart';` тянул наружу **27**
имён. Осталось **9**:

`CustomLogPublisher`, `CustomLogFormatter`, `MultiPublisher`,
`TransformPublisher`, `AsyncPublisher`, `AsyncPublisherWithBuffer`,
`Flushable`, `Closable`, `LogTransformer`.

Публичная поверхность на pub.dev: **92 → 74 имени**.

## Что убрано и почему

| Убрано | Почему не нужно называть |
| --- | --- |
| `Levels` | второй словарь констант уровней рядом с `LogLevels`, а `LogLevels` и есть тот, которым пакет пользуется; внутри `Levels` встречается 8 раз, и все — в `log_levels.dart`, чтобы определить `LogLevels` |
| `CustomLogger`, `CustomLog`, `CustomLevelLogger` | суперклассы `Logger`, `Log`, `LevelLogger`; все три наследника `final`, расширить нельзя, а унаследованные члены dartdoc показывает на их страницах |
| `Lazy`, `TypedLazy`, `LazyString`, `LazyStringOrNull` | ленивые параметры принимают **замыкания**; эти объекты вызывающий не конструирует |
| `AsyncPublisherBase`, `AsyncPublisherWithBufferBase` | для наследования, которым пакет занимается внутри себя (`FileLogStorage extends AsyncPublisherWithBufferBase<Log>`, и он `final`) |
| `AsyncPublisherWithParam*`, `AsyncPublisherWithBufferAndParam*` (4) | ось «параметр» в `team_logger` не значит ничего |
| `AsyncFormatter`, `AsyncFormatterWithBuffer`, `AsyncFormatterWithParam`, `AsyncFormatterWithBufferAndParam` | уровень конструктора |
| `HasFlush` | устаревший алиас; уходит и из самого `logger_builder` |

Четыре спорных имени владелец решил **оставить**: `AsyncPublisher`
(README §12 советует ставить работу в очередь — вот этим),
`AsyncPublisherWithBuffer`, пара `Flushable`/`Closable` и
`CustomLogFormatter`.

## Проверено

- Ссылок вида `[Имя]` в dartdoc на убираемые имена — **ноль** (проверено до
  правки, поэтому `dart doc --validate-links` не пострадал).
- `dart analyze` чисто в корне и в `example/`, `dart test` — **616**,
  `dart format` без изменений, 43 кадра байт-в-байт, оба примера
  отрабатывают, `dart doc --validate-links` — 0 ошибок.
- Список запинен тестом `test/export_test.dart`: девять имён обязаны
  конструироваться через импорт одного `team_logger.dart`. В комментарии
  теста сказано прямо, что добавление имени сюда — решение, а не рефлекс.

## Что это меняет в плане до 1.0

`2026-08-24[2]-road-to-1.0.md` предлагал развилку: либо вести
`logger_builder` к 1.0, либо сузить реэкспорт. Развилки нет — **нужно и то,
и другое, и они не мешают друг другу**:

- `logger_builder` замораживается **широко** — он конструктор, его
  пользователям нужна вся поверхность (ревью заморозки —
  `logger_builder/docs/records/2026-08-24[1]-api-freeze-review.md`);
- `team_logger` **курирует** свой реэкспорт — он продукт.

Сделано в 0.7.0, до публикации: релиз уже нёс три `[breaking changes]`,
четвёртое едет тем же — пользователь ломается один раз, а не два.

## Правки следом

- `README.md` и `README.ru.md`: фраза «реэкспортирует его целиком» стала
  ложью — переписана, и добавлено, куда идти за остальным.
- `CHANGELOG.md`, раздел 0.7.0, помечено `[breaking changes]`.
