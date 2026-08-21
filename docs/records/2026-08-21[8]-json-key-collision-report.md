# Отчёт о коллизиях JSON-ключей

> **Состояние на 2026-08-21:** исправлено в `fd3045f`; независимое ревью и
> полный набор проверок, включая clean publish dry-run, завершены.
> **Что это:** исправление находки №6 полного ревью.
> **Связанная запись:** `2026-08-21[1]-project-review.md`.

## Проблема и решение

`Loggable.objectToJson()` превращает каждый ключ `Map` в строку: строковый
ключ остаётся как есть, `null` становится `"null"`, остальные используют
`toString()`. Раньше результат без проверки записывался в
`Map<String, Object?>`, поэтому `{1: 'int', '1': 'string'}` и
`{null: 1, 'null': 2}` молча теряли первое значение.

Владелец выбрал fail-fast контракт. После нормализации и escaping каждый
реально выводимый ключ проверяется через `containsKey`; повтор даёт
`ArgumentError` без включения потенциально чувствительного текста ключа в
сообщение. Проверка стоит после `Sanitize.drop`, поэтому удалённая запись не
создаёт ложной коллизии. Обычная форма JSON object и поведение уникальных
ключей не меняются.

Для `FileLogStorage(dataFormat: FileLogDataFormat.json)` отдельного механизма
не понадобилось: существующая изоляция encode errors сообщает исходный
`ArgumentError` через `onError`, пишет безопасную строку
`encodeError: "ArgumentError"` и продолжает batch.

## TDD

До изменения production-кода прямые тесты получили last-write-wins результаты
`{'1': 'string'}` и `{'null': 'string value'}` вместо `ArgumentError`.
Исправленный JSON-mode integration fixture без проверки записал обычную строку
без `encodeError`. После минимальной проверки все целевые тесты зелёные.

Закреплены сценарии:

- `1` против `'1'`;
- `null` против `'null'`;
- первое значение равно `null`, поэтому нужен именно `containsKey`;
- sanitizer удаляет одну конфликтующую запись до проверки;
- JSONL fallback сообщает ошибку и сохраняет соседние логи.

## Проверки

- `dart test test/team_logger_test.dart` — 110 тестов;
- `dart test test/file_storage/file_log_storage_test.dart` — 39 тестов;
- `dart test` — 468 тестов;
- `dart analyze` — чисто в корне и `example/`;
- `dart format .` — 94 файла, изменений нет;
- на минимальном Dart 3.6 — `analyze` чист, 468 тестов;
- `dart run example.dart` и `dart run bin/file_storage_example.dart` — успешно;
- `scripts/screenshots.sh --check` — все 41 кадр совпали;
- `dart doc --validate-links` — 0 ошибок, одно известное предупреждение
  `[a, b, c, d]` из находки №16;
- `dart pub outdated` — устаревших зависимостей нет;
- `dart pub publish --dry-run` после `fd3045f` — 0 предупреждений, архив
  161 КБ;
- `git diff --check` — чисто.

Независимое ревью дополнительно проверило вложенные map, escaping, оба порядка
sanitizer drop, безопасный текст ошибки и storage fallback. Critical/Important
не найдено. Единственное Minor — ранняя строка handoff неверно говорила, что в
дереве изменён только handoff; описание синхронизировано с `git status`.
