# Runtime-валидация публичных предусловий

> **Состояние на 2026-08-21:** реализовано в `1b9f1f0`; RED–GREEN, полный
> набор проверок на current stable и Dart 3.6, независимое ревью завершены.
> **Что это:** отчёт об исправлении находки №9 полного ревью проекта.
> **Связанные записи:** `2026-08-21[1]-project-review.md`.

## Что ломалось

Несколько публичных API проверяли опасные параметры только через `assert`.
Обычный production-запуск Dart выключает assertions, поэтому неверная
конфигурация принималась и проявлялась позже либо работала молча неправильно.

Реальный subprocess-probe без assertions подтвердил все шесть границ:

- `LogStorage(maxCount: 0)` создавался; первая публикация затем падала с
  `RangeError` в точке логирования;
- размеры `FileLogStorage` не защищали file-retention invariants;
- `ConsoleLogPrinter` принимал active filter без `inactiveTheme`;
- публичный `LogMainTheme` принимал опасные punctuation tokens;
- оба строковых renderer'а `Loggable` принимали отрицательные/нулевые лимиты
  и управляющие коды в разделителях.

В ходе реализации обнаружилась та же граница у
`FileLogStorage.maxQueueSize`: проверка жила в assert базового пакета. Значение
0 в production создавало очередь, которая отказывала каждому входящему логу.

## Что изменено

Перечисленные предусловия теперь дают синхронный `ArgumentError.value` с
именем и исходным значением параметра. Для `FileLogStorage` проверки размеров
идут до codec, clock, superclass и файловой инициализации в том же порядке,
что прежние assertions; `maxQueueSize` проверяется затем в аргументе `super`.

В `ConsoleLogPrinter` покрыты все шесть веток active filter. `LogMainTheme`
проверяет каждый punctuation token и односимвольный `padding`. Два строковых
renderer'а используют общий helper: два числовых сравнения и прямой проход по
code units `start`/`end`, без RegExp, промежуточных коллекций и замыканий.

Изменение breaking только по типу и моменту ошибки: вместо debug-only
`AssertionError`, позднего исключения или молча неверного поведения теперь
всегда приходит ранний `ArgumentError`. Сигнатуры API не менялись.

## Осознанные границы

Охват ограничен пятью зонами исходной находки и соседним `maxQueueSize` того
же `FileLogStorage`. Не менялись:

- JSON-renderer `Loggable`, где отрицательный limit уже имеет явный runtime
  fallback к нулю;
- взаимное исключение config/individual arguments у `LoggableData.prop`;
- внутреннее требование непустых lines у `LogBox`.

Это отдельные контракты; смешивать их в один breaking diff без решения
владельца нельзя.

## RED–GREEN и ревью

Первый RED дал 27 ожидаемых падений. Обычные тесты получили прежние
`AssertionError`, а дочерний production-process сообщил, что все шесть
границ завершились нормально.

Независимое ревью нашло изменение precedence: при одновременно неверных
`maxChunkSize` и `maxQueueSize` новая версия сначала сообщала queue. Отдельный
тест воспроизвёл ошибку RED; ранняя size-validation вернула прежний порядок.
Ревью также потребовало отрицательные значения для всех non-positive
границ и полный FileLogStorage-набор в subprocess. После исправлений повторный
вердикт: Critical/Important/Minor нет, `Ready to merge — Yes`.

## Производительность

Ни одна проверка не добавлена в `publish`, очередь, encoding или файловую
запись. Конструкторские проверки выполняются один раз.

Для строкового renderer'а временный AOT-benchmark сделал два warm-up и девять
измеряемых раундов: по 5 000 000 вызовов эквивалентной allocation-free
валидации и по 300 000 типичных рендеров трёх элементов. Медианы:

- валидация — 2,23 нс/op;
- `Loggable.iterableToString([1, 2, 3])` — 1749,04 нс/op;
- верхняя оценка доли — 0,13%.

Probe и AOT-бинарник после измерения удалены.

## Проверки

- focused runtime-validation/storage — 73/73;
- `dart test` — 503/503 на current stable и Dart 3.6;
- `dart analyze` — чисто в корне, `example/` и на Dart 3.6;
- `dart format --output=none --set-exit-if-changed .` — 96 файлов, без
  изменений;
- `scripts/screenshots.sh --check` — 41/41;
- `dart doc --validate-links` — 0 ошибок, одно прежнее предупреждение
  находки №16;
- чистый `dart pub publish --dry-run` — 0 предупреждений, архив 166 КБ;
- `git diff --check` — чисто.
