> **Состояние на 2026-08-18:** сделано и смержено в `main`; вошло в
> невыпущенную 0.7.0.
> **Что это:** отчёт об обновлении `ansi_escape_codes` 3.1.2 → 4.0.1 и
> `logger_builder` 0.5.0 → 0.6.1.
> **Связанные записи:** `2026-08-17[1]-agent-docs-setup-report.md`.

# Обновление ansi_escape_codes и logger_builder

## ansi_escape_codes 3.1.2 → 4.0.1

Ломающее здесь одно, но масштабное: 530 констант-стилей верхнего уровня
исчезли, вместо них класс `Styles` (783 константы). Это дало 441 ошибку
`undefined_prefixed_name` — почти весь `log_theme_data.dart` и куски
`log_main_theme.dart`, README и примеров. Правка механическая:
`ansi.rgb030` → `ansi.Styles.rgb030`, то же для `gray*`, `bold`, `dim`,
`italic`, `underline`, `strikethrough`.

Второе: точка входа `parsing.dart` удалена — после 4.0.0 она стала
байт-в-байт равна `style.dart`. `log_block.dart` и
`control_code_formatter.dart` переведены на `style.dart`.

Остальные ломающие изменения пакета (`Match` → `Piece`, `Link` →
`OscLink`, `rgb`/`gray` → `rgb256`/`gray256`, `Style.defaults`,
`Color.withPrefix`) этой кодовой базы не касаются — она их не использует.

По решению владельца `Styles` добавлен в реэкспорт `lib/team_logger.dart`
рядом с `Style`, `NoStyle`, `Color16`, `Color256`: теперь настройка темы
не требует прямой зависимости от `ansi_escape_codes`. README и примеры в
`example/bin/readme_examples/` переписаны без префикса — `Styles.rgb030` —
и три из них потеряли импорт ansi целиком. `test/export_test.dart`
проверяет новое имя.

## logger_builder 0.5.0 → 0.6.1

Компилироваться ничего не мешало, но одно задокументированное поведение
поменялось. Дартдок `Logger` утверждал, что лог из трансформера через тот
же логгер уходит в `StackOverflowError`. В 0.6.0 появился сторож
реентрантности: вложенный лог выбрасывается, а `StateError` уходит в
`CustomLogger.onError` (или в текущую зону). Проверено экспериментом —
`depth=1`, один напечатанный лог, `Bad state: A log transformer must not
log through its own logger; the nested log was dropped`. Дартдок и
`docs/architecture.md` исправлены.

Прочие ломающие изменения апстрима на пакет не влияют, но отражены в
CHANGELOG, потому что протекают к пользователям через реэкспорт: уровень
на пороге (`Levels.all`/`Levels.off`) отвергается, один `LevelLogger` в
двух логгерах бросает, `TransformPublisher.close()` терминален, сублоггер
держит родителя сильной ссылкой. Даром достались `CustomLogger.onError`,
`CustomLevelLogger.hasPublisher`, `AsyncPublisherWithBufferBase.onDropped`,
`retryDelay` и важные для `FileLogStorage` починки буферизованных
публишеров (`flush()` во время `close()`, `close()` без ожидания
retry-таймера, отсутствие голодания event loop).

Пункт бэклога про по-уровневый linked-флаг апстрим **не** закрыл:
`_setLevelPublisher` в 0.6.1 по-прежнему снимает `publisherLinked` со всего
логгера. Пункт остаётся в `docs/backlog.md`.

## Проверка

`dart analyze` чист в корне и в `example/`, 396 тестов зелёные,
`dart format` чист. Все примеры запускаются. Главная проверка — вывод
`example/bin/example.dart` до и после обновления: сняты оба прогона (старые
версии зависимостей возвращались через `git stash`), нормализованы время и
pid, `diff` пуст. То есть ANSI-рендер не поехал ни на байт.

## Чего не делали

`format` 1.6.0 → 4.0.0 и `lints` 5.1.1 → 6.1.0 не трогали — просили два
пакета. Оба мажорные; `lints` 6 почти наверняка потянет правки под новые
правила.
