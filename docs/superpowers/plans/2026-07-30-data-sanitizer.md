# Санитайзация значений data при выводе — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Глобальный санитайзер, который получает каждое выводимое
значение внутри `data` (имя, путь, глубина) и может его заменить или
убрать из вывода.

**Architecture:** Хук встраивается в существующие обходчики
`objectToString`/`objectToJson` — новой структуры не строится, поэтому
лень, защита от циклов и лимиты коллекций работают как раньше.
Санитайзер применяется ровно один раз на значение — тем местом, которое
знает его позицию (свойство, ключ `Map`, индекс элемента, запись
multi-data), плюс точками входа для корня. Регистрация глобальная:
`Loggable.sanitizer`.

**Tech Stack:** Pure Dart, пакет team_logger
(/Users/user/development/my/team_logger). Релиз 0.6.0. `logger_builder`
не трогаем.

**Спека:** `docs/superpowers/specs/2026-07-30-data-sanitizer-design.md`
(редакция v2). При расхождении плана и спеки — спека главнее. Обрати
внимание на раздел «История решения»: вариант с пересборкой структуры
при создании лога рассмотрен и отклонён, возвращаться к нему не надо.

## Global Constraints

- Строгий анализ: `dart analyze` чист, `dart format --set-exit-if-changed .`
  без изменений. Одинарные кавычки, trailing commas, 80 колонок,
  `omit_local_variable_types`, `cascade_invocations`,
  `require_trailing_commas`.
- TDD: тест → RED → реализация → GREEN → полный `dart test` → analyze →
  format.
- **Нулевой оверхед по умолчанию:** при `Loggable.sanitizer == null`
  поведение вывода не меняется ни в одном сценарии. 228 существующих
  тестов — главный страж этого; они должны оставаться зелёными без
  правок. Если существующий тест пришлось поменять — это сигнал ошибки в
  реализации, а не повод править тест.
- Санитайзер вызывается **ровно один раз** на выводимое значение.
  Двойной вызов — дефект: правило вида
  `(ctx) => ctx.name == 'p' ? Sanitize.drop : ctx.value` при повторном
  применении к уже подставленному значению сломается.
- `Loggable.sanitizer` — глобальное изменяемое состояние; каждый тест,
  который его ставит, обязан снимать его в `tearDown`, иначе поедут
  соседние тесты.
- Комментарии в подсистеме `src/loggable/` — на русском.
- Коммиты: conventional commits + трейлер
  `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.
- Работать только в /Users/user/development/my/team_logger. Абсолютные
  пути; macOS (нет `timeout`). `pubspec.lock` в .gitignore.
- Ожидаемые строки рендеринга в тестах выверены по докам пакета; при
  расхождении с фактическим выводом правится ОЖИДАНИЕ, но утверждения
  «секрета нет в выводе» и «ключ исчез» ослаблять нельзя.
- Публикация — ТОЛЬКО после показа диффа пользователю и одобрения.

---

### Task 1: Ядро — типы, глобальный хук, стек пути, корень

**Files:**
- Create: `lib/src/loggable/log_value_sanitizer.dart`
- Modify: `lib/src/loggable/loggable.dart` (директива `part`, поле
  `sanitizer`, применение к корню)
- Create: `test/loggable/sanitizer_test.dart`

**Interfaces:**
- Produces:
  `typedef LogValueSanitizer = Object? Function(SanitizeContext ctx);`
  `final class SanitizeContext { String? name; Object? value; int depth; String get path; }`
  `abstract final class Sanitize { static const Object drop; }`
  `static LogValueSanitizer? Loggable.sanitizer;`
  Пакет-приватные хелперы, которыми пользуются задачи 2–4:
  `static Object? Loggable._sanitizeChild(Object segment, String? name, Object? value)` —
  кладёт сегмент в стек, применяет санитайзер, снимает сегмент;
  возвращает исходное значение, замену или `Sanitize.drop`;
  `static T Loggable._withSegment<T>(Object segment, T Function() render)` —
  выполняет рендеринг ребёнка с сегментом в стеке (чтобы путь у внуков
  был полным);
  `static bool get Loggable._sanitizing` — активен ли санитайзер.

- [ ] **Step 1: Write the failing test**

Создать `test/loggable/sanitizer_test.dart`:

```dart
import 'package:team_logger/team_logger.dart';
import 'package:test/test.dart';

void main() {
  group('Loggable.sanitizer — root', () {
    tearDown(() => Loggable.sanitizer = null);

    test('is not applied when null', () {
      expect(Loggable.objectToString('secret'), '"secret"');
      expect(Loggable.objectToJson('secret'), 'secret');
    });

    test('replaces the root value in both outputs', () {
      Loggable.sanitizer = (ctx) => '***';

      expect(Loggable.objectToString('secret'), '"***"');
      expect(Loggable.objectToJson('secret'), '***');
    });

    test('sees the root as an unnamed value at depth 0', () {
      final seen = <SanitizeContext>[];
      Loggable.sanitizer = (ctx) {
        seen.add(ctx);

        return ctx.value;
      };

      Loggable.objectToString('secret');

      expect(seen.single.name, isNull);
      expect(seen.single.value, 'secret');
      expect(seen.single.depth, 0);
      expect(seen.single.path, isEmpty);
    });

    test('drop at the root renders empty', () {
      Loggable.sanitizer = (ctx) => Sanitize.drop;

      expect(Loggable.objectToString('secret'), isEmpty);
      expect(Loggable.objectToJson('secret'), isNull);
    });

    test('is applied exactly once per rendered value', () {
      var calls = 0;
      Loggable.sanitizer = (ctx) {
        calls++;

        return ctx.value;
      };

      Loggable.objectToString('secret');

      expect(calls, 1);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/user/development/my/team_logger && dart test test/loggable/sanitizer_test.dart`
Expected: COMPILE ERROR — `Loggable.sanitizer`, `Sanitize`,
`SanitizeContext` не существуют.

- [ ] **Step 3: Write minimal implementation**

Создать `lib/src/loggable/log_value_sanitizer.dart`:

```dart
part of 'loggable.dart';

/// Обрабатывает одно выводимое значение внутри `data`.
///
/// Возврат значения, идентичного [SanitizeContext.value], означает «не
/// трогал». Любое другое значение выводится вместо исходного, и внутрь
/// него обход не идёт. Возврат [Sanitize.drop] убирает значение из
/// вывода (см. [Loggable.sanitizer]).
///
/// Правило обязано быть тотальным: исключение из него выходит в
/// publisher (см. спеку, раздел «Ошибки»).
typedef LogValueSanitizer = Object? Function(SanitizeContext ctx);

final class _SanitizeDrop {
  const _SanitizeDrop._();

  @override
  String toString() => '<dropped>';
}

/// Маркеры для [LogValueSanitizer].
abstract final class Sanitize {
  /// Убирает значение из вывода.
  ///
  /// Свойство, запись [Map] или запись `LoggableMultiData` не выводятся
  /// вовсе; в корне вывод пустой. В позиции элемента коллекции
  /// работает как замена на `'<dropped>'`: длина коллекции печатается и
  /// должна остаться честной.
  static const Object drop = _SanitizeDrop._();
}

/// Позиция значения при выводе.
///
/// Контекст действителен только во время вызова санитайзера: [path]
/// собирается по текущему состоянию обхода.
final class SanitizeContext {
  /// Имя свойства, ключ [Map] или записи `LoggableMultiData`; `null`
  /// для элементов коллекций и для корневого значения.
  final String? name;

  /// Значение, которое реально попадёт в вывод (для свойства с `view` —
  /// сам `view`).
  final Object? value;

  /// Глубина: 0 — корневое значение.
  final int depth;

  final List<Object> _segments;

  const SanitizeContext._(this.name, this.value, this.depth, this._segments);

  /// Путь от корня: `user.card.number`, `items[0].pan`.
  ///
  /// Собирается лениво: правило, смотрящее только на [name], не платит
  /// за сборку строки.
  String get path {
    final buf = StringBuffer();
    for (final segment in _segments) {
      if (segment is int) {
        buf.write('[$segment]');
      } else {
        if (buf.isNotEmpty) buf.write('.');
        buf.write(segment);
      }
    }

    return buf.toString();
  }

  @override
  String toString() => 'SanitizeContext($path)';
}
```

В `lib/src/loggable/loggable.dart`:

1. Добавить директиву рядом с `part 'loggable_data.dart';`:

```dart
part 'log_value_sanitizer.dart';
```

2. В классе `Loggable` рядом с `_converters` добавить поле и стек:

```dart
  /// Глобальный санитайзер выводимых значений.
  ///
  /// `null` (по умолчанию) — вывод без обработки и без накладных
  /// расходов. Применяется в [objectToString] и [objectToJson], то есть
  /// ко ВСЕМ выводам: publisher'ам, in-app просмотрщику логов, экспорту
  /// сессий.
  ///
  /// Каждое значение обрабатывается ровно один раз, тем местом, которое
  /// знает его позицию (свойство, ключ [Map], индекс элемента).
  /// Правило получает [SanitizeContext] и возвращает исходное значение,
  /// замену или [Sanitize.drop].
  ///
  /// ```dart
  /// Loggable.sanitizer = (ctx) => switch (ctx.name) {
  ///   'password' || 'token' => Sanitize.drop,
  ///   _ => ctx.value,
  /// };
  /// ```
  static LogValueSanitizer? sanitizer;

  /// Сегменты пути к текущему значению: [String] — имя или ключ,
  /// [int] — индекс. Статический стек, как и [_visiting], чтобы не
  /// менять сигнатуры обходчиков.
  static final List<Object> _sanitizeSegments = <Object>[];

  static bool get _sanitizing => sanitizer != null;

  /// Применяет санитайзер к ребёнку, зная его позицию.
  ///
  /// Возвращает исходное значение (не трогали), замену или
  /// [Sanitize.drop]. Вызывать ровно один раз на значение: обходчики
  /// для не-корневых значений санитайзер не применяют.
  static Object? _sanitizeChild(Object segment, String? name, Object? value) {
    final sanitizer = Loggable.sanitizer;
    if (sanitizer == null) return value;

    _sanitizeSegments.add(segment);
    try {
      return sanitizer(
        SanitizeContext._(
          name,
          value,
          _sanitizeSegments.length,
          _sanitizeSegments,
        ),
      );
    } finally {
      _sanitizeSegments.removeLast();
    }
  }

  /// Рендерит ребёнка, держа его сегмент в стеке пути, — чтобы у
  /// вложенных значений путь был полным.
  static T _withSegment<T>(Object segment, T Function() render) {
    if (!_sanitizing) return render();

    _sanitizeSegments.add(segment);
    try {
      return render();
    } finally {
      _sanitizeSegments.removeLast();
    }
  }
```

3. Применение к корню. В `objectToString` в самое начало:

```dart
    if (_sanitizing && _sanitizeSegments.isEmpty) {
      final sanitized = _sanitizeChild__root(obj);
      if (identical(sanitized, Sanitize.drop)) return '';
      if (!identical(sanitized, obj)) {
        // Замена выводится как обычное значение; повторно санитайзер к
        // ней не применяется — стек уже не пуст только у детей, поэтому
        // защищаемся флагом.
        return _renderRoot(
          () => objectToString(
            sanitized,
            theme: theme,
            depth: depth,
            config: config,
          ),
        );
      }
    }
```

Чтобы не городить два механизма, реализовать это через один приватный
помощник — окончательная форма (заменяет фрагмент выше):

```dart
  /// Санитайз корня: у корня нет ни имени, ни сегмента пути.
  ///
  /// Возвращает [Sanitize.drop], замену или исходный объект. Повторного
  /// применения не происходит: рекурсивный вызов с заменой выполняется
  /// внутри [_withSegment], поэтому стек уже не пуст.
  static Object? _sanitizeRoot(Object? obj) {
    final sanitizer = Loggable.sanitizer;
    if (sanitizer == null) return obj;

    return sanitizer(SanitizeContext._(null, obj, 0, _sanitizeSegments));
  }
```

и в `objectToString`:

```dart
  static String objectToString(
    Object? obj, {
    LogTheme theme = LogTheme.noColors,
    int depth = 0,
    LoggableConfig config = const LoggableConfig(),
  }) {
    if (_sanitizing && _sanitizeSegments.isEmpty) {
      final sanitized = _sanitizeRoot(obj);
      if (identical(sanitized, Sanitize.drop)) return '';
      if (!identical(sanitized, obj)) {
        // Сегмент-заглушка держит стек непустым: к замене санитайзер
        // повторно не применится.
        return _withSegment(
          '',
          () => objectToString(
            sanitized,
            theme: theme,
            depth: depth,
            config: config,
          ),
        );
      }
    }

    // ...существующее тело без изменений
```

Аналогично в `objectToJson` (drop → `null`, замена → рекурсивный вызов
внутри `_withSegment('')`).

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/user/development/my/team_logger && dart test && dart analyze && dart format --set-exit-if-changed .`
Expected: новые тесты PASS, все 228 существующих зелёные без правок.

- [ ] **Step 5: Commit**

```bash
git -C /Users/user/development/my/team_logger add -A
git -C /Users/user/development/my/team_logger commit -m "feat: global value sanitizer — types, hook and root handling

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: Map и LoggableMultiData

**Files:**
- Modify: `lib/src/loggable/loggable.dart` (`_mapEntryToString`,
  `_mapToString`, `_mapToJson`, ветки `LoggableMultiData` в
  `_objectToString`/`_objectToJson`)
- Modify: `test/loggable/sanitizer_test.dart`

**Interfaces:**
- Consumes: `_sanitizeChild`, `_withSegment`, `_sanitizing` (Task 1).
- Produces: санитайз записей `Map` и `LoggableMultiData` в обоих
  выводах, включая пропуск записи по `Sanitize.drop`.

- [ ] **Step 1: Write the failing test**

Добавить группу в `test/loggable/sanitizer_test.dart`:

```dart
  group('Loggable.sanitizer — maps', () {
    tearDown(() => Loggable.sanitizer = null);

    test('replaces a value by key in both outputs', () {
      Loggable.sanitizer =
          (ctx) => ctx.name == 'password' ? '***' : ctx.value;

      const data = {'user': 'ann', 'password': 'hunter2'};
      expect(Loggable.objectToString(data), '{user: "ann", password: "***"}');
      expect(Loggable.objectToJson(data), {'user': 'ann', 'password': '***'});
    });

    test('drop removes the entry with its separator', () {
      Loggable.sanitizer =
          (ctx) => ctx.name == 'password' ? Sanitize.drop : ctx.value;

      const data = {'a': 1, 'password': 'hunter2', 'c': 3};
      expect(Loggable.objectToString(data), '{a: 1, c: 3}');
      expect(Loggable.objectToJson(data), {'a': 1, 'c': 3});
    });

    test('reports name, depth and path for nested maps', () {
      final seen = <String, int>{};
      Loggable.sanitizer = (ctx) {
        seen['${ctx.path}|${ctx.name}'] = ctx.depth;

        return ctx.value;
      };

      Loggable.objectToString({
        'user': {'card': {'pan': '4111'}},
      });

      expect(seen, {
        '|null': 0,
        'user|user': 1,
        'user.card|card': 2,
        'user.card.pan|pan': 3,
      });
    });

    test('replacing a map stops the walk inside it', () {
      final names = <String?>[];
      Loggable.sanitizer = (ctx) {
        names.add(ctx.name);

        return ctx.name == 'card' ? '<redacted>' : ctx.value;
      };

      expect(
        Loggable.objectToString({
          'card': {'pan': '4111', 'cvv': '123'},
        }),
        '{card: "<redacted>"}',
      );
      expect(names, [null, 'card']);
    });

    test('LoggableMultiData entries are sanitized by key', () {
      Loggable.sanitizer =
          (ctx) => ctx.name == 'password' ? Sanitize.drop : ctx.value;

      final data = LoggableMultiData({'req': 'ok', 'password': 'hunter2'});
      expect(Loggable.objectToString(data), 'req: "ok"');
      expect(Loggable.objectToJson(data), {':k': 'multi', 'req': 'ok'});
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/user/development/my/team_logger && dart test test/loggable/sanitizer_test.dart -n maps`
Expected: FAIL — значения внутри `Map` санитайзер не видит (корень уже
обработан, дети — нет).

- [ ] **Step 3: Write minimal implementation**

`_mapEntryToString` — санитайз значения записи; при `drop` вернуть
`null`, чтобы `_mapToString` пропустил запись:

```dart
  static String? _mapEntryToString(
    MapEntry<Object?, Object?> entry, {
    LogTheme theme = LogTheme.noColors,
    int depth = 0,
    LoggableConfig config = const LoggableConfig(),
  }) {
    final name = entry.key?.toString();
    final segment = name ?? 'null';
    final value = Loggable._sanitizeChild(segment, name, entry.value);
    if (identical(value, Sanitize.drop)) return null;

    String obj2str(Object? obj) => Loggable._withSegment(
          segment,
          () => objectToString(
            obj,
            depth: depth + 1,
            theme: theme,
            config: config,
          ),
        );

    final depthTheme = theme.depthTheme(depth);

    final key = switch (entry.key) {
      final String key => theme.formatValue(key),
      final key => obj2str(key),
    };

    return '${theme.data.keyStyle(key)}${depthTheme.punctuation(':')}'
        ' ${theme.data.valueStyle(obj2str(value))}';
  }
```

`_mapToString` — отфильтровать `null`:

```dart
    final body = map.entries
        .map(
          (e) => _mapEntryToString(
            e,
            theme: theme,
            depth: depth,
            config: config,
          ),
        )
        .whereType<String>()
        .join(depthTheme.punctuation(', '));
```

`_mapToJson` — то же для JSON (вместо `map.map` собрать вручную, чтобы
уметь пропускать записи):

```dart
    final result = <String, Object?>{};
    for (final entry in map.entries) {
      final name = entry.key?.toString();
      final segment = name ?? 'null';
      final value = Loggable._sanitizeChild(segment, name, entry.value);
      if (identical(value, Sanitize.drop)) continue;

      final key = _escapeServiceKey(
        switch (entry.key) {
          String() => entry.key! as String,
          _ => entry.key.toString(),
        },
      );
      result[key] = _withSegment(
        segment,
        () => objectToJson(value, config: itemConfig),
      );
    }
```

Ветка `LoggableMultiData` в `_objectToString` — санитайз значения записи
по ключу, пропуск при `drop`:

```dart
      LoggableMultiData() => obj.data.entries
          .map((e) {
            final sanitized = Loggable._sanitizeChild(e.key, e.key, e.value);
            if (identical(sanitized, Sanitize.drop)) return null;

            final value = Loggable._withSegment(
              e.key,
              () => Loggable.objectToString(
                sanitized,
                theme: theme,
                depth: depth,
                config: obj.config.merge(config),
              ),
            );

            return switch (e.key) {
              '' => value,
              final key =>
                '${theme.data.sectionStyle(key)}${theme.styledColon} $value',
            };
          })
          .whereType<String>()
          .join(depthTheme.punctuation(', ')),
```

и симметрично в `_objectToJson` (собрать `Map` циклом, пропуская `drop`).

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/user/development/my/team_logger && dart test && dart analyze && dart format --set-exit-if-changed .`
Expected: всё PASS, существующие тесты не правились.

- [ ] **Step 5: Commit**

```bash
git -C /Users/user/development/my/team_logger add -A
git -C /Users/user/development/my/team_logger commit -m "feat: sanitize map and multi-data entries

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: Элементы коллекций

**Files:**
- Modify: `lib/src/loggable/loggable.dart` (замыкания `obj2str`/`obj2json`
  в `_addEfficientLengthIterableItemsToBuf`, `_addAllIterableItemsToBuf`,
  `_addIterableItemsToBuf`, `_efficientLengthIterableToJson`,
  `iterableToJson`)
- Modify: `test/loggable/sanitizer_test.dart`

**Interfaces:**
- Consumes: `_sanitizeChild`, `_withSegment` (Task 1).
- Produces: санитайз элементов с индексом в пути; `Sanitize.drop` в этой
  позиции = замена на `'<dropped>'` (длина коллекции остаётся честной).

- [ ] **Step 1: Write the failing test**

```dart
  group('Loggable.sanitizer — collections', () {
    tearDown(() => Loggable.sanitizer = null);

    test('elements are unnamed and indexed in the path', () {
      final paths = <String>[];
      Loggable.sanitizer = (ctx) {
        paths.add('${ctx.path}|${ctx.name}');

        return ctx.value;
      };

      Loggable.objectToString({
        'items': [
          {'pan': '4111'},
        ],
      });

      expect(paths, [
        '|null',
        'items|items',
        'items[0]|null',
        'items[0].pan|pan',
      ]);
    });

    test('replaces an element value', () {
      Loggable.sanitizer = (ctx) => ctx.value == 'secret' ? '***' : ctx.value;

      expect(
        Loggable.objectToString(['a', 'secret']),
        contains('"***"'),
      );
      expect(
        Loggable.objectToString(['a', 'secret']),
        isNot(contains('secret')),
      );
    });

    test('drop in an element position becomes a marker, length is kept', () {
      Loggable.sanitizer =
          (ctx) => ctx.value == 'secret' ? Sanitize.drop : ctx.value;

      final out = Loggable.objectToString(['a', 'secret', 'c']);
      expect(out, contains('<dropped>'));
      expect(out, isNot(contains('secret')));
      expect(Loggable.objectToJson(['a', 'secret', 'c']), isNotNull);
    });

    test('json output sanitizes elements too', () {
      Loggable.sanitizer = (ctx) => ctx.value == 'secret' ? '***' : ctx.value;

      expect(Loggable.objectToJson(['a', 'secret']).toString(),
          isNot(contains('secret')));
    });

    test('collection limits still apply with a sanitizer', () {
      var calls = 0;
      Loggable.sanitizer = (ctx) {
        calls++;

        return ctx.value;
      };

      Loggable.objectToString(
        List<int>.generate(100, (i) => i),
        config: const LoggableConfig(collectionMaxCount: 3),
      );

      // Санитайзер не вызывается для того, что лимит не вывел:
      // корень + не больше выведенных элементов.
      expect(calls, lessThan(10));
    });

    test('an infinite iterable still does not hang', () {
      Loggable.sanitizer = (ctx) => ctx.value;

      final out = Loggable.objectToString(
        Iterable<int>.generate(1 << 30, (i) => i),
        config: const LoggableConfig(collectionMaxCount: 3),
      );

      expect(out, isNotEmpty);
    });

    test('cycles still render as a cycle marker', () {
      Loggable.sanitizer = (ctx) => ctx.value;

      final list = <Object?>[];
      list.add(list);

      expect(Loggable.objectToString(list), isNotEmpty);
      expect(Loggable.objectToJson(list).toString(), contains('cycle'));
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/user/development/my/team_logger && dart test test/loggable/sanitizer_test.dart -n collections`
Expected: FAIL — элементы коллекций санитайзер не видит (пути `items[0]`
не появляются).

- [ ] **Step 3: Write minimal implementation**

В каждом из пяти мест заменить замыкание рендеринга элемента на вариант
с индексом. Общий шаблон для строкового вывода (`obj2str` вызывается там,
где индекс уже известен — в `indexedObj2str` и в циклах):

```dart
    String obj2str(int index, Object? obj) {
      final value = Loggable._sanitizeChild(index, null, obj);

      return Loggable._withSegment(
        index,
        () => objectToString(
          identical(value, Sanitize.drop) ? '<dropped>' : value,
          theme: theme,
          depth: depth + 1,
          config: config,
        ),
      );
    }
```

Так как существующие замыкания принимают только `obj`, в каждом месте
нужно протащить индекс:

- `_addEfficientLengthIterableItemsToBuf` — индекс уже есть
  (`indexedObj2str(index, obj)`), передать его в `obj2str`.
- `_addAllIterableItemsToBuf` и `_addIterableItemsToBuf` — итерируются с
  счётчиком для `index2str`; использовать тот же счётчик.
- `_efficientLengthIterableToJson` и `iterableToJson` — заменить
  `values.map(obj2json)` на индексированный обход:

```dart
    final items = <Object?>[];
    var index = 0;
    for (final item in values) {
      final value = _sanitizeChild(index, null, item);
      items.add(
        _withSegment(
          index,
          () => objectToJson(
            identical(value, Sanitize.drop) ? '<dropped>' : value,
            config: itemConfig,
          ),
        ),
      );
      index++;
    }
```

**Важно:** индексы должны соответствовать позиции в исходной коллекции
(в путях вида `items[4]`), а не порядковому номеру среди выведенных, —
иначе после усечения путь врёт. Там, где вывод пропускает «хвост» через
многоточие, индекс берётся из существующей логики нумерации.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/user/development/my/team_logger && dart test && dart analyze && dart format --set-exit-if-changed .`
Expected: всё PASS; существующие тесты коллекций (включая лимиты,
усечение и циклы) не правились.

- [ ] **Step 5: Commit**

```bash
git -C /Users/user/development/my/team_logger add -A
git -C /Users/user/development/my/team_logger commit -m "feat: sanitize collection elements with indexed paths

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: Свойства и правило view

**Files:**
- Modify: `lib/src/loggable/loggable_data.dart` (`Prop.toLogString`,
  `Prop.toMapEntry`, фильтрация свойств в `LoggableData.toLogString`,
  `LoggableData.toJson`, `_LoggableMapBuilder`)
- Modify: `test/loggable/sanitizer_test.dart`

**Interfaces:**
- Consumes: `_sanitizeChild`, `_withSegment` (Task 1).
- Produces: санитайз свойств `Loggable`-объектов и builder'ов; замена
  отменяет логику `view`; `Sanitize.drop` убирает свойство из вывода.

- [ ] **Step 1: Write the failing test**

```dart
  group('Loggable.sanitizer — props', () {
    tearDown(() => Loggable.sanitizer = null);

    test('sanitizes props of a Loggable object in both outputs', () {
      Loggable.sanitizer =
          (ctx) => ctx.name == 'password' ? '***' : ctx.value;

      final user = _User('ann', 'hunter2');
      expect(Loggable.objectToString(user), contains('"***"'));
      expect(Loggable.objectToString(user), isNot(contains('hunter2')));
      expect(Loggable.objectToJson(user).toString(),
          isNot(contains('hunter2')));
    });

    test('drop removes the prop entirely', () {
      Loggable.sanitizer =
          (ctx) => ctx.name == 'password' ? Sanitize.drop : ctx.value;

      final out = Loggable.objectToString(_User('ann', 'hunter2'));
      expect(out, contains('ann'));
      expect(out, isNot(contains('password')));
    });

    test('the sanitizer sees the view, not the raw value', () {
      final seen = <Object?>[];
      Loggable.sanitizer = (ctx) {
        if (ctx.depth > 0) seen.add(ctx.value);

        return ctx.value;
      };

      Loggable.objectToString(
        Loggable.builder(const Object(), name: 'D')
          ..prop('card', 'raw-pan', view: 'view-pan'),
      );

      expect(seen, ['view-pan']);
    });

    test('replacing a prop with a view leaks neither value nor view', () {
      Loggable.sanitizer = (ctx) => ctx.name == 'card' ? '***' : ctx.value;

      final data = Loggable.builder(const Object(), name: 'D')
        ..prop('card', 'raw-pan', view: 'view-pan');

      final out = Loggable.objectToString(data);
      expect(out, contains('***'));
      expect(out, isNot(contains('raw-pan')));
      expect(out, isNot(contains('view-pan')));
      expect(Loggable.objectToJson(data).toString(),
          isNot(contains('raw-pan')));
    });

    test('computed props are visible through their view', () {
      Loggable.sanitizer = (ctx) => ctx.name == 'total' ? '***' : ctx.value;

      final out = Loggable.objectToString(
        Loggable.builder(const Object(), name: 'D')
          ..computed('total', 'secret-total'),
      );

      expect(out, contains('***'));
      expect(out, isNot(contains('secret-total')));
    });

    test('LoggableView is replaced as a whole', () {
      Loggable.sanitizer = (ctx) => ctx.name == 'x' ? '***' : ctx.value;

      final out = Loggable.objectToString(
        Loggable.builder(const Object(), name: 'D')
          ..prop('x', 1, view: const LoggableView(42, units: 'kg')),
      );

      expect(out, contains('***'));
      expect(out, isNot(contains('42')));
    });

    test('mapBuilder props are sanitized too', () {
      Loggable.sanitizer =
          (ctx) => ctx.name == 'password' ? Sanitize.drop : ctx.value;

      final out = Loggable.objectToString(
        Loggable.mapBuilder()
          ..prop('a', 1, units: 'kg')
          ..prop('password', 'hunter2'),
      );

      expect(out, '{a: 1kg}');
    });

    test('LoggableWrapper is transparent', () {
      final seen = <Object?>[];
      Loggable.sanitizer = (ctx) {
        seen.add(ctx.value);

        return ctx.value;
      };

      Loggable.objectToString(
        Loggable.from('hunter2', config: const LoggableConfig()),
      );

      expect(seen, ['hunter2']);
    });
  });
```

и фикстуру в конец файла:

```dart
final class _User with Loggable {
  final String name;
  final String password;

  _User(this.name, this.password);

  @override
  void collectLoggableData(LoggableData data) {
    data
      ..prop('name', name)
      ..prop('password', password);
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/user/development/my/team_logger && dart test test/loggable/sanitizer_test.dart -n props`
Expected: FAIL — свойства санитайзер не видит; тесты про `view` падают
особенно наглядно (`view` рендерится мимо обходчиков).

- [ ] **Step 3: Write minimal implementation**

В `Prop` добавить пакет-приватный метод, дающий санитайзнутое значение
(единая точка для обоих выводов):

```dart
  /// Значение, которое реально рендерится: `view`, если он задан, иначе
  /// `value`. Санитайзер видит именно его — иначе секрет во `view`
  /// прошёл бы мимо: ни одна реализация [LoggableView] не проходит через
  /// [Loggable.objectToString].
  Object? get _renderedValue =>
      view is LoggableNoView ? value : view;

  /// Результат санитайза: исходное `_renderedValue`, замена или
  /// [Sanitize.drop].
  Object? _sanitized() => Loggable._sanitizeChild(name, name, _renderedValue);
```

`Prop.toLogString` — ветка замены обходит логику `view`:

```dart
  String toLogString({
    LogTheme theme = LogTheme.noColors,
    int depth = 0,
    LoggableConfig config = const LoggableConfig(),
    Object? sanitized,
  }) {
    String name2str() => theme.data.keyStyle(theme.formatValue(name));

    final effectiveConfig = this.config.merge(config);
    final depthTheme = theme.depthTheme(depth);
    final prefix =
        showName ? '${name2str()}${depthTheme.punctuation(':')} ' : '';

    // Замена рендерится как обычное значение: units и LoggableView
    // рассчитаны на оригинал и к подставленному значению не применяются.
    if (sanitized != null && !identical(sanitized, _renderedValue)) {
      return '$prefix'
          '${theme.formatValue(Loggable._withSegment(
        name,
        () => Loggable.objectToString(
          sanitized,
          theme: theme,
          depth: depth + 1,
          config: effectiveConfig,
        ),
      ))}';
    }

    // ...существующее тело (view/value), обёрнутое в _withSegment(name, ...)
    // для вложенных путей
  }
```

`Prop.toMapEntry` — симметрично.

Фильтрация и передача результата санитайза — в
`LoggableData.toLogString`/`toJson` и в `_LoggableMapBuilder`
(там, где сейчас `props.where((p) => !p.hidden)`):

```dart
    String? prop2str(Prop<Object?> p) {
      final sanitized = p._sanitized();
      if (identical(sanitized, Sanitize.drop)) return null;

      return p.toLogString(
        theme: theme,
        depth: depth,
        config: config,
        sanitized: sanitized,
      );
    }

    buf.write(
      props
          .where((p) => !p.hidden)
          .map(prop2str)
          .whereType<String>()
          .join(depthTheme.punctuation(', ')),
    );
```

Аналогично в JSON-ветках (`prop2entry`/`prop2json`): при `drop` запись
не добавляется.

**Важно:** `_sanitized()` вызывается ровно один раз на свойство, а
результат передаётся в `toLogString`/`toMapEntry` параметром — иначе
санитайзер сработает дважды.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/user/development/my/team_logger && dart test && dart analyze && dart format --set-exit-if-changed .`
Expected: всё PASS; существующие тесты `loggable`/`printer` не правились.

- [ ] **Step 5: Commit**

```bash
git -C /Users/user/development/my/team_logger add -A
git -C /Users/user/development/my/team_logger commit -m "feat: sanitize props, closing the view bypass

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: e2e через publisher'ы

**Files:**
- Create: `test/logger/sanitizer_e2e_test.dart`

**Interfaces:**
- Consumes: всё из задач 1–4 через публичный API team_logger.

- [ ] **Step 1: Write the failing test**

Создать `test/logger/sanitizer_e2e_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:team_logger/team_logger_io.dart';
import 'package:test/test.dart';

void main() {
  group('sanitizer e2e', () {
    tearDown(() => Loggable.sanitizer = null);

    test('the secret never reaches the console printer', () {
      Loggable.sanitizer =
          (ctx) => ctx.name == 'password' ? Sanitize.drop : ctx.value;

      final lines = <String>[];
      Logger('app')
        ..level = LogLevels.all
        ..publisher = ConsoleLogPrinter(
          theme: LogMainTheme.noColors,
          rows: const [
            LogRow(maxLength: 200, children: [LogMessage()]),
          ],
          output: lines.add,
        )
        ..i('login', data: {
          'user': {'name': 'ann', 'password': 'hunter2'},
        });

      final out = lines.join('\n');
      expect(out, contains('ann'));
      expect(out, isNot(contains('hunter2')));
      expect(out, isNot(contains('password')));
    });

    test('the secret never reaches the JSONL file', () async {
      Loggable.sanitizer =
          (ctx) => ctx.name == 'password' ? '***' : ctx.value;

      final tmp = await Directory.systemTemp.createTemp('sanitizer_e2e');
      addTearDown(() => tmp.delete(recursive: true));

      final storage = FileLogStorage(directory: tmp.path);
      Logger('app')
        ..level = LogLevels.all
        ..publisher = storage
        ..i('login', data: {'password': 'hunter2'});

      await storage.flush();
      await storage.close();

      final content = Directory(tmp.path)
          .listSync()
          .whereType<File>()
          .map((f) => utf8.decode(f.readAsBytesSync()))
          .join('\n');
      expect(content, contains('***'));
      expect(content, isNot(contains('hunter2')));
    });

    test('an in-app viewer rendering log.data is sanitized too', () {
      Loggable.sanitizer =
          (ctx) => ctx.name == 'password' ? '***' : ctx.value;

      final storage = LogStorage();
      Logger('app')
        ..level = LogLevels.all
        ..publisher = storage
        ..i('login', data: {'password': 'hunter2'});

      final rendered = Loggable.objectToString(storage.logs.single.data);
      expect(rendered, contains('***'));
      expect(rendered, isNot(contains('hunter2')));
    });

    test('without a sanitizer the output is unchanged', () {
      final lines = <String>[];
      Logger('app')
        ..level = LogLevels.all
        ..publisher = ConsoleLogPrinter(
          theme: LogMainTheme.noColors,
          rows: const [
            LogRow(maxLength: 200, children: [LogMessage()]),
          ],
          output: lines.add,
        )
        ..i('login', data: {'password': 'hunter2'});

      expect(lines.join('\n'), contains('hunter2'));
    });
  });
}
```

(проверить фактическое имя конструктора и геттера у `LogStorage` —
`storage.logs` может называться иначе; поправить обращение, не ослабляя
утверждения.)

- [ ] **Step 2: Run test to verify it fails or passes**

Run: `cd /Users/user/development/my/team_logger && dart test test/logger/sanitizer_e2e_test.dart`
Expected: PASS, если задачи 1–4 сделаны верно. Любой красный тест здесь —
дырка в покрытии, а не повод править тест.

- [ ] **Step 3: Прогнать пример**

Run: `cd /Users/user/development/my/team_logger/example && dart pub get && dart run bin/example.dart`
Expected: вывод не изменился (санитайзер не задан).

- [ ] **Step 4: Commit**

```bash
git -C /Users/user/development/my/team_logger add -A
git -C /Users/user/development/my/team_logger commit -m "test: e2e coverage for the value sanitizer

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: Релиз team_logger 0.6.0 — ГЕЙТ: одобрение пользователя

**Files:**
- Modify: `pubspec.yaml`, `CHANGELOG.md`, `README.md`

- [ ] **Step 1: Bump + changelog + README**

`pubspec.yaml`: `version: 0.6.0`. В начало `CHANGELOG.md`:

```markdown
## 0.6.0

- Per-value sanitization of logged data: assign [Loggable.sanitizer] to
  process every value on its way to the output. The callback receives a
  [SanitizeContext] (name, value, lazily built path such as
  `user.card.number`, depth) and returns the value unchanged, a
  replacement (the walk does not descend into it), or [Sanitize.drop] to
  remove the property/entry from the output entirely. The hook is global,
  so it cannot be forgotten on a publisher: it applies to the console
  printer, the file storage, session export and any direct
  [Loggable.objectToString]/[objectToJson] call — including an in-app log
  viewer.
- A property's `view` is what the sanitizer sees (no [LoggableView] goes
  through the walkers, so a `view` would otherwise bypass the rules); a
  replacement is rendered as a plain value, without the `view`/`units`
  logic. In a collection-element position [Sanitize.drop] renders
  `'<dropped>'` — the printed collection length stays honest.
- Cycle protection, collection limits and lazy iterables are unaffected:
  sanitization happens while rendering, so filtered-out logs still cost
  nothing.
```

README: в секцию «10. Redacting Logs» добавить подраздел про
пер-значение санитайз с рабочим примером:

```markdown
`Logger.transformer` replaces the log as a whole. To redact values
**inside** `data` — including nested objects — register a global
sanitizer: it is called for every value on its way to the output, so no
publisher can miss it.

```dart
Loggable.sanitizer = (ctx) => switch (ctx.name) {
  'password' || 'token' => Sanitize.drop,   // the field disappears
  'email' => maskEmail(ctx.value),
  _ => ctx.value,
};
```

`ctx` also carries `path` (`user.cards[0].pan`) and `depth`. Note that
sanitizing happens while rendering: the raw value stays in `Log.data`, so
use `Logger.transformer` when it must not exist in memory at all.
```

- [ ] **Step 2: Verify**

Run: `cd /Users/user/development/my/team_logger && dart test && dart analyze && dart format --set-exit-if-changed . && dart pub publish --dry-run`
Expected: 0 issues (кроме предупреждения о незакоммиченном состоянии).

- [ ] **Step 3: ГЕЙТ — показать дифф пользователю**

Показать `git -C /Users/user/development/my/team_logger diff v0.5.2..HEAD`
плюс незакоммиченное и ДОЖДАТЬСЯ явного одобрения.

- [ ] **Step 4: Commit, publish, tag, push**

```bash
git -C /Users/user/development/my/team_logger add -A
git -C /Users/user/development/my/team_logger commit -m "feat: per-value data sanitization (Loggable.sanitizer)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
cd /Users/user/development/my/team_logger && dart pub publish --force
git -C /Users/user/development/my/team_logger tag v0.6.0
git -C /Users/user/development/my/team_logger push origin main --tags
```

Дождаться доступности на pub.dev, отчитаться пользователю.
