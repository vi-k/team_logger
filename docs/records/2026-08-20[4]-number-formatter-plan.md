> **Состояние на 2026-08-20:** план согласован, к реализации не приступали.
> **Что это:** план работ по спеке выноса форматирования чисел в тему.
> **Связанные записи:** `2026-08-20[3]-number-formatter-design.md`.

# Number formatter in the theme — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Убрать `package:format` из зависимостей `team_logger`, отдав
форматирование чисел форматтеру темы, который подключает пользователь.

**Architecture:** `LoggableConfig.intFormat`/`doubleFormat` остаются
`String?`, но их содержимое становится непрозрачным шаблоном. Новый
`LogMainTheme.numberFormatter` (тип `LogNumberFormatter`) получает
`(theme, value, pattern)`; `LogTheme.formatNumber` — точка вызова из
рендереров. Дефолт темы шаблон игнорирует и печатает `value.toString()`.

**Tech Stack:** Pure Dart, `package:test`. `package:format` остаётся только
в `dev_dependencies` — как рецепт, который пинят тесты.

**Spec:** `docs/records/2026-08-20[3]-number-formatter-design.md`

## Global Constraints

- `environment.sdk: ^3.6.0` — floor не поднимать; всё должно собираться на
  настоящем Dart 3.6 (SDK внутри fvm Flutter 3.27).
- Зелёные проверки после каждой задачи: `dart analyze` (корень и
  `example/`), `dart test`, `dart format .`.
- Документы для владельца и агентов — по-русски; `README.md`,
  `CHANGELOG.md`, dartdoc в `lib/`, сообщения коммитов — по-английски.
- Коммит прямо в `main`, без PR; чужие правки не коммитить вместе со
  своими.
- Публикацию не запускать и не предлагать (`AGENTS.md`, «Публикация на
  pub.dev»).
- Версия остаётся 0.7.0 — она не выпущена, отдельный бамп не нужен.

---

### Task 1: Форматтер чисел в теме

Публичный API целиком, без единого изменения в рендере: после этой задачи
`numberFormatter` существует, доносится через `copyWith` и вызывается
через `LogTheme.formatNumber`, но `Loggable` его ещё не зовёт.

**Files:**
- Modify: `lib/src/theme/log_main_theme.dart` (typedef после
  `LogThemeFormatter`, поле после `indexFormatter`, дефолтная функция
  рядом с `_defaultCountFormatter`, оба конструктора, `copyWith`,
  `collectLoggableData`)
- Modify: `lib/src/theme/log_theme.dart` (метод после `formatCycle`)
- Test: `test/theme/log_main_theme_test.dart` (создать)
- Test: `test/export_test.dart`

**Interfaces:**
- Produces: `typedef LogNumberFormatter = String Function(LogTheme theme,
  num value, String pattern);`, поле
  `LogMainTheme.numberFormatter` (`LogNumberFormatter`, non-nullable),
  параметр `numberFormatter` у `LogMainTheme(...)` и
  `LogMainTheme.copyWith(...)`, метод
  `LogTheme.formatNumber(num value, String pattern) -> String`.

- [ ] **Step 1: Написать падающие тесты темы**

Создать `test/theme/log_main_theme_test.dart`:

```dart
import 'package:team_logger/team_logger.dart';
import 'package:test/test.dart';

void main() {
  group('LogMainTheme.numberFormatter', () {
    test('default ignores the pattern and prints toString()', () {
      final theme = LogMainTheme.noColors.verbose;

      expect(theme.formatNumber(1234567, '{:,d}'), '1234567');
      expect(theme.formatNumber(1234.5678, '{:.2f}'), '1234.5678');
    });

    test('formatNumber hands over the value and the pattern verbatim', () {
      final calls = <(num, String)>[];
      final theme = LogMainTheme.noColors
          .copyWith(
            numberFormatter: (theme, value, pattern) {
              calls.add((value, pattern));

              return 'formatted';
            },
          )
          .verbose;

      expect(theme.formatNumber(42, 'not a format'), 'formatted');
      expect(calls, [(42, 'not a format')]);
    });

    test('the formatter receives the level theme it was taken from', () {
      late LogTheme seen;
      final main = LogMainTheme.noColors.copyWith(
        numberFormatter: (theme, value, pattern) {
          seen = theme;

          return '';
        },
      );

      main.error.formatNumber(1, 'p');

      expect(seen.level, LogLevels.error);
    });

    test('copyWith carries the formatter through a later copy', () {
      final theme = LogMainTheme.noColors.copyWith(
        numberFormatter: (theme, value, pattern) => 'x',
      );

      expect(theme.copyWith(colon: '=').verbose.formatNumber(1, 'p'), 'x');
    });
  });
}
```

- [ ] **Step 2: Убедиться, что тесты падают**

Run: `dart test test/theme/log_main_theme_test.dart`
Expected: FAIL на компиляции — `formatNumber` и параметр
`numberFormatter` не существуют.

- [ ] **Step 3: Добавить typedef**

Внимание: `analysis_options.yaml` включает `comment_references`, а
`LoggableConfig` в `log_main_theme.dart` не импортирован (импорт был бы
циклом — `loggable_config.dart` сам импортирует тему). Поэтому ссылки на
его поля в dartdoc этого файла — в обратных кавычках, а не в квадратных
скобках.

В `lib/src/theme/log_main_theme.dart` сразу после существующего
`LogThemeFormatter`:

```dart
/// A theme's number formatter: it receives the value and the **opaque
/// pattern** from `LoggableConfig.intFormat`/`LoggableConfig.doubleFormat`
/// and returns the rendered string.
///
/// The package does not parse the pattern and defines no syntax for it —
/// the formatter does. See [LogMainTheme.numberFormatter].
typedef LogNumberFormatter = String Function(
  LogTheme theme,
  num value,
  String pattern,
);
```

- [ ] **Step 4: Добавить поле и дефолтную функцию**

Поле — сразу после `final LogThemeFormatter<int> indexFormatter;`:

```dart
  /// Renders a number whose `LoggableConfig.intFormat` or
  /// `LoggableConfig.doubleFormat` is set; the pattern arrives here exactly
  /// as it was written, together with the value.
  ///
  /// The default ignores the pattern and prints `value.toString()`: this
  /// package depends on no number formatter and knows no pattern syntax.
  /// Install one to make patterns work — for example over
  /// [`package:format`](https://pub.dev/packages/format), which is what the
  /// README documents:
  ///
  /// ```dart
  /// LogMainTheme.defaultActiveTheme.copyWith(
  ///   numberFormatter: (theme, value, pattern) => format(pattern, value),
  /// )
  /// ```
  ///
  /// An exception thrown here reaches the publisher that was rendering, the
  /// same way a throwing [Loggable.sanitizer] rule does.
  final LogNumberFormatter numberFormatter;
```

Дефолтная функция — рядом с `_defaultCountFormatter`:

```dart
  static String _defaultNumberFormatter(
    LogTheme theme,
    num value,
    String pattern,
  ) =>
      value.toString();
```

- [ ] **Step 5: Прокинуть поле через оба конструктора, copyWith и вывод**

Публичный конструктор `LogMainTheme({...})` — после
`this.indexFormatter = _defaultIndexFormatter,`:

```dart
    this.numberFormatter = _defaultNumberFormatter,
```

Приватный `const LogMainTheme._({...})` — в списке инициализаторов после
`indexFormatter = _defaultIndexFormatter,`:

```dart
        numberFormatter = _defaultNumberFormatter,
```

`copyWith` — параметр после `LogThemeFormatter<int>? indexFormatter,`:

```dart
    LogNumberFormatter? numberFormatter,
```

и в теле после `indexFormatter: indexFormatter ?? this.indexFormatter,`:

```dart
        numberFormatter: numberFormatter ?? this.numberFormatter,
```

`collectLoggableData` — после блока `..prop('indexFormatter', …)`:

```dart
      ..prop('numberFormatter', numberFormatter)
```

Без `view` с сэмплом (в отличие от `countFormatter`/`indexFormatter`):
любой пример шаблона был бы диалектно-специфичным, а это знание мы и
выносим.

- [ ] **Step 6: Добавить `LogTheme.formatNumber`**

В `lib/src/theme/log_theme.dart`, после `formatCycle`:

```dart
  String formatNumber(num value, String pattern) =>
      main.numberFormatter(this, value, pattern);
```

- [ ] **Step 7: Прогнать тесты темы**

Run: `dart test test/theme/log_main_theme_test.dart`
Expected: PASS, 4 теста.

- [ ] **Step 8: Добавить пин на экспорт**

В `test/export_test.dart` дописать в конец `main()`:

```dart
  test('team_logger exports the number formatter typedef', () {
    const LogNumberFormatter formatter = _plainNumber;

    expect(formatter(LogTheme.noColors, 42, 'ignored'), '42');
  });
```

и в конец файла:

```dart
String _plainNumber(LogTheme theme, num value, String pattern) =>
    value.toString();
```

- [ ] **Step 9: Полная проверка и коммит**

Run: `dart analyze && dart test && dart format .`
Expected: analyze чист, все тесты зелёные, format ничего не меняет.

```bash
git add lib/src/theme/log_main_theme.dart lib/src/theme/log_theme.dart \
        test/theme/log_main_theme_test.dart test/export_test.dart
git commit -m "feat: give the theme a number formatter"
```

---

### Task 2: Рендер через тему, `format` вон из зависимостей

**Files:**
- Modify: `test/loggable/number_format_test.dart` (переписать)
- Modify: `lib/src/loggable/loggable.dart` (импорт на строке 4, две ветки
  `switch` в `_intToString` и `_doubleToString`)
- Modify: `lib/src/loggable/loggable_config.dart` (dartdoc шапки класса)
- Modify: `pubspec.yaml`

**Interfaces:**
- Consumes: `LogTheme.formatNumber(num, String)` из Task 1.
- Produces: `LoggableConfig.intFormat`/`doubleFormat` как непрозрачные
  шаблоны; `package:format` больше не импортируется из `lib/`.

- [ ] **Step 1: Переписать тест форматирования чисел**

Заменить `test/loggable/number_format_test.dart` целиком:

```dart
import 'package:format/format.dart';
import 'package:team_logger/team_logger.dart';
import 'package:test/test.dart';

/// Пины на форматирование чисел через форматтер темы.
///
/// `intFormat`/`doubleFormat` — непрозрачные шаблоны: пакет передаёт их в
/// `LogMainTheme.numberFormatter` вместе со значением и сам не разбирает.
/// Здесь в тему кладётся рецепт поверх `package:format` — тот самый, что
/// документирует README, — поэтому файл продолжает пинить и поведение
/// `format`. Пробел вскрылся при переборе его версий: между ветками 1.x и
/// 4.x расходится `{:g}` — для 1234.5678 ветка 1.x печатала `1234.57`,
/// ветка 4.x печатает `1234.5678`.
void main() {
  final formatting = LogMainTheme.noColors
      .copyWith(
        numberFormatter: (theme, value, pattern) => format(pattern, value),
      )
      .verbose;

  String render(Object? value, LoggableConfig config) =>
      Loggable.objectToString(value, theme: formatting, config: config);

  String plain(Object? value, LoggableConfig config) =>
      Loggable.objectToString(value, config: config);

  group('intFormat', () {
    const cases = <String, String>{
      '{:d}': '42',
      '{:5d}': '   42',
      '{:-5d}': '   42',
      '{:05d}': '00042',
      '{:,d}': '42',
      '{:x}': '2a',
      '{:X}': '2A',
      '{:o}': '52',
      '{:b}': '101010',
      '{:+d}': '+42',
    };

    for (final MapEntry(key: pattern, value: expected) in cases.entries) {
      test('$pattern renders $expected', () {
        expect(render(42, LoggableConfig(intFormat: pattern)), expected);
      });
    }

    test('groups thousands', () {
      expect(
        render(1234567, const LoggableConfig(intFormat: '{:,d}')),
        '1,234,567',
      );
    });

    test('keeps units after the formatted value', () {
      expect(
        render(42, const LoggableConfig(intFormat: '{:05d}', units: 'ms')),
        '00042ms',
      );
    });

    // Локалезависимого варианта здесь нет: `format` читает свою
    // `NumberLocale` из инстанса `Format`, а рецепт зовёт топ-уровневый
    // `format()`. С версии 3.0.0 он не смотрит и в `Intl.defaultLocale`.
    test('n follows the C locale and does not group', () {
      expect(
        render(1234567, const LoggableConfig(intFormat: '{:n}')),
        '1234567',
      );
    });

    test(',n is rejected by the installed formatter', () {
      expect(
        () => render(1234567, const LoggableConfig(intFormat: '{:,n}')),
        throwsA(anything),
      );
    });
  });

  group('doubleFormat', () {
    const cases = <String, String>{
      '{:.2f}': '1234.57',
      '{:.0f}': '1235',
      '{:10.2f}': '   1234.57',
      '{:-10.2f}': '   1234.57',
      '{:010.2f}': '0001234.57',
      '{:,.2f}': '1,234.57',
      '{:+.2f}': '+1234.57',
      '{:.3e}': '1.235e+3',
      // На ветке 1.x здесь было '1234.57' — см. шапку файла.
      '{:g}': '1234.5678',
    };

    for (final MapEntry(key: pattern, value: expected) in cases.entries) {
      test('$pattern renders $expected', () {
        expect(
          render(1234.5678, LoggableConfig(doubleFormat: pattern)),
          expected,
        );
      });
    }

    test('rounds half to even the same way in every branch', () {
      expect(
        render(2.675, const LoggableConfig(doubleFormat: '{:.2f}')),
        '2.67',
      );
      expect(
        render(2.665, const LoggableConfig(doubleFormat: '{:.2f}')),
        '2.67',
      );
    });

    test('keeps units after the formatted value', () {
      expect(
        render(
          1234.5678,
          const LoggableConfig(doubleFormat: '{:.1f}', units: 'm'),
        ),
        '1234.6m',
      );
    });
  });

  group('the pattern is opaque to the package', () {
    test('it reaches the formatter exactly as written', () {
      final seen = <(num, String)>[];
      final theme = LogMainTheme.noColors
          .copyWith(
            numberFormatter: (theme, value, pattern) {
              seen.add((value, pattern));

              return 'formatted';
            },
          )
          .verbose;

      expect(
        Loggable.objectToString(
          42,
          theme: theme,
          config: const LoggableConfig(intFormat: 'not a format at all'),
        ),
        'formatted',
      );
      expect(seen, [(42, 'not a format at all')]);
    });

    test('nan and inf never reach the formatter', () {
      final seen = <String>[];
      final theme = LogMainTheme.noColors
          .copyWith(
            numberFormatter: (theme, value, pattern) {
              seen.add(pattern);

              return 'formatted';
            },
          )
          .verbose;

      String rendered(double value) => Loggable.objectToString(
            value,
            theme: theme,
            config: const LoggableConfig(doubleFormat: '{:.2f}'),
          );

      expect(rendered(double.nan), 'nan');
      expect(rendered(double.infinity), 'inf');
      expect(rendered(double.negativeInfinity), '-inf');
      expect(seen, isEmpty);
    });
  });

  group('no formatter in the theme', () {
    test('an int pattern is ignored, not applied', () {
      expect(
        plain(1234567, const LoggableConfig(intFormat: '{:,d}')),
        '1234567',
      );
    });

    test('a double pattern is ignored, not applied', () {
      expect(
        plain(1234.5678, const LoggableConfig(doubleFormat: '{:.2f}')),
        '1234.5678',
      );
    });

    test('units still follow the value', () {
      expect(
        plain(42, const LoggableConfig(intFormat: '{:05d}', units: 'ms')),
        '42ms',
      );
    });

    test('a pattern nobody can honour does not throw', () {
      expect(
        () => plain(1234567, const LoggableConfig(intFormat: '{:,n}')),
        returnsNormally,
      );
    });
  });
}
```

- [ ] **Step 2: Убедиться, что тесты падают**

Run: `dart test test/loggable/number_format_test.dart`
Expected: FAIL — рендер всё ещё зовёт `format('{:$f}', obj)`, поэтому
шаблон `'{:d}'` превращается в `'{:{:d}}'`, а группа «no formatter in the
theme» падает на том, что шаблон применяется.

- [ ] **Step 3: Перевести рендереры на тему**

В `lib/src/loggable/loggable.dart` удалить строку

```dart
import 'package:format/format.dart';
```

и в обеих функциях заменить ветку `final f => format('{:$f}', obj),` на:

```dart
        final f => theme.formatNumber(obj, f),
```

(`_intToString` — примерно строка 1913, `_doubleToString` — примерно
1925; в обоих случаях это единственная строка со словом `format` в теле.)

- [ ] **Step 4: Прогнать тесты**

Run: `dart test test/loggable/number_format_test.dart`
Expected: PASS.

- [ ] **Step 5: Описать поля в dartdoc `LoggableConfig`**

В шапке класса `LoggableConfig` (`lib/src/loggable/loggable_config.dart`)
`intFormat` и `doubleFormat` не описаны вообще. Дописать после абзаца про
`units`:

```dart
/// [intFormat] и [doubleFormat] — шаблоны для чисел. Пакет их не
/// разбирает: шаблон уходит в [LogMainTheme.numberFormatter] темы вместе
/// со значением, и смысл ему придаёт форматтер. Тема без форматтера
/// шаблон игнорирует и печатает число как есть — исключения не будет.
/// Рецепт поверх `package:format`:
/// `numberFormatter: (theme, value, pattern) => format(pattern, value)`,
/// и тогда в конфиге пишут `'{:,d}'`, `'{:.4f}'` и так далее.
```

- [ ] **Step 6: Убрать `format` из зависимостей пакета**

В `pubspec.yaml` удалить из `dependencies` блок с комментарием и строкой
`format: ^4.1.0`, а в `dev_dependencies` добавить:

```yaml
  # Только для тестов: `lib/` не зависит от форматирования чисел (шаблон
  # исполняет форматтер темы, который ставит пользователь). Тесты пинят
  # именно тот рецепт, который документирует README.
  format: ^4.1.0
```

- [ ] **Step 7: Полная проверка и коммит**

Run: `dart pub get && dart analyze && dart test && dart format .`
Expected: analyze чист, все тесты зелёные.

Дополнительно убедиться, что `lib/` больше не знает про пакет:
Run: `grep -rn "package:format" lib/`
Expected: пусто.

```bash
git add lib/src/loggable/loggable.dart lib/src/loggable/loggable_config.dart \
        test/loggable/number_format_test.dart pubspec.yaml
git commit -m "feat!: render numbers through the theme's formatter"
```

---

### Task 3: README и пример

**Files:**
- Modify: `README.md` (раздел «Formatting Settings», блок про числа)
- Modify: `example/pubspec.yaml`
- Modify: `example/lib/readme_examples/default_log.dart`
- Modify: `example/bin/readme_examples/data.dart`
- Modify: `example/bin/example.dart` (тема на строках 7–13, конфиги на
  строках ~251 и ~257)
- Modify: `screenshots/data_6.png` (только если вывод разошёлся)

**Interfaces:**
- Consumes: `LogMainTheme.numberFormatter`, шаблоны в фигурных скобках.

- [ ] **Step 1: Вернуть `format` в пример**

В `example/pubspec.yaml`, в `dependencies`, по алфавиту после
`equatable`:

```yaml
  format: ^4.1.0
```

- [ ] **Step 2: Положить форматтер в тему примеров README**

В `example/lib/readme_examples/default_log.dart` добавить импорт
`package:format/format.dart` и заменить `theme:` у `ConsoleLogPrinter`:

```dart
    theme: LogMainTheme.defaultActiveTheme.copyWith(
      numberFormatter: (theme, value, pattern) => format(pattern, value),
    ),
```

- [ ] **Step 3: Перевести data.dart на шаблоны**

В `example/bin/readme_examples/data.dart` три конфига:

```dart
    config: const LoggableConfig(doubleFormat: '{:.4f}'),
```
```dart
    config: const LoggableConfig(intFormat: '{:,d}'),
```
```dart
    config: const LoggableConfig(intFormat: '{:#x}'),
```

- [ ] **Step 4: Перевести example.dart**

В `example/bin/example.dart` добавить импорт `package:format/format.dart`
и форматтер в обе темы:

```dart
final theme = LogMainTheme.defaultActiveTheme.copyWith(
  numberFormatter: (theme, value, pattern) => format(pattern, value),
);
final inactiveTheme = LogMainTheme.defaultInactiveTheme.copyWith(
  numberFormatter: (theme, value, pattern) => format(pattern, value),
);
```

и два конфига (строки ~251 и ~257):

```dart
    config: const LoggableConfig(doubleFormat: '{:.2f}', units: 'kg'),
```
```dart
    config: const LoggableConfig(intFormat: '{: d}', units: 'items'),
```

- [ ] **Step 5: Прогнать примеры**

Run:
```bash
cd example && dart pub get && dart analyze
for f in bin/readme_examples/*.dart; do dart run "$f" >/dev/null || echo "FAIL $f"; done
dart run bin/example.dart | wc -l
```
Expected: analyze чист, ни одного FAIL. Число строк `example.dart`
изменится — строка 158 печатает саму тему, и в выводе появится
`numberFormatter`. Записать новое число для handoff.

- [ ] **Step 6: Сверить numbers-блок со скриншотом**

Run:
```bash
cd example && dart run bin/readme_examples/data.dart | grep -A2 'Float number'
```
Expected: `1.2346`, `123,456,789`, `0x75bcd15` — как на текущем
`screenshots/data_6.png`. Если совпало, скриншот не трогать. Если нет —
переснять по рецепту из `2026-08-20[2]-int-format-locale-report.md`
(временный `example/bin/_numbers_shot.dart` с логгером с тегом `log`,
`scripts/ansi_screenshot.sh --command …`, убрать `^D` в начале `.ansi`,
затем `--input`).

- [ ] **Step 7: Переписать блок README про числа**

В `README.md`, раздел «Formatting Settings». Заменить абзац «Numbers can
be formatted in the format/sprintf style…» и следующий за ним снипет на:

````markdown
Numbers take a formatting pattern, but the package does not interpret it:
`intFormat`/`doubleFormat` are handed to the theme's `numberFormatter`
along with the value, and a theme without one prints the number as it is.
Install a formatter to make patterns work — for example over the
[format](https://pub.dev/packages/format) package, which then belongs to
your `pubspec.yaml`, not to this one:

```dart
final theme = LogMainTheme.defaultActiveTheme.copyWith(
  numberFormatter: (theme, value, pattern) => format(pattern, value),
);

log.d(
  'Float number with fixed precision',
  data: 1.23456789,
  config: const LoggableConfig(doubleFormat: '{:.4f}'),
);

log.d(
  'Integer number with grouping',
  data: 123456789,
  config: const LoggableConfig(intFormat: '{:,d}'),
);

log.d(
  'Integer number in hexadecimal',
  data: 123456789,
  config: const LoggableConfig(intFormat: '{:#x}'),
);
```
````

Абзац после картинки `screenshots/data_6.png` (тот, что сейчас говорит про
`,n` и C-локаль) заменить на:

```markdown
The pattern means whatever the installed formatter says it means — the one
above is a `format` template, and `(theme, value, pattern) =>
sprintf(pattern, [value])` would make `'%d'` the way to write it instead.
With `format` the locale rules are its own: `,` and `_` group under every
locale, `n` is the locale-aware form, and since it stopped depending on
`intl` it reads no ambient locale — `n` follows the C locale and
`Intl.defaultLocale` changes nothing. `'{:,n}'` throws there, because `n`
takes no grouping option.
```

- [ ] **Step 8: Коммит**

Run: `dart analyze && dart test && dart format .` (в корне) и
`cd example && dart analyze`
Expected: чисто везде.

```bash
git add README.md example/ screenshots/
git commit -m "docs: teach the number pattern through the theme's formatter"
```

---

### Task 4: CHANGELOG, документы, матрица Flutter

**Files:**
- Modify: `CHANGELOG.md`
- Modify: `docs/architecture.md`
- Modify: `docs/handoff.md`
- Modify: `docs/records/2026-08-20[3]-number-formatter-design.md` (шапка)
- Modify: `docs/records/2026-08-20[4]-number-formatter-plan.md` (шапка)
- Create: `docs/records/2026-08-20[5]-number-formatter-report.md`

- [ ] **Step 1: Ломающий пункт в CHANGELOG**

В секцию `## 0.7.0`, рядом с пунктом про `format` 4.1.0:

```markdown
- [breaking changes] `format` is no longer a dependency of this package,
  and number formatting is a theme's job. `intFormat` and `doubleFormat`
  keep their names and their `String?` type, but the package no longer
  reads them: the string goes to `LogMainTheme.numberFormatter` together
  with the value, and what it means is that formatter's business. A theme
  without one prints the number as it is — no exception, and no pattern
  applied. Two changes to make on the way up: install the formatter
  (`numberFormatter: (theme, value, pattern) => format(pattern, value)`,
  with `format` in your own pubspec), and write the whole template where a
  bare specifier used to go — `'{:,d}'` for `',d'`, `'{:.4f}'` for
  `'.4f'`. Nothing else in the package took `format`, so it leaves the
  dependency graph of every application that takes this one; a formatter
  over `sprintf`, or one that has nothing to do with `format`, is now
  equally installable.
```

- [ ] **Step 2: Абзац в architecture.md**

В `docs/architecture.md`, в раздел про `src/theme/` (или рядом с описанием
`LogMainTheme`), добавить:

```markdown
Форматирование чисел — точка расширения темы, а не зависимость пакета.
`LoggableConfig.intFormat`/`doubleFormat` хранят непрозрачный шаблон,
`LogMainTheme.numberFormatter` его исполняет, `LogTheme.formatNumber` —
точка вызова из рендереров. Дефолт шаблон игнорирует и печатает
`value.toString()`, поэтому `lib/` не зависит ни от `package:format`, ни
от какого-либо синтаксиса шаблонов.
```

- [ ] **Step 3: Переснять матрицу Flutter**

Из графа потребителя уходит `format`, значит резолв меняется.

Run: пробное приложение с path-зависимостью, с `flutter_localizations` и
без, на `~/fvm/versions/{3.27.0,3.29.0,3.44.4,stable}/bin/flutter pub get`
(рецепт — в `2026-08-20[1]-logger-builder-0.7.0-report.md`).
Expected: все восемь комбинаций проходят; в lock'е 3.27 + l10n больше нет
`format`.

- [ ] **Step 4: Финальные проверки**

Run:
```bash
dart analyze && dart test && dart format --output=none --set-exit-if-changed .
dart pub publish --dry-run
cd example && dart analyze && dart run bin/example.dart >/dev/null
```
Плюс прогон на настоящем Dart 3.6 копией пакета без `example/` (рецепт —
в `2026-08-20[1]`).
Expected: всё зелёное; dry-run — только предупреждение про
незакоммиченное, если дерево грязное.

- [ ] **Step 5: Отчёт и handoff**

Создать `docs/records/2026-08-20[5]-number-formatter-report.md` по шаблону
`docs/conventions.md`: что сделано, что сломано для пользователя, какие
проверки прошли, новое число строк вывода `example.dart`. Обновить шапки
записей `[3]` и `[4]` на «сделано и смержено». Обновить `docs/handoff.md`:
убрать раздел «В работе прямо сейчас», добавить волну 6 в «Где мы»,
обновить статус проверок и матрицу Flutter.

- [ ] **Step 6: Коммит**

```bash
git add CHANGELOG.md docs/
git commit -m "docs: record the number formatter move"
```
