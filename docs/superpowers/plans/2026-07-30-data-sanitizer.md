# Санитайзация значений data — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Рекурсивный санитайзер значений внутри `data`, применяемый до
публикации лога: маскирование секретов/PII во вложенных структурах и
удаление полей целиком.

**Architecture:** Обход живёт в библиотеке `loggable.dart` (part-файл, ему
нужны приватные `_converters`, `Prop._`, `LoggableData._`) и строит НОВУЮ
структуру. Склейка `sanitizeData(...)` возвращает `LogTransformer<Log>` и
подключается через готовые хуки 0.5.2 (`logger.transformer` /
`TransformPublisher`), откуда fail-closed достаётся бесплатно.

**Tech Stack:** Pure Dart, пакет team_logger
(/Users/user/development/my/team_logger). Релиз 0.6.0. `logger_builder`
не трогаем.

**Спека:** `docs/superpowers/specs/2026-07-30-data-sanitizer-design.md`.
При расхождении плана и спеки — спека главнее.

## Global Constraints

- Строгий анализ: `dart analyze` чист, `dart format --set-exit-if-changed .`
  без изменений. Одинарные кавычки, trailing commas, 80 колонок,
  `omit_local_variable_types`, `cascade_invocations`,
  `require_trailing_commas`, `prefer_const_constructors`.
- TDD: тест → RED → реализация → GREEN → полный `dart test` (228
  существующих тестов должны остаться зелёными) → analyze → format.
- Fail-closed: сырое (несанитайзнутое) значение не должно попадать ни в
  один publisher. Обход обязан покрывать те же типы, что и type-switch
  форматтера, иначе непокрытый тип — дыра.
- Санитайзер вызывается для каждого узла ДО обхода внутрь; результат,
  **не идентичный** входному значению, подставляется как есть и обход
  внутрь не идёт.
- Комментарии в подсистеме `src/loggable/` — на русском (правило
  подкаталога).
- Ожидаемые строки рендеринга в тестах (`'_User(name: "ann")'` и т.п.)
  выверены по документации пакета, но при расхождении с фактическим
  выводом правится ОЖИДАНИЕ, а не проверяемое поведение: утверждения
  «секрета нет в выводе» и «поле исчезло» ослаблять нельзя.
- Коммиты: conventional commits (`feat:`, `test:`, `docs:`) + трейлер
  `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.
- Работать только в /Users/user/development/my/team_logger. Абсолютные
  пути; macOS (нет `timeout`). `pubspec.lock` в .gitignore.
- Публикация пакета — ТОЛЬКО после показа диффа пользователю и явного
  одобрения.

---

### Task 1: Каркас обхода — контекст, drop, примитивы, Map/List/Set

**Files:**
- Create: `lib/src/loggable/log_value_sanitizer.dart`
- Modify: `lib/src/loggable/loggable.dart` (директива `part`, статик
  `Loggable.sanitize`)
- Create: `test/loggable/sanitizer_test.dart`

**Interfaces:**
- Produces:
  `typedef LogValueSanitizer = Object? Function(SanitizeContext ctx);`
  `final class SanitizeContext { String? name; Object? value; int depth; String get path; }`
  `abstract final class Sanitize { static const Object drop; }`
  `static Object? Loggable.sanitize(Object? obj, LogValueSanitizer sanitizer, {String cycleMarker = '<cycle>', int maxIterableCount = 1000})`
  Внутренний класс `_Sanitizer` с полями `_visiting`/`_segments` —
  задачи 2–4 дописывают в него ветки type-switch.

- [ ] **Step 1: Write the failing test**

Создать `test/loggable/sanitizer_test.dart`:

```dart
import 'package:team_logger/team_logger.dart';
import 'package:test/test.dart';

void main() {
  group('Loggable.sanitize', () {
    test('identity sanitizer returns an equal structure', () {
      final result = Loggable.sanitize(
        {'a': 1, 'b': ['x', 'y']},
        (ctx) => ctx.value,
      );

      expect(result, {'a': 1, 'b': ['x', 'y']});
    });

    test('replaces a value by name', () {
      final result = Loggable.sanitize(
        {'password': 'hunter2', 'user': 'ann'},
        (ctx) => ctx.name == 'password' ? '***' : ctx.value,
      );

      expect(result, {'password': '***', 'user': 'ann'});
    });

    test('Sanitize.drop removes a map entry', () {
      final result = Loggable.sanitize(
        {'password': 'hunter2', 'user': 'ann'},
        (ctx) => ctx.name == 'password' ? Sanitize.drop : ctx.value,
      );

      expect(result, {'user': 'ann'});
    });

    test('Sanitize.drop removes a collection element', () {
      final result = Loggable.sanitize(
        ['keep', 'secret', 'keep2'],
        (ctx) => ctx.value == 'secret' ? Sanitize.drop : ctx.value,
      );

      expect(result, ['keep', 'keep2']);
    });

    test('Sanitize.drop at the root is returned as the marker', () {
      final result = Loggable.sanitize(
        {'a': 1},
        (ctx) => ctx.depth == 0 ? Sanitize.drop : ctx.value,
      );

      expect(result, same(Sanitize.drop));
    });

    test('sets are rebuilt as sets', () {
      final result = Loggable.sanitize({1, 2, 3}, (ctx) => ctx.value);

      expect(result, isA<Set<Object?>>());
      expect(result, {1, 2, 3});
    });

    test('replacing a container stops the walk inside it', () {
      final visited = <String?>[];
      final result = Loggable.sanitize(
        {
          'card': {'pan': '4111111111111111', 'cvv': '123'},
        },
        (ctx) {
          visited.add(ctx.name);

          return ctx.name == 'card' ? '<redacted>' : ctx.value;
        },
      );

      expect(result, {'card': '<redacted>'});
      expect(visited, [null, 'card']);
    });

    test('root, name, depth and path describe the position', () {
      final seen = <String, int>{};
      Loggable.sanitize(
        {
          'user': {
            'cards': [
              {'pan': '4111'},
            ],
          },
        },
        (ctx) {
          seen['${ctx.path}|${ctx.name}'] = ctx.depth;

          return ctx.value;
        },
      );

      expect(seen, {
        '|null': 0,
        'user|user': 1,
        'user.cards|cards': 2,
        'user.cards[0]|null': 3,
        'user.cards[0].pan|pan': 4,
      });
    });

    test('primitives are leaves: the sanitizer sees each of them once', () {
      final values = <Object?>[];
      Loggable.sanitize(
        {'i': 1, 'd': 1.5, 's': 'a', 'b': true, 'n': null},
        (ctx) {
          if (ctx.depth > 0) values.add(ctx.value);

          return ctx.value;
        },
      );

      expect(values, [1, 1.5, 'a', true, null]);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/user/development/my/team_logger && dart test test/loggable/sanitizer_test.dart`
Expected: COMPILE ERROR — `Loggable.sanitize`, `Sanitize`,
`SanitizeContext` не существуют.

- [ ] **Step 3: Write minimal implementation**

Создать `lib/src/loggable/log_value_sanitizer.dart`:

```dart
part of 'loggable.dart';

/// Обрабатывает одно значение внутри `data` до публикации лога.
///
/// Возврат значения, идентичного [SanitizeContext.value], означает «не
/// трогал» — обход продолжается внутрь. Любое другое значение
/// подставляется как есть, и внутрь него обход не идёт. Возврат
/// [Sanitize.drop] убирает значение из вывода целиком.
typedef LogValueSanitizer = Object? Function(SanitizeContext ctx);

final class _SanitizeDrop {
  const _SanitizeDrop._();

  @override
  String toString() => '<drop>';
}

/// Маркеры для [LogValueSanitizer].
abstract final class Sanitize {
  /// Убирает значение из вывода целиком: свойство/запись/элемент
  /// исчезают, а не заменяются на заглушку.
  static const Object drop = _SanitizeDrop._();
}

/// Позиция значения при обходе `data`.
///
/// Контекст действителен только во время вызова санитайзера: [path]
/// собирается по текущему состоянию обхода, сохранять объект наружу
/// нельзя.
final class SanitizeContext {
  /// Имя свойства или ключ [Map]; `null` для элементов коллекций и корня.
  final String? name;

  /// Значение, которое реально попадёт в вывод (для свойства с `view` —
  /// сам `view`).
  final Object? value;

  /// Глубина: 0 — корневой объект `data`.
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

final class _Sanitizer {
  final LogValueSanitizer _sanitizer;
  final String _cycleMarker;
  final int _maxIterableCount;

  /// Объекты в текущей цепочке рекурсии — защита от циклов.
  final List<Object> _visiting = [];

  /// Сегменты пути: [String] — имя свойства или ключ, [int] — индекс.
  final List<Object> _segments = [];

  _Sanitizer(this._sanitizer, this._cycleMarker, this._maxIterableCount);

  Object? run(Object? obj) => visit(null, obj, 0);

  Object? visit(String? name, Object? value, int depth) {
    // Обёртка прозрачна: санитайзер должен видеть само значение, иначе
    // Loggable.from(password) прошёл бы мимо правил.
    if (value is LoggableWrapper) {
      final inner = visit(name, value.data, depth);

      return identical(inner, Sanitize.drop)
          ? Sanitize.drop
          : LoggableWrapper(inner, config: value.config);
    }

    final result = _sanitizer(
      SanitizeContext._(name, value, depth, _segments),
    );
    if (!identical(result, value)) return result;

    return _walk(value, depth);
  }

  Object? _child(Object segment, String? name, Object? value, int depth) {
    _segments.add(segment);
    try {
      return visit(name, value, depth);
    } finally {
      _segments.removeLast();
    }
  }

  Object? _walk(Object? value, int depth) {
    if (value == null) return null;
    // Примитивы не содержат ссылок: и лист, и защита от циклов не нужна.
    if (!Loggable._canContainCycle(value)) return value;

    return switch (value) {
      Map<Object?, Object?>() => _walkMap(value, depth),
      List<Object?>() => _walkList(value, depth),
      Set<Object?>() => _walkSet(value, depth),
      _ => value,
    };
  }

  Map<Object?, Object?> _walkMap(Map<Object?, Object?> map, int depth) {
    final result = <Object?, Object?>{};
    for (final entry in map.entries) {
      final name = entry.key?.toString();
      final value = _child(name ?? 'null', name, entry.value, depth + 1);
      if (identical(value, Sanitize.drop)) continue;
      result[entry.key] = value;
    }

    return result;
  }

  List<Object?> _walkList(List<Object?> list, int depth) {
    final result = <Object?>[];
    for (var i = 0; i < list.length; i++) {
      final value = _child(i, null, list[i], depth + 1);
      if (identical(value, Sanitize.drop)) continue;
      result.add(value);
    }

    return result;
  }

  Set<Object?> _walkSet(Set<Object?> set, int depth) {
    final result = <Object?>{};
    var i = 0;
    for (final item in set) {
      final value = _child(i, null, item, depth + 1);
      i++;
      if (identical(value, Sanitize.drop)) continue;
      result.add(value);
    }

    return result;
  }
}
```

В `lib/src/loggable/loggable.dart` добавить директиву part рядом с
существующими (`part 'loggable_data.dart';`):

```dart
part 'log_value_sanitizer.dart';
```

и статический метод в `Loggable` — рядом с `objectToJson`:

```dart
  /// Рекурсивно обходит [obj], предлагая [sanitizer] каждое значение, и
  /// возвращает НОВУЮ структуру с результатами.
  ///
  /// Предназначен для очистки `data` до публикации лога (см.
  /// `sanitizeData`): результат кладётся в лог вместо оригинала, поэтому
  /// сырое значение не достаётся ни одному publisher'у.
  ///
  /// Обратная ссылка на предка заменяется на [cycleMarker]. Ленивые
  /// [Iterable] материализуются не более чем на [maxIterableCount]
  /// элементов.
  static Object? sanitize(
    Object? obj,
    LogValueSanitizer sanitizer, {
    String cycleMarker = '<cycle>',
    int maxIterableCount = 1000,
  }) =>
      _Sanitizer(sanitizer, cycleMarker, maxIterableCount).run(obj);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/user/development/my/team_logger && dart test test/loggable/sanitizer_test.dart && dart test && dart analyze && dart format --set-exit-if-changed .`
Expected: новые тесты PASS, 228 старых зелёные, analyze чист.

- [ ] **Step 5: Commit**

```bash
git -C /Users/user/development/my/team_logger add -A
git -C /Users/user/development/my/team_logger commit -m "feat: data sanitizer core — context, drop marker, collections

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: Свойства и LoggableData — правило view и пересборка

**Files:**
- Modify: `lib/src/loggable/log_value_sanitizer.dart` (ветки `Loggable`,
  `LoggableData`)
- Modify: `lib/src/loggable/loggable_data.dart` (`copyWithProps` в
  `LoggableData`, `_LoggableBuilder`, `_LoggableMapBuilder`)
- Modify: `test/loggable/sanitizer_test.dart`

**Interfaces:**
- Consumes: `_Sanitizer.visit/_child/_walk` (Task 1).
- Produces: `LoggableData.copyWithProps(List<Prop<Object?>> props)` с
  переопределениями в builder-подклассах; ветки `Loggable()` и
  `LoggableData()` в `_walk`.

- [ ] **Step 1: Write the failing test**

Добавить в `test/loggable/sanitizer_test.dart` новую группу (внутри
`main()`, после существующей группы):

```dart
  group('Loggable.sanitize — props', () {
    test('sanitizes props of a Loggable object', () {
      final result = Loggable.sanitize(
        _User('ann', 'hunter2'),
        (ctx) => ctx.name == 'password' ? '***' : ctx.value,
      );

      expect(
        Loggable.objectToString(result),
        '_User(name: "ann", password: "***")',
      );
    });

    test('identity sanitizer renders exactly like the original', () {
      final user = _User('ann', 'hunter2');
      final result = Loggable.sanitize(user, (ctx) => ctx.value);

      expect(Loggable.objectToString(result), Loggable.objectToString(user));
    });

    test('drop removes the prop entirely', () {
      final result = Loggable.sanitize(
        _User('ann', 'hunter2'),
        (ctx) => ctx.name == 'password' ? Sanitize.drop : ctx.value,
      );

      expect(Loggable.objectToString(result), '_User(name: "ann")');
    });

    test('the sanitizer sees the view, not the raw value', () {
      final seen = <Object?>[];
      Loggable.sanitize(
        Loggable.builder(const Object(), name: 'D')
          ..prop('card', 'raw-pan', view: 'view-pan'),
        (ctx) {
          if (ctx.depth > 0) seen.add(ctx.value);

          return ctx.value;
        },
      );

      expect(seen, ['view-pan']);
    });

    test('replacing a prop clears both value and view', () {
      final result = Loggable.sanitize(
        Loggable.builder(const Object(), name: 'D')
          ..prop('card', 'raw-pan', view: 'view-pan'),
        (ctx) => ctx.name == 'card' ? '***' : ctx.value,
      ) as LoggableData;

      final prop = result.props.single;
      expect(prop.value, '***');
      expect(prop.view, isA<LoggableNoView>());
      expect(Loggable.objectToString(result), 'D(card: "***")');
    });

    test('computed props are visible through their view', () {
      final result = Loggable.sanitize(
        Loggable.builder(const Object(), name: 'D')
          ..computed('total', 'secret-total'),
        (ctx) => ctx.name == 'total' ? '***' : ctx.value,
      );

      expect(Loggable.objectToString(result), 'D(total: "***")');
    });

    test('mapBuilder keeps its rendering after sanitizing', () {
      final result = Loggable.sanitize(
        Loggable.mapBuilder()
          ..prop('a', 1, units: 'kg')
          ..prop('password', 'hunter2'),
        (ctx) => ctx.name == 'password' ? Sanitize.drop : ctx.value,
      );

      expect(Loggable.objectToString(result), '{a: 1kg}');
    });

    test('hidden props keep their flag', () {
      final result = Loggable.sanitize(
        Loggable.builder(const Object(), name: 'D')
          ..prop('visible', 1)
          ..hidden('secret', 'x'),
        (ctx) => ctx.value,
      ) as LoggableData;

      expect(result.props.map((p) => p.hidden), [false, true]);
    });
  });
```

и приватный класс-фикстуру в конец файла (вне `main()`):

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

Run: `cd /Users/user/development/my/team_logger && dart test test/loggable/sanitizer_test.dart`
Expected: FAIL — `Loggable`-объект и `LoggableData` сейчас возвращаются
как есть (ветка `_ => value`), санитайзер их свойства не видит.

- [ ] **Step 3: Write minimal implementation**

В `lib/src/loggable/loggable_data.dart` добавить в `LoggableData` (после
конструктора `LoggableData._`):

```dart
  /// Создаёт объект того же вида с другим набором свойств.
  ///
  /// Нужен санитайзеру: пересобрать структуру, не меняя рендеринг —
  /// builder-подклассы переопределяют вывод и должны сохранить свой тип.
  LoggableData copyWithProps(List<Prop<Object?>> props) =>
      LoggableData._(_type)..props.addAll(props);
```

В `_LoggableBuilder` добавить конструктор и переопределение:

```dart
  _LoggableBuilder._withType(TypeProp type, {required this.config})
      : super._(type);

  @override
  LoggableData copyWithProps(List<Prop<Object?>> props) =>
      _LoggableBuilder._withType(_type, config: config)..props.addAll(props);
```

(поле `config` в `_LoggableBuilder` объявлено как `final LoggableConfig
config;` — конструктор `_withType` его инициализирует именованным
параметром; основной конструктор оставить без изменений.)

В `_LoggableMapBuilder` — аналогично:

```dart
  _LoggableMapBuilder._withType(TypeProp type, {required this.config})
      : super._(type);

  @override
  LoggableData copyWithProps(List<Prop<Object?>> props) =>
      _LoggableMapBuilder._withType(_type, config: config)
        ..props.addAll(props);
```

В `lib/src/loggable/log_value_sanitizer.dart` добавить ветки в `_walk`
(перед `_ => value`):

```dart
      Loggable() => _walkData(value.logClassInfo(), depth),
      LoggableData() => _walkData(value, depth),
```

и сам метод в `_Sanitizer`:

```dart
  /// Санитайзеру предлагается то, что реально рендерится: `view`, если он
  /// задан, иначе `value`. Иначе секрет остался бы в `view`, который
  /// побеждает при выводе.
  LoggableData _walkData(LoggableData data, int depth) {
    final props = <Prop<Object?>>[];
    for (final prop in data.props) {
      final rendered = prop.view is LoggableNoView ? prop.value : prop.view;
      final result = _child(prop.name, prop.name, rendered, depth + 1);
      if (identical(result, Sanitize.drop)) continue;

      props.add(
        identical(result, rendered)
            ? prop
            // От оригинала не остаётся ни value, ни view.
            : Prop<Object?>._(
                prop.name,
                result,
                showName: prop.showName,
                hidden: prop.hidden,
                config: prop.config,
              ),
      );
    }

    return data.copyWithProps(props);
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/user/development/my/team_logger && dart test && dart analyze && dart format --set-exit-if-changed .`
Expected: всё PASS, analyze чист.

- [ ] **Step 5: Commit**

```bash
git -C /Users/user/development/my/team_logger add -A
git -C /Users/user/development/my/team_logger commit -m "feat: sanitize Loggable props, closing the view leak

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: Конвертеры типов и LoggableMultiData

**Files:**
- Modify: `lib/src/loggable/log_value_sanitizer.dart`
- Modify: `test/loggable/sanitizer_test.dart`

**Interfaces:**
- Consumes: `_walkData` (Task 2), `Loggable._converters`.
- Produces: ветка конвертеров в `_walk` и ветка `LoggableMultiData()`.

- [ ] **Step 1: Write the failing test**

Добавить группу в `test/loggable/sanitizer_test.dart`:

```dart
  group('Loggable.sanitize — converters and multi-data', () {
    tearDown(Loggable.unregisterTypeConverter<_Card>);

    test('a registered converter is applied before sanitizing', () {
      Loggable.registerTypeConverter<_Card>(_CardConverter());

      final result = Loggable.sanitize(
        _Card('4111111111111111'),
        (ctx) => ctx.name == 'pan' ? '***' : ctx.value,
      );

      expect(Loggable.objectToString(result), 'Card(pan: "***")');
    });

    test('LoggableMultiData values are sanitized, keys kept', () {
      final result = Loggable.sanitize(
        LoggableMultiData({'req': 'ok', 'password': 'hunter2'}),
        (ctx) => ctx.name == 'password' ? '***' : ctx.value,
      );

      expect(Loggable.objectToString(result), 'req: "ok", password: "***"');
    });

    test('LoggableWrapper is transparent for the sanitizer', () {
      final seen = <Object?>[];
      final result = Loggable.sanitize(
        Loggable.from('hunter2', config: const LoggableConfig(units: 'x')),
        (ctx) {
          seen.add(ctx.value);

          return ctx.value == 'hunter2' ? '***' : ctx.value;
        },
      );

      expect(seen, ['hunter2']);
      expect(result, isA<LoggableWrapper>());
      expect((result! as LoggableWrapper).data, '***');
    });
  });
```

и фикстуры в конец файла:

```dart
final class _Card {
  final String pan;

  _Card(this.pan);
}

final class _CardConverter implements LoggableTypeConverter<_Card> {
  @override
  LoggableData convertToData(_Card obj) =>
      Loggable.builder(obj, name: 'Card')..prop('pan', obj.pan);
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/user/development/my/team_logger && dart test test/loggable/sanitizer_test.dart -n 'converters and multi-data'`
Expected: FAIL — конвертер не применяется (объект уходит в `_ => value`),
`LoggableMultiData` не обходится.

- [ ] **Step 3: Write minimal implementation**

В `_Sanitizer._walk` — проверка конвертера ПЕРЕД switch (как в
`_objectToString`), и новая ветка в switch:

```dart
  Object? _walk(Object? value, int depth) {
    if (value == null) return null;
    if (!Loggable._canContainCycle(value)) return value;

    // Конвертер подбирается строго по runtimeType — так же, как в
    // форматтере; иначе поля стороннего типа прошли бы мимо санитайзера.
    final converter = Loggable._converters[value.runtimeType];
    if (converter != null) {
      return _walkData(converter.convertToData(value), depth);
    }

    return switch (value) {
      Map<Object?, Object?>() => _walkMap(value, depth),
      List<Object?>() => _walkList(value, depth),
      Set<Object?>() => _walkSet(value, depth),
      Loggable() => _walkData(value.logClassInfo(), depth),
      LoggableData() => _walkData(value, depth),
      LoggableMultiData() => _walkMultiData(value, depth),
      _ => value,
    };
  }

  LoggableMultiData _walkMultiData(LoggableMultiData data, int depth) {
    final result = <String, Object?>{};
    for (final entry in data.data.entries) {
      final value = _child(entry.key, entry.key, entry.value, depth + 1);
      if (identical(value, Sanitize.drop)) continue;
      result[entry.key] = value;
    }

    return LoggableMultiData(result, config: data.config);
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/user/development/my/team_logger && dart test && dart analyze && dart format --set-exit-if-changed .`
Expected: всё PASS.

- [ ] **Step 5: Commit**

```bash
git -C /Users/user/development/my/team_logger add -A
git -C /Users/user/development/my/team_logger commit -m "feat: sanitize converted types and multi-data

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: Циклы и ленивые Iterable

**Files:**
- Modify: `lib/src/loggable/log_value_sanitizer.dart`
- Modify: `test/loggable/sanitizer_test.dart`

**Interfaces:**
- Consumes: `_visiting` (объявлено в Task 1, до сих пор не использовалось).
- Produces: защита от циклов в `_walk`, ветка `Iterable()` с
  ограничением `_maxIterableCount`.

- [ ] **Step 1: Write the failing test**

Добавить группу:

```dart
  group('Loggable.sanitize — cycles and lazy iterables', () {
    test('a self-reference becomes the cycle marker', () {
      final map = <String, Object?>{'a': 1};
      map['self'] = map;

      final result = Loggable.sanitize(map, (ctx) => ctx.value);

      expect(result, {'a': 1, 'self': '<cycle>'});
    });

    test('mutual references do not hang the walk', () {
      final a = <String, Object?>{};
      final b = <String, Object?>{'a': a};
      a['b'] = b;

      final result = Loggable.sanitize(a, (ctx) => ctx.value);

      expect(result, {
        'b': {'a': '<cycle>'},
      });
    });

    test('the cycle marker is configurable', () {
      final list = <Object?>[];
      list.add(list);

      final result = Loggable.sanitize(
        list,
        (ctx) => ctx.value,
        cycleMarker: '↺',
      );

      expect(result, ['↺']);
    });

    test('a sibling repeated twice is not a cycle', () {
      final shared = {'x': 1};
      final result = Loggable.sanitize(
        {'a': shared, 'b': shared},
        (ctx) => ctx.value,
      );

      expect(result, {
        'a': {'x': 1},
        'b': {'x': 1},
      });
    });

    test('an infinite iterable is truncated instead of hanging', () {
      final result = Loggable.sanitize(
        {'items': Iterable<int>.generate(1 << 30, (i) => i)},
        (ctx) => ctx.value,
        maxIterableCount: 3,
      ) as Map<Object?, Object?>;

      expect(result['items'], [0, 1, 2, '…']);
    });

    test('a short lazy iterable is materialized as is', () {
      final result = Loggable.sanitize(
        {'items': [1, 2, 3].map((e) => e * 2)},
        (ctx) => ctx.value,
      ) as Map<Object?, Object?>;

      expect(result['items'], [2, 4, 6]);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/user/development/my/team_logger && dart test test/loggable/sanitizer_test.dart -n 'cycles and lazy iterables'`
Expected: тесты циклов — зависание или `StackOverflowError`; тесты
ленивых `Iterable` — FAIL (возвращается исходный `Iterable`).

**Внимание:** запускать именно эту группу отдельно; зависший тест
прервать вручную (в macOS нет `timeout`), затем реализовать.

- [ ] **Step 3: Write minimal implementation**

В `_Sanitizer` добавить поиск предка и обёртку обхода (в `_walk`, после
проверки примитивов и ДО поиска конвертера):

```dart
    final ancestor = _visitingIndexOf(value);
    if (ancestor != -1) return _cycleMarker;

    _visiting.add(value);
    try {
      return _walkContainer(value, depth);
    } finally {
      _visiting.removeLast();
    }
```

то есть `_walk` становится обёрткой, а весь конвертер+switch переезжает
в `_walkContainer(Object value, int depth)` (тело — как в Task 3, без
изменений). Плюс метод:

```dart
  int _visitingIndexOf(Object obj) {
    for (var i = 0; i < _visiting.length; i++) {
      if (identical(_visiting[i], obj)) return i;
    }

    return -1;
  }
```

и ветка ленивых коллекций в switch `_walkContainer` — ПОСЛЕ `List`/`Set`
(иначе перехватит их):

```dart
      Iterable<Object?>() => _walkIterable(value, depth),
```

```dart
  /// Ленивые [Iterable] материализуются: после санитайза структура должна
  /// быть готовой, а лимиты форматтера сюда не доходят. Ограничение
  /// [_maxIterableCount] защищает от бесконечных последовательностей.
  List<Object?> _walkIterable(Iterable<Object?> iterable, int depth) {
    final result = <Object?>[];
    var i = 0;
    for (final item in iterable) {
      if (i >= _maxIterableCount) {
        result.add('…');
        break;
      }
      final value = _child(i, null, item, depth + 1);
      i++;
      if (identical(value, Sanitize.drop)) continue;
      result.add(value);
    }

    return result;
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/user/development/my/team_logger && dart test && dart analyze && dart format --set-exit-if-changed .`
Expected: всё PASS без зависаний.

- [ ] **Step 5: Commit**

```bash
git -C /Users/user/development/my/team_logger add -A
git -C /Users/user/development/my/team_logger commit -m "feat: cycle protection and bounded lazy iterables in the sanitizer

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: Склейка sanitizeData и e2e

**Files:**
- Create: `lib/src/logger/sanitize_data.dart`
- Modify: `lib/team_logger.dart` (экспорт)
- Create: `test/logger/sanitize_data_test.dart`

**Interfaces:**
- Consumes: `Loggable.sanitize`, `Sanitize.drop` (Tasks 1–4);
  `Log.copyWith`, `Log.noData`, `Log.hasData` (0.5.2);
  `LogTransformer<Log>` (logger_builder 0.5.0).
- Produces:
  `LogTransformer<Log> sanitizeData(LogValueSanitizer sanitizer, {String cycleMarker = '<cycle>', int maxIterableCount = 1000})`.

- [ ] **Step 1: Write the failing test**

Создать `test/logger/sanitize_data_test.dart`:

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:team_logger/team_logger_io.dart';
import 'package:test/test.dart';

void main() {
  group('sanitizeData', () {
    (Logger, List<String>) setUpPrinter() {
      final lines = <String>[];
      final logger = Logger('app')
        ..level = LogLevels.all
        ..publisher = ConsoleLogPrinter(
          theme: LogMainTheme.noColors,
          rows: const [
            LogRow(maxLength: 200, children: [LogMessage()]),
          ],
          output: lines.add,
        );

      return (logger, lines);
    }

    test('masks a nested value before the printer', () {
      final (logger, lines) = setUpPrinter();
      logger
        ..transformer = sanitizeData(
          (ctx) => ctx.name == 'password' ? '***' : ctx.value,
        )
        ..i('login', data: {
          'user': {'name': 'ann', 'password': 'hunter2'},
        });

      final output = lines.join('\n');
      expect(output, contains('***'));
      expect(output, isNot(contains('hunter2')));
    });

    test('drop removes the field from the output', () {
      final (logger, lines) = setUpPrinter();
      logger
        ..transformer = sanitizeData(
          (ctx) => ctx.name == 'password' ? Sanitize.drop : ctx.value,
        )
        ..i('login', data: {'user': 'ann', 'password': 'hunter2'});

      final output = lines.join('\n');
      expect(output, contains('ann'));
      expect(output, isNot(contains('password')));
      expect(output, isNot(contains('hunter2')));
    });

    test('dropping the root clears the data', () {
      final (logger, lines) = setUpPrinter();
      logger
        ..transformer = sanitizeData((ctx) => Sanitize.drop)
        ..i('login', data: {'password': 'hunter2'});

      final output = lines.join('\n');
      expect(output, contains('login'));
      expect(output, isNot(contains('hunter2')));
    });

    test('logs without data are passed through untouched', () {
      final (logger, lines) = setUpPrinter();
      logger
        ..transformer = sanitizeData((ctx) => Sanitize.drop)
        ..i('plain');

      expect(lines.join('\n'), contains('plain'));
    });

    test('a throwing sanitizer publishes nothing (fail-closed)', () {
      final (logger, lines) = setUpPrinter();
      final errors = <Object>[];
      runZonedGuarded(
        () {
          logger
            ..transformer = sanitizeData((ctx) => throw StateError('bug'))
            ..i('login', data: {'password': 'hunter2'});
        },
        (error, stackTrace) => errors.add(error),
      );

      expect(lines, isEmpty);
      expect(errors.single, isA<StateError>());
    });

    test('the log keeps its number and time', () {
      final logs = <Log>[];
      final logger = Logger('app')
        ..level = LogLevels.all
        ..publisher = CustomLogPublisher(logs.add)
        ..transformer = sanitizeData(
          (ctx) => ctx.name == 'password' ? '***' : ctx.value,
        );

      final before = Log.lastNum;
      logger.i('login', data: {'password': 'hunter2'});

      expect(logs.single.num, before + 1);
      expect(Log.lastNum, before + 1);
    });

    test('masked data reaches FileLogStorage as masked JSONL', () async {
      final tmp = await Directory.systemTemp.createTemp('sanitize_test');
      addTearDown(() => tmp.delete(recursive: true));

      final storage = FileLogStorage(directory: tmp.path);
      final logger = Logger('app')
        ..level = LogLevels.all
        ..publisher = storage
        ..transformer = sanitizeData(
          (ctx) => ctx.name == 'password' ? '***' : ctx.value,
        );

      logger.i('login', data: {'password': 'hunter2'});
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

    test('TransformPublisher sanitizes one destination only', () {
      final console = <Log>[];
      final file = <Log>[];
      final logger = Logger('app')
        ..level = LogLevels.all
        ..publisher = MultiPublisher([
          CustomLogPublisher(console.add),
          TransformPublisher(
            CustomLogPublisher(file.add),
            transformer: sanitizeData(
              (ctx) => ctx.name == 'password' ? '***' : ctx.value,
            ),
          ),
        ]);

      logger.i('login', data: {'password': 'hunter2'});

      expect(Loggable.objectToString(console.single.data), contains('hunter2'));
      expect(Loggable.objectToString(file.single.data), isNot(contains('hunter2')));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/user/development/my/team_logger && dart test test/logger/sanitize_data_test.dart`
Expected: COMPILE ERROR — `sanitizeData` не существует.

- [ ] **Step 3: Write minimal implementation**

Создать `lib/src/logger/sanitize_data.dart`:

```dart
import 'package:logger_builder/logger_builder.dart';

import '../loggable/loggable.dart';
import 'logger.dart';

/// Строит трансформер, очищающий каждое значение внутри `data`.
///
/// Подключается как обычный трансформер — глобально на логгере (правило
/// наследуется сублоггерами) или на одно назначение:
///
/// ```dart
/// log.transformer = sanitizeData(
///   (ctx) => switch (ctx.name) {
///     'password' || 'token' => Sanitize.drop,
///     _ => ctx.value,
///   },
/// );
///
/// log.publisher = MultiPublisher([
///   consolePrinter,
///   TransformPublisher(fileStorage, transformer: sanitizeData(rules)),
/// ]);
/// ```
///
/// Санитайзер получает каждое значение (включая контейнеры) до обхода
/// внутрь; возврат [Sanitize.drop] убирает поле целиком, а в корне —
/// очищает `data`. Логи без данных проходят без изменений; номер и время
/// лога сохраняются ([Log.copyWith]).
///
/// Fail-closed: исключение из санитайзера выходит из трансформера, и лог
/// не публикуется (см. [Logger.transformer] и [TransformPublisher]).
LogTransformer<Log> sanitizeData(
  LogValueSanitizer sanitizer, {
  String cycleMarker = '<cycle>',
  int maxIterableCount = 1000,
}) =>
    (log) {
      if (!log.hasData) return log;

      final sanitized = Loggable.sanitize(
        log.data,
        sanitizer,
        cycleMarker: cycleMarker,
        maxIterableCount: maxIterableCount,
      );
      if (identical(sanitized, log.data)) return log;

      return log.copyWith(
        data: identical(sanitized, Sanitize.drop) ? Log.noData : sanitized,
      );
    };
```

В `lib/team_logger.dart` добавить экспорт в алфавитном порядке (после
`src/logger/logger.dart`):

```dart
export 'src/logger/sanitize_data.dart';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/user/development/my/team_logger && dart test && dart analyze && dart format --set-exit-if-changed .`
Expected: всё PASS. Дополнительно прогнать пример:
`cd /Users/user/development/my/team_logger/example && dart pub get && dart run bin/example.dart`
— вывод не изменился.

- [ ] **Step 5: Commit**

```bash
git -C /Users/user/development/my/team_logger add -A
git -C /Users/user/development/my/team_logger commit -m "feat: sanitizeData transformer for per-value data sanitization

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: Релиз team_logger 0.6.0 — ГЕЙТ: одобрение пользователя

**Files:**
- Modify: `pubspec.yaml`, `CHANGELOG.md`, `README.md`

- [ ] **Step 1: Bump + changelog + README**

`pubspec.yaml`: `version: 0.6.0`. В начало `CHANGELOG.md` (стиль пакета —
`-`-буллеты, `[имена]` в скобках, 80 колонок):

```markdown
## 0.6.0

- Per-value sanitization of `data`: [sanitizeData] builds a
  [LogTransformer] that walks the data structure and offers every value
  to a [LogValueSanitizer] before publishing. The callback receives a
  [SanitizeContext] (name, value, lazily built path such as
  `user.card.number`, depth); returning a different value replaces it and
  stops the walk inside it, returning [Sanitize.drop] removes the field
  from the output entirely. The result replaces `data` in the log, so no
  publisher — including the in-memory [LogStorage] — ever sees the raw
  values.
- Add [Loggable.sanitize] — the same walk as a standalone utility.
  Registered [LoggableTypeConverter]s and [Loggable] objects are expanded
  before sanitizing, a property's `view` is what the sanitizer sees (and
  is replaced together with the value), reference cycles become a
  configurable marker, and lazy iterables are materialized up to
  `maxIterableCount`.
```

README: добавить в секцию «10. Redacting Logs» короткий подраздел про
пер-значение санитайз (после существующего примера с `TransformPublisher`),
в том же тоне и с рабочим кодом:

```markdown
To redact values **inside** `data` — including nested objects — use
`sanitizeData`: it walks the structure and offers every value to your
callback. Returning `Sanitize.drop` removes the field entirely.

```dart
log.transformer = sanitizeData(
  (ctx) => switch (ctx.name) {
    'password' || 'token' => Sanitize.drop,
    'pan' => '**** **** **** ${(ctx.value! as String).substring(12)}',
    _ => ctx.value,
  },
);
```
```

(проверить, что пример компилируется against текущего API; при
необходимости упростить.)

- [ ] **Step 2: Verify**

Run: `cd /Users/user/development/my/team_logger && dart test && dart analyze && dart format --set-exit-if-changed . && dart pub publish --dry-run`
Expected: 0 issues (кроме предупреждения о незакоммиченном состоянии).

- [ ] **Step 3: ГЕЙТ — показать дифф пользователю**

Показать `git -C /Users/user/development/my/team_logger diff v0.5.2..HEAD`
плюс незакоммиченное и ДОЖДАТЬСЯ явного одобрения. Без одобрения к Step 4
не переходить.

- [ ] **Step 4: Commit, publish, tag, push**

```bash
git -C /Users/user/development/my/team_logger add -A
git -C /Users/user/development/my/team_logger commit -m "feat: per-value data sanitization (sanitizeData, Loggable.sanitize)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
cd /Users/user/development/my/team_logger && dart pub publish --force
git -C /Users/user/development/my/team_logger tag v0.6.0
git -C /Users/user/development/my/team_logger push origin main --tags
```

Дождаться доступности на pub.dev (цикл по
`https://pub.dev/api/packages/team_logger`), отчитаться пользователю.
