> **Состояние на 2026-08-20:** спека реализована; работа в `main`
> (`1721655`, `b4312d6`, `30bf711`), отчёт —
> `2026-08-20[5]-number-formatter-report.md`.
> **Что это:** дизайн выноса форматирования чисел из пакета в тему, чтобы
> `package:format` подключал пользователь, если оно ему нужно.
> **Связанные записи:** `2026-08-20[2]-int-format-locale-report.md`,
> `2026-08-18[2]-flutter-compat-report.md`.

# Форматирование чисел через тему

## Зачем

`package:format` сидит в `dependencies` пакета ради двух строк в `lib/`:

```dart
// Loggable._intToString и Loggable._doubleToString
final f => format('{:$f}', obj),
```

Всё остальное — это цена, которую платят все потребители. Она уже
обходилась дорого: floor `format` 1.6.0 тянул `intl ^0.20.2`, а
`flutter_localizations` пинит `intl` 0.19.0, из-за чего пакет вообще не
ставился в локализованное Flutter-приложение (см.
`2026-08-18[2]-flutter-compat-report.md`). Починка была в обновлении до
4.1.0, но зависимость никуда не делась — и вместе с ней осталась чужая
эволюция синтаксиса, за которой пакет вынужден следить: тот же `,n`
перестал быть валидным и уронил пример (`2026-08-20[2]`).

Форматирование чисел нужно меньшинству пользователей. Значит его место —
точка расширения, а не жёсткая зависимость.

Форма выбрана владельцем: **сами форматы остаются в `LoggableConfig`, а
форматтер живёт в теме** — рядом с `valueFormatter`, `messageFormatter`,
`countFormatter`, `indexFormatter`, `cycleFormatter`. Тема уже прокинута в
обе точки рендера отдельным параметром, так что место готовое.

## Публичный API

Новый top-level typedef в `lib/src/theme/log_main_theme.dart`, рядом с
существующим `LogThemeFormatter`:

```dart
typedef LogNumberFormatter = String Function(
  LogTheme theme,
  num value,
  String pattern,
);
```

Новое поле `LogMainTheme`:

```dart
final LogNumberFormatter numberFormatter;   // default: _defaultNumberFormatter

static String _defaultNumberFormatter(
  LogTheme theme,
  num value,
  String pattern,
) =>
    value.toString();
```

Новый метод `LogTheme`, рядом с `formatIndex`/`formatCount`/`formatCycle`:

```dart
String formatNumber(num value, String pattern) =>
    main.numberFormatter(this, value, pattern);
```

Рецепт на стороне приложения — одна строка, и `format` в его собственном
`pubspec.yaml`:

```dart
LogMainTheme.defaultActiveTheme.copyWith(
  numberFormatter: (theme, value, pattern) => format(pattern, value),
)
```

Один форматтер на `int` и `double`, а не два. Спецификаторы в
`LoggableConfig` остаются раздельными (`intFormat`, `doubleFormat`), но
вызов один и тот же; кому нужно различать — `value is int` внутри своего
форматтера.

Форматтер живёт только в `LogMainTheme`, не в `LogThemeData`: по уровням
не разводятся и `countFormatter`/`indexFormatter`/`cycleFormatter`.

### Строка в конфиге — целый шаблон, а не спецификатор

Это второе решение владельца и главное отличие от «просто вынести вызов».
Сейчас `{:$f}` собирает team_logger — то есть знание о синтаксисе чужого
пакета зашито у нас, и развязка была бы неполной. После правки пакет
передаёт строку **как есть**:

| было | стало |
| --- | --- |
| `intFormat: ',d'` | `intFormat: '{:,d}'` |
| `doubleFormat: '.4f'` | `doubleFormat: '{:.4f}'` |
| `intFormat: '#x'` | `intFormat: '{:#x}'` |

Из `lib/` исчезает последнее упоминание `package:format`: ни импорта, ни
строки `'{:$f}'`. Побочный плюс — подключить можно не только брейсы:
`(theme, value, pattern) => sprintf(pattern, [value])`, и тогда в конфиге
пишут `'%d'`. Или вообще свою функцию, не имеющую отношения к `format`.

Параметр назван `pattern`, а не `spec`: «спецификатор» после этого решения
неточно, а имя `format` столкнулось бы с функцией внутри рецепта. Имена
полей `intFormat`/`doubleFormat` не меняются.

## Точки рендера

`lib/src/loggable/loggable.dart`, ровно две строки:

```dart
// _intToString
'${switch (config.intFormat) {
  null => obj.toString(),
  final f => theme.formatNumber(obj, f),
}}'

// _doubleToString, внутри ветки isFinite
'${switch (config.doubleFormat) {
  null => obj.toString(),
  final f => theme.formatNumber(obj, f),
}}'
```

`nan`/`inf` как и раньше форматирование обходят и печатаются как `nan`,
`-inf`, `inf`; `units` как и раньше приклеиваются **после**
отформатированного значения.

Импорт `package:format/format.dart` из файла уходит.

## Поведение по умолчанию

Тема, которой форматтер не задали, шаблон **игнорирует** и печатает
`value.toString()`. Молча: ни исключения, ни маркера в выводе.

Это решение владельца, и у него два следствия, оба нужные:

1. Путь без темы перестаёт быть проблемой. `Loggable.objectToString` и
   `toString()` рендерят через `const LogTheme.noColors`, в которую
   форматтер положить нечем; при бросающем дефолте интерполяция `'$obj'`
   для объекта с `intFormat` роняла бы вызывающий код. При тихом дефолте
   она просто печатает число как есть. Ни nullable-параметров `theme:`, ни
   настраиваемого `Loggable.defaultTheme`, ни статических запасок вводить
   не нужно.
2. Невалидный шаблон больше не роняет логирование сам по себе. Раньше
   `,n` бросал `InvalidSpecifierException` из недр `format` в точку
   логирования; теперь бросить может только форматтер, который поставил
   сам пользователь, — и это его исключение, по обычному контракту
   бросающего рендера (`ConsoleLogPrinter` выпускает наружу,
   `FileLogStorage` ловит на лог, репортит в `onError` и пишет
   fallback-строку, `MultiPublisher` изолирует).

Цена — тоже названная: у того, кто обновится и не прочтёт CHANGELOG,
`intFormat: ',d'` молча начнёт печатать `123456789` вместо `123,456,789`.
Это надо описать в ломающем пункте прямо, вместе с обеими правками
перехода.

## Зависимость

`format` переезжает из `dependencies` в `dev_dependencies`
`pubspec.yaml`. Пакет его больше не импортирует; тесты — импортируют, и
пинят ровно тот рецепт, который документирует README. У потребителя
`format` уходит из графа полностью.

## Миграция для пользователя

Две правки, и обе обязательны, если форматирование чисел использовалось:

1. Добавить `format` в свой `pubspec.yaml` и положить форматтер в тему:
   `numberFormatter: (theme, value, pattern) => format(pattern, value)`.
2. Переписать строки в конфигах: `',d'` → `'{:,d}'`, `'.4f'` →
   `'{:.4f}'`, и так далее — то, что раньше было спецификатором внутри
   `{:…}`, теперь пишется целиком.

Кто форматированием чисел не пользовался — не делает ничего.

## Затрагиваемые файлы

Библиотека:

- `lib/src/theme/log_main_theme.dart` — typedef, поле, дефолтная функция,
  оба конструктора (публичный `LogMainTheme({…})` и `const
  LogMainTheme._({…})`), `copyWith`, `collectLoggableData`.
- `lib/src/theme/log_theme.dart` — `formatNumber`.
- `lib/src/loggable/loggable.dart` — минус импорт, две строки рендера.
- `lib/src/loggable/loggable_config.dart` — dartdoc: `intFormat` и
  `doubleFormat` в шапке класса не описаны **вообще**, и это место, где
  надо сказать новый контракт: непрозрачная строка, которую пакет
  передаёт в `numberFormatter` темы вместе со значением; смысл ей придаёт
  форматтер; без форматтера она игнорируется.
- `pubspec.yaml` — `format` в `dev_dependencies`.

В `collectLoggableData` поле печатается простым `..prop('numberFormatter',
numberFormatter)` — **без** сэмпла, в отличие от `countFormatter` и
`indexFormatter`, которые показывают себя на примере. Любой пример
шаблона был бы диалектно-специфичным (`'{:,d}'` — это синтаксис `format`),
а мы именно это знание и выносим.

Тесты:

- `test/loggable/number_format_test.dart` — переписать: рендер через тему
  с рецептом; файл продолжает пинить поведение `format`, но уже как
  поведение подключённого форматтера.
- `test/export_test.dart` — `LogNumberFormatter` виден из барреля.

Документация и пример:

- `README.md`, раздел «Formatting Settings» — `format` в pubspec
  приложения, форматтер в теме, шаблоны вместо спецификаторов.
- `example/pubspec.yaml` — `format` возвращается.
- `example/lib/readme_examples/default_log.dart` — форматтер в теме.
- `example/bin/readme_examples/data.dart` — три шаблона.
- `example/bin/example.dart` — строки 251 и 257 (`doubleFormat: '.2f'`,
  `intFormat: ' d'`) и тема на строках 7–11.
- `CHANGELOG.md` — ломающий пункт.
- `docs/architecture.md` — тема как точка подключения форматирования
  чисел.
- `docs/handoff.md`.

## Тесты

Переписать `number_format_test.dart` так, чтобы рендер шёл через тему:

```dart
final theme = LogMainTheme.noColors
    .copyWith(
      numberFormatter: (theme, value, pattern) => format(pattern, value),
    )
    .verbose;   // LogMainTheme.verbose/debug/... отдают LogTheme уровня

String render(Object? value, LoggableConfig config) =>
    Loggable.objectToString(value, theme: theme, config: config);
```

Кейсы, которые должны быть после правки:

1. Существующая таблица `intFormat`/`doubleFormat` — те же ожидания, но
   шаблоны в фигурных скобках (`'{:d}'`, `'{:05d}'`, `'{:x}'`, `'{:,d}'`,
   `'{:+d}'`, `'{:.4f}'`, `'{:g}'` и прочие, что есть в файле).
2. Группировка тысяч и `units` после отформатированного значения — как
   сейчас, через тему.
3. Дефолтная тема (без форматтера): `intFormat` и `doubleFormat`
   игнорируются, печатается `toString()`, исключения нет. Отдельно для
   int и для double.
4. Форматтер получает ровно ту строку, что лежит в конфиге, и ровно то
   значение (проверить перехватом, без `format`).
5. `nan`/`inf` не доходят до форматтера даже когда `doubleFormat` задан.
6. `LogMainTheme.copyWith(numberFormatter: …)` действительно доносит поле
   (поле в `copyWith` легко забыть, а тестов на `copyWith` темы сейчас
   нет ни одного).
7. `,n` продолжает бросать — но теперь как исключение форматтера
   пользователя, а не пакета.

## Границы: чего не делаем

- `LoggableJsonConfig` не трогаем: в JSON числа пишутся сырыми,
  форматирование там не применялось и не появится.
- Отдельных `intFormatter`/`doubleFormatter` в теме не заводим — один на
  `num`.
- Per-level форматтера в `LogThemeData` не заводим.
- `intFormat`/`doubleFormat` не переименовываем.
- Пакет-адаптер (`team_logger_format`) не заводим: рецепт в одну строку
  живёт в README.
- `Loggable.defaultTheme` и nullable `theme:` не вводим — при тихом
  дефолте не нужно.

## Что проверить в конце

- Вывод `example/bin/example.dart` изменится в двух местах помимо самих
  чисел: строка 158 печатает саму тему (`log.d('$LogMainTheme', data:
  theme)`), так что в выводе появится новое свойство `numberFormatter`.
  Пин «374 строки» в handoff после этого недействителен — пересчитать.
- `screenshots/data_6.png` переснять, если numbers-блок разошёлся с
  текущим (при верном рецепте не должен: `'{:,d}'` даёт то же
  `123,456,789`).
- Матрица Flutter: `format` уходит из зависимостей потребителя, то есть
  граф меняется — переснять.
