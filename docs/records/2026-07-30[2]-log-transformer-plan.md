> **Состояние на 2026-08-17:** выполнен полностью, релиз 0.5.2.
> **Что это:** пошаговый план реализации `Logger.transformer`.
> **Связанные записи:** `2026-07-30[1]-log-transformer-design.md`.

# LogTransformer (обработка лога до публикации) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Хук обработки лога между созданием и публикацией (маскирование
секретов/PII, drop) на двух уровнях: `logger.transformer` и
`TransformPublisher`.

**Architecture:** Оба примитива — в `logger_builder` (typedef
`LogTransformer`, `CustomLogger.transformer` с наследованием сублоггерами,
`CustomLevelLogger.publishLog`, `TransformPublisher`, защищённый
`CustomLog.copy`); `team_logger` переводит `processLog` на `publishLog` и
добавляет `Log.copyWith`. Fail-closed: исключение из transformer'а ⇒ лог
не публикуется, ошибка — в `onError`/Zone.

**Tech Stack:** Pure Dart. Репозитории: `/Users/user/development/my/logger_builder`
(релиз 0.5.0) и `/Users/user/development/my/team_logger` (релиз 0.5.2).

**Спека:** `docs/records/2026-07-30[1]-log-transformer-design.md`
(в репо team_logger). При расхождении плана и спеки — спека главнее.

## Global Constraints

- Оба пакета — строгий analyze (`strict-casts`/`strict-inference`/
  `strict-raw-types` + ручной набор линтов): `prefer_single_quotes`,
  `require_trailing_commas`, `omit_local_variable_types`,
  `cascade_invocations`, 80 колонок. После каждой задачи: `dart analyze`
  чист, `dart format --set-exit-if-changed .` без изменений.
- Fail-closed везде: сырой (нетрансформированный) лог НЕ должен попадать
  в publisher ни при `null`, ни при исключении из transformer'а.
- `copyWith`/`CustomLog.copy` НЕ потребляют номер (`Log.lastNum`) и НЕ
  берут новое время.
- Коммиты logger_builder — короткие простые сообщения; team_logger —
  conventional commits (`feat:`, `docs:`, ...). Оба — с трейлером
  `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.
- Публикация пакета — ТОЛЬКО после показа диффа пользователю и его
  явного одобрения.
- macOS: команды `timeout` нет; пути абсолютные, `git -C <repo>`.

---

### Task 1: `CustomLog.copy` (logger_builder)

**Files:**
- Modify: `/Users/user/development/my/logger_builder/lib/src/custom_logger/custom_log.dart`
- Modify: `/Users/user/development/my/logger_builder/test/utils/hierarchical_logger.dart`
- Create: `/Users/user/development/my/logger_builder/test/custom_log_test.dart`

**Interfaces:**
- Produces: `@protected CustomLog.copy(CustomLog original, {required Object? error, required StackTrace? stackTrace})` —
  копирует `level`/`levelName`/`shortLevelName`/`zone` из оригинала,
  `error`/`stackTrace` присваивает дословно (без `stackTraceFromError`).
  Тестовая фикстура получает `Log.copy(Log original, {Object? message, Object? error, StackTrace? stackTrace})`
  (используется задачами 2–3).

- [ ] **Step 1: Write the failing test**

Создать `test/custom_log_test.dart`:

```dart
import 'package:logger_builder/logger_builder.dart';
import 'package:test/test.dart';

import 'utils/hierarchical_logger.dart';

void main() {
  group('CustomLog.copy', () {
    Log capture(void Function(Logger logger) emit) {
      final logs = <Log>[];
      // Порог 0 включает все уровни (уровни всегда > 0).
      final logger = Logger('test')
        ..level = 0
        ..publisher = CustomLogPublisher(logs.add);
      emit(logger);

      return logs.single;
    }

    test('preserves level fields, zone and timestamp', () {
      final original = capture((logger) => logger.i('hello'));
      final copy = Log.copy(original, message: 'masked');

      expect(copy.level, original.level);
      expect(copy.levelName, original.levelName);
      expect(copy.shortLevelName, original.shortLevelName);
      expect(copy.zone, same(original.zone));
      expect(copy.timestamp, original.timestamp);
      expect(copy.path, original.path);
      expect(copy.message, 'masked');
    });

    test('keeps the original message when not overridden', () {
      final original = capture((logger) => logger.i('hello'));
      final copy = Log.copy(original);

      expect(copy.message, 'hello');
    });

    test('assigns error and stackTrace verbatim', () {
      final error = StateError('boom');
      final original = capture(
        (logger) => logger.e(
          'fail',
          error: error,
          stackTrace: StackTrace.current,
        ),
      );
      expect(original.stackTrace, isNotNull);

      // Копия с error, но без stackTrace НЕ выводит трейс заново и не
      // подхватывает трейс оригинала — значения присваиваются дословно.
      final copy = Log.copy(original, error: error, stackTrace: null);

      expect(copy.error, same(error));
      expect(copy.stackTrace, isNull);
    });

    test('drops error when copied without one', () {
      final original =
          capture((logger) => logger.e('fail', error: StateError('boom')));
      final copy = Log.copy(original);

      expect(copy.error, isNull);
      expect(copy.stackTrace, isNull);
    });
  });
}
```

Примечание: конфликта имён между пакетом и фикстурой нет — пакет
экспортирует `CustomLog`/`CustomLogger`, а `Log`/`Logger` объявляет
только фикстура; `hide` не нужен.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/user/development/my/logger_builder && dart test test/custom_log_test.dart`
Expected: COMPILE ERROR — `Log.copy` / `CustomLog.copy` не существуют.

- [ ] **Step 3: Write minimal implementation**

В `lib/src/custom_logger/custom_log.dart`:

1. Добавить импорт `package:meta/meta.dart`.
2. Добавить конструктор после основного:

```dart
  /// Creates a copy of [original] with the given [error] and [stackTrace].
  ///
  /// [level], [levelName], [shortLevelName] and [zone] are taken from
  /// [original]; [error] and [stackTrace] are assigned verbatim — unlike
  /// the main constructor, no stack trace is derived from [error]. Intended
  /// for subclass `copyWith` implementations: a copy is not a new log
  /// event, so no new identity (number, time) should be minted.
  @protected
  CustomLog.copy(
    CustomLog original, {
    required this.error,
    required this.stackTrace,
  })  : level = original.level,
        levelName = original.levelName,
        shortLevelName = original.shortLevelName,
        zone = original.zone;
```

В `test/utils/hierarchical_logger.dart` добавить в `Log` копирующий
конструктор (полям `timestamp`/`_lazyPath`/`_lazyMessage` — значения
оригинала; `message != null` — замена):

```dart
  Log.copy(
    Log original, {
    Object? message,
    Object? error,
    StackTrace? stackTrace,
  })  : timestamp = original.timestamp,
        _lazyPath = original._lazyPath,
        _lazyMessage = message != null
            ? LazyStringOrNull(message)
            : original._lazyMessage,
        super.copy(original, error: error, stackTrace: stackTrace);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/user/development/my/logger_builder && dart test test/custom_log_test.dart`
Expected: PASS (4 tests). Затем весь набор: `dart test` — без регрессий,
`dart analyze` — чисто, `dart format --set-exit-if-changed .`.

- [ ] **Step 5: Commit**

```bash
git -C /Users/user/development/my/logger_builder add -A
git -C /Users/user/development/my/logger_builder commit -m "Add protected CustomLog.copy for subclass copyWith support

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: `LogTransformer` typedef + `TransformPublisher` (logger_builder)

**Files:**
- Modify: `/Users/user/development/my/logger_builder/lib/src/custom_logger/custom_log.dart` (typedef)
- Create: `/Users/user/development/my/logger_builder/lib/src/async_publishers/transform_publisher.dart`
- Modify: `/Users/user/development/my/logger_builder/lib/logger_builder.dart` (export)
- Create: `/Users/user/development/my/logger_builder/test/transform_publisher_test.dart`

**Interfaces:**
- Consumes: `Log.copy` из фикстуры (Task 1); `Flushable`/`Closable` из
  `async_publisher.dart`; паттерн `_reportError` из `MultiPublisher`.
- Produces:
  `typedef LogTransformer<Log extends CustomLog> = Log? Function(Log log);`
  `TransformPublisher<Log extends CustomLog>(CustomLogPublisher<Log> inner, {required LogTransformer<Log> transformer, void Function(Object error, StackTrace stackTrace)? onError})`
  implements `CustomLogPublisher<Log>, Flushable, Closable`.

- [ ] **Step 1: Write the failing test**

Создать `test/transform_publisher_test.dart`:

```dart
import 'dart:async';

import 'package:logger_builder/logger_builder.dart';
import 'package:test/test.dart';

import 'utils/hierarchical_logger.dart';

final class _LifecyclePublisher
    implements CustomLogPublisher<Log>, Flushable, Closable {
  final published = <Log>[];
  var flushCount = 0;
  var closeCount = 0;

  @override
  void publish(Log log) => published.add(log);

  @override
  Future<void> flush() async {
    flushCount++;
  }

  @override
  Future<void> close() async {
    closeCount++;
  }
}

void main() {
  group('TransformPublisher', () {
    late List<Log> published;
    late Logger logger;

    void setUpLogger(CustomLogPublisher<Log> publisher) {
      published = <Log>[];
      logger = Logger('test')
        ..level = 0
        ..publisher = publisher;
    }

    test('inner receives the transformed log', () {
      setUpLogger(
        TransformPublisher(
          CustomLogPublisher(published.add),
          transformer: (log) => Log.copy(log, message: '***'),
        ),
      );

      logger.i('secret');

      expect(published, hasLength(1));
      expect(published.single.message, '***');
    });

    test('null from transformer drops the log', () {
      setUpLogger(
        TransformPublisher(
          CustomLogPublisher(published.add),
          transformer: (log) => null,
        ),
      );

      logger.i('secret');

      expect(published, isEmpty);
    });

    test('throwing transformer drops the log and reports to the zone', () {
      final errors = <Object>[];
      runZonedGuarded(
        () {
          setUpLogger(
            TransformPublisher(
              CustomLogPublisher(published.add),
              transformer: (log) => throw StateError('bad transformer'),
            ),
          );

          logger.i('secret');
        },
        (error, stackTrace) => errors.add(error),
      );

      expect(published, isEmpty);
      expect(errors, hasLength(1));
      expect(errors.single, isA<StateError>());
    });

    test('throwing transformer reports to onError instead of the zone', () {
      final errors = <Object>[];
      final zoneErrors = <Object>[];
      runZonedGuarded(
        () {
          setUpLogger(
            TransformPublisher(
              CustomLogPublisher(published.add),
              transformer: (log) => throw StateError('bad transformer'),
              onError: (error, stackTrace) => errors.add(error),
            ),
          );

          logger.i('secret');
        },
        (error, stackTrace) => zoneErrors.add(error),
      );

      expect(published, isEmpty);
      expect(errors, hasLength(1));
      expect(zoneErrors, isEmpty);
    });

    test('throwing onError is reported to the zone, delivery continues', () {
      final zoneErrors = <Object>[];
      runZonedGuarded(
        () {
          setUpLogger(
            TransformPublisher(
              CustomLogPublisher(published.add),
              transformer: (log) => log.message == 'boom'
                  ? throw StateError('bad transformer')
                  : log,
              onError: (error, stackTrace) =>
                  throw StateError('bad handler'),
            ),
          );

          logger
            ..i('boom')
            ..i('fine');
        },
        (error, stackTrace) => zoneErrors.add(error),
      );

      expect(zoneErrors, hasLength(1));
      expect(published, hasLength(1));
      expect(published.single.message, 'fine');
    });

    test('flush and close are delegated to the inner publisher', () async {
      final inner = _LifecyclePublisher();
      final publisher = TransformPublisher(inner, transformer: (log) => log);

      await publisher.flush();
      await publisher.close();

      expect(inner.flushCount, 1);
      expect(inner.closeCount, 1);
    });

    test('flush and close complete for a plain inner publisher', () async {
      final publisher = TransformPublisher(
        const CustomLogPublisher<Log>.noOp(),
        transformer: (log) => log,
      );

      await publisher.flush();
      await publisher.close();
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/user/development/my/logger_builder && dart test test/transform_publisher_test.dart`
Expected: COMPILE ERROR — `TransformPublisher` не существует.

- [ ] **Step 3: Write minimal implementation**

В `lib/src/custom_logger/custom_log.dart` (после класса `CustomLog`):

```dart
/// Transforms a log event before it is published.
///
/// Returning a (possibly modified) log publishes it instead of the
/// original; returning `null` drops the log entirely. Used by
/// `CustomLogger.transformer` and `TransformPublisher` — primarily for
/// security: masking secrets and PII before the log reaches any output.
typedef LogTransformer<Log extends CustomLog> = Log? Function(Log log);
```

Создать `lib/src/async_publishers/transform_publisher.dart`:

```dart
import 'dart:async';

import '../custom_logger/custom_log.dart';
import '../custom_logger/custom_log_publisher.dart';
import 'async_publisher.dart';

/// A publisher that transforms every log before handing it to the wrapped
/// publisher.
///
/// Use it to apply a different [LogTransformer] per destination — e.g.
/// mask secrets only in the file/network publisher while the console one
/// stays verbatim:
///
/// ```dart
/// logger.publisher = MultiPublisher([
///   consolePrinter,
///   TransformPublisher(fileStorage, transformer: redact),
/// ]);
/// ```
///
/// The transformer returning `null` drops the log. A throwing transformer
/// also drops the log (fail-closed: the untransformed log is never
/// published) and reports the error to [onError]; without [onError] the
/// error goes to the current zone via [Zone.handleUncaughtError].
///
/// [flush] and [close] are delegated to the wrapped publisher when it
/// implements [Flushable]/[Closable], and complete immediately otherwise.
final class TransformPublisher<Log extends CustomLog>
    implements CustomLogPublisher<Log>, Flushable, Closable {
  final CustomLogPublisher<Log> _inner;

  /// Transforms a log before publishing; `null` drops the log.
  final LogTransformer<Log> transformer;

  /// Called when [transformer] throws.
  ///
  /// When `null`, the error is reported to the current zone via
  /// [Zone.handleUncaughtError]. A throwing [onError] does not interrupt
  /// delivery: its own error is reported to the current zone.
  final void Function(Object error, StackTrace stackTrace)? onError;

  /// Creates a publisher that transforms every log before [inner].
  TransformPublisher(
    CustomLogPublisher<Log> inner, {
    required this.transformer,
    this.onError,
  }) : _inner = inner;

  @override
  void publish(Log log) {
    final Log? transformed;
    try {
      transformed = transformer(log);
    } on Object catch (error, stackTrace) {
      _reportError(error, stackTrace);

      return;
    }

    if (transformed != null) {
      _inner.publish(transformed);
    }
  }

  void _reportError(Object error, StackTrace stackTrace) {
    if (onError case final onError?) {
      try {
        onError(error, stackTrace);
      } on Object catch (handlerError, handlerStackTrace) {
        // A throwing error handler must not interrupt delivery.
        Zone.current.handleUncaughtError(handlerError, handlerStackTrace);
      }
    } else {
      Zone.current.handleUncaughtError(error, stackTrace);
    }
  }

  @override
  Future<void> flush() => switch (_inner) {
        final Flushable flushable => flushable.flush(),
        _ => Future.value(),
      };

  @override
  Future<void> close() => switch (_inner) {
        final Closable closable => closable.close(),
        _ => Future.value(),
      };
}
```

В `lib/logger_builder.dart` добавить экспорт (алфавитный порядок — после
`multi_publisher.dart`):

```dart
export 'src/async_publishers/transform_publisher.dart';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/user/development/my/logger_builder && dart test test/transform_publisher_test.dart && dart test && dart analyze && dart format --set-exit-if-changed .`
Expected: все PASS, analyze чист, format без изменений.

- [ ] **Step 5: Commit**

```bash
git -C /Users/user/development/my/logger_builder add -A
git -C /Users/user/development/my/logger_builder commit -m "Add LogTransformer typedef and TransformPublisher

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: `CustomLogger.transformer` + `CustomLevelLogger.publishLog` (logger_builder)

**Files:**
- Modify: `/Users/user/development/my/logger_builder/lib/src/custom_logger/custom_logger.dart`
- Modify: `/Users/user/development/my/logger_builder/lib/src/custom_logger/custom_level_logger.dart`
- Modify: `/Users/user/development/my/logger_builder/test/utils/hierarchical_logger.dart`
- Create: `/Users/user/development/my/logger_builder/test/transformer_test.dart`

**Interfaces:**
- Consumes: `LogTransformer` (Task 2), `Log.copy` фикстуры (Task 1),
  приватные `_subloggers`/`pruneSubloggers`/`_relink` в `custom_logger.dart`.
- Produces:
  `LogTransformer<Log>? get transformer` / `set transformer(LogTransformer<Log>? value)` на `CustomLogger` (push-наследование, флаг `_transformerLinked`, `@visibleForTesting bool get transformerLinked`);
  `@protected void publishLog(Log log)` на `CustomLevelLogger`.
  Контракт: `processLog` подклассов должен звать `publishLog` вместо
  `publisher.publish` (team_logger перейдёт в Task 6).

- [ ] **Step 1: Write the failing test**

Создать `test/transformer_test.dart`:

```dart
import 'dart:async';

import 'package:logger_builder/logger_builder.dart';
import 'package:test/test.dart';

import 'utils/hierarchical_logger.dart';

void main() {
  group('CustomLogger.transformer', () {
    late List<Log> published;
    late Logger logger;

    setUp(() {
      published = <Log>[];
      logger = Logger('app')
        ..level = 0
        ..publisher = CustomLogPublisher(published.add);
    });

    test('is applied before the publisher', () {
      logger
        ..transformer = ((log) => Log.copy(log, message: '***'))
        ..i('secret');

      expect(published.single.message, '***');
    });

    test('null transformer (default) publishes the log as is', () {
      logger.i('hello');

      expect(published.single.message, 'hello');
    });

    test('null from transformer drops the log', () {
      logger
        ..transformer = ((log) => null)
        ..i('secret');

      expect(published, isEmpty);
    });

    test('throwing transformer drops the log and reports to the zone', () {
      final errors = <Object>[];
      runZonedGuarded(
        () {
          logger
            ..transformer = ((log) => throw StateError('bad transformer'))
            ..i('secret');
        },
        (error, stackTrace) => errors.add(error),
      );

      expect(published, isEmpty);
      expect(errors.single, isA<StateError>());
    });

    test('a sublogger created after the assignment inherits it', () {
      logger.transformer = (log) => Log.copy(log, message: '***');
      final child = logger.withAddedName('child');

      child.i('secret');

      expect(published.single.message, '***');
      expect(child.transformerLinked, isTrue);
    });

    test('an assignment on the parent propagates to linked subloggers', () {
      final child = logger.withAddedName('child');
      logger.transformer = (log) => Log.copy(log, message: '***');

      child.i('secret');

      expect(published.single.message, '***');
    });

    test('an assignment on the child detaches it from the parent', () {
      final child = logger.withAddedName('child')
        ..transformer = ((log) => Log.copy(log, message: 'child'));
      logger.transformer = (log) => Log.copy(log, message: 'parent');

      child.i('secret');
      logger.i('secret');

      expect(published, hasLength(2));
      expect(published[0].message, 'child');
      expect(published[1].message, 'parent');
      expect(child.transformerLinked, isFalse);
    });

    test('self-assignment unlinks without changing the value', () {
      final child = logger.withAddedName('child');
      child.transformer = child.transformer;
      logger.transformer = (log) => Log.copy(log, message: 'parent');

      child.i('secret');

      expect(published.single.message, 'secret');
      expect(child.transformerLinked, isFalse);
    });

    test('relink() re-inherits the parent transformer', () {
      logger.transformer = (log) => Log.copy(log, message: 'parent');
      final child = logger.withAddedName('child')
        ..transformer = ((log) => Log.copy(log, message: 'child'));

      child.relink();
      child.i('secret');

      expect(published.single.message, 'parent');
      expect(child.transformerLinked, isTrue);
    });

    test('works together with a per-level publisher', () {
      final errorsOnly = <Log>[];
      logger
        ..transformer = ((log) => Log.copy(log, message: '***'))
        ..[Levels.error].publisher = CustomLogPublisher(errorsOnly.add);

      logger
        ..i('secret')
        ..e('secret');

      expect(published.single.message, '***');
      expect(errorsOnly.single.message, '***');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/user/development/my/logger_builder && dart test test/transformer_test.dart`
Expected: COMPILE ERROR — `transformer`/`transformerLinked` не существуют.

- [ ] **Step 3: Write minimal implementation**

В `lib/src/custom_logger/custom_logger.dart`:

1. Импорт `dart:async` (для `Zone` в part-файле level logger'а).
2. Поля рядом с `_publisherLinked` (строка ~37):

```dart
  LogTransformer<Log>? _transformer;
  bool _transformerLinked = false;
```

3. Рядом с `publisherLinked` (~строка 92) — тестовый геттер:

```dart
  /// Returns `true` if this logger's transformer is synchronized with its
  /// parent.
  ///
  /// For tests only; not intended for production use.
  @visibleForTesting
  bool get transformerLinked => _transformerLinked;
```

4. В `_relink()` после `level = parent.level;`:

```dart
    transformer = parent._transformer;
```

и после `_levelLinked = true;` добавить `_transformerLinked = true;`.

5. Геттер/сеттер после `set publisher` (~строка 209):

```dart
  /// The transformer applied to every log of this logger right before it
  /// is handed to the publisher (see [CustomLevelLogger.publishLog]).
  ///
  /// Intended primarily for security: masking secrets and PII, or dropping
  /// forbidden logs entirely (`null` return). `null` (the default) means
  /// no transformation.
  ///
  /// Fail-closed: if the transformer throws, the log is NOT published and
  /// the error is reported to the current zone via
  /// [Zone.handleUncaughtError]. Use `TransformPublisher` with its
  /// `onError` for a custom error callback.
  LogTransformer<Log>? get transformer => _transformer;

  /// Sets the log [transformer].
  ///
  /// Propagates the change to linked subloggers. Detaches this logger's
  /// transformer link if it is a sublogger
  /// (`child.transformer = child.transformer` unlinks without changing the
  /// value; use [relink] to re-attach).
  set transformer(LogTransformer<Log>? value) {
    _transformer = value;
    _transformerLinked = false;

    pruneSubloggers();
    for (final sublogger in _subloggers) {
      if (sublogger.target case final sublogger?
          when sublogger._transformerLinked) {
        sublogger
          ..transformer = value
          .._transformerLinked = true;
      }
    }
  }
```

В `lib/src/custom_logger/custom_level_logger.dart` после
`set publisher` (~строка 119):

```dart
  /// Publishes [log], first applying the logger's
  /// [CustomLogger.transformer].
  ///
  /// Returning `null` from the transformer drops the log. A throwing
  /// transformer also drops it (fail-closed: the untransformed log is
  /// never published) and reports the error to the current zone via
  /// [Zone.handleUncaughtError].
  ///
  /// Subclasses must call this from [processLog] instead of
  /// `publisher.publish(...)` — otherwise [CustomLogger.transformer] is
  /// ignored.
  @protected
  void publishLog(Log log) {
    var published = log;

    if (logger._transformer case final transformer?) {
      final Log? transformed;
      try {
        transformed = transformer(log);
      } on Object catch (error, stackTrace) {
        Zone.current.handleUncaughtError(error, stackTrace);

        return;
      }

      if (transformed == null) {
        return;
      }
      published = transformed;
    }

    _publisher.publish(published);
  }
```

В `test/utils/hierarchical_logger.dart` в `LevelLogger.processLog`
заменить `publisher.publish(` на `publishLog(`.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/user/development/my/logger_builder && dart test && dart analyze && dart format --set-exit-if-changed .`
Expected: все PASS (включая старые hierarchy-тесты — фикстура перешла на
`publishLog`), analyze чист, format без изменений.

- [ ] **Step 5: Commit**

```bash
git -C /Users/user/development/my/logger_builder add -A
git -C /Users/user/development/my/logger_builder commit -m "Add CustomLogger.transformer and CustomLevelLogger.publishLog

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: Релиз logger_builder 0.5.0 — ГЕЙТ: одобрение пользователя

**Files:**
- Modify: `/Users/user/development/my/logger_builder/pubspec.yaml` (version)
- Modify: `/Users/user/development/my/logger_builder/CHANGELOG.md`

- [ ] **Step 1: Bump + changelog**

`pubspec.yaml`: `version: 0.5.0`. В начало `CHANGELOG.md`
(стиль пакета — `*`-буллеты, 80 колонок):

```markdown
## 0.5.0

* Pre-publication log processing: the new `LogTransformer` typedef
  (`Log? Function(Log)`), the `CustomLogger.transformer` property applied
  to every log right before publishing (inherited by subloggers like
  `level`/`publisher`, same link/unlink/`relink` semantics), and the
  `TransformPublisher` wrapper for per-destination transformation.
  Returning `null` drops the log. Fail-closed: a throwing transformer
  drops the log and reports the error to `onError`
  (`TransformPublisher`) or the current zone.
* [breaking changes] `CustomLevelLogger` gains the protected `publishLog`:
  `processLog` implementations must call it instead of
  `publisher.publish(...)`, otherwise `CustomLogger.transformer` is
  ignored.
* The new protected `CustomLog.copy` copies level fields and the zone from
  an existing log and assigns `error`/`stackTrace` verbatim — the building
  block for `copyWith` in subclasses (a copy keeps the log's identity: no
  new number or time should be minted).
```

- [ ] **Step 2: Verify**

Run: `cd /Users/user/development/my/logger_builder && dart test && dart analyze && dart format --set-exit-if-changed . && dart pub publish --dry-run`
Expected: 0 issues (или только предупреждение о несовпадении с git —
допустимо до коммита).

- [ ] **Step 3: ГЕЙТ — показать дифф пользователю**

Показать пользователю полный дифф релиза: незакоммиченное
(`git -C /Users/user/development/my/logger_builder diff`) плюс задачи 1–3 —
`git -C /Users/user/development/my/logger_builder diff v0.4.0..HEAD`; если
тега `v0.4.0` нет, взять базой релизный коммит 0.4.0 из
`git log --oneline`. ДОЖДАТЬСЯ явного одобрения. Без одобрения к Step 4
не переходить.

- [ ] **Step 4: Commit, publish, tag, push**

```bash
git -C /Users/user/development/my/logger_builder add -A
git -C /Users/user/development/my/logger_builder commit -m "Release 0.5.0

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
cd /Users/user/development/my/logger_builder && dart pub publish --force
git -C /Users/user/development/my/logger_builder tag v0.5.0
git -C /Users/user/development/my/logger_builder push origin main --tags
```

Дождаться доступности: цикл
`curl -s https://pub.dev/api/packages/logger_builder | grep -q '"version":"0.5.0"'`
(фоново, раз в 10 с). При зависании резолва — удалить
`~/.pub-cache/hosted/pub.dev/.cache/logger_builder-versions.json`.

---

### Task 5: `Log.copyWith` (team_logger)

**Files:**
- Modify: `/Users/user/development/my/team_logger/pubspec.yaml` (`logger_builder: ^0.5.0`)
- Modify: `/Users/user/development/my/team_logger/lib/src/logger/log.dart`
- Create: `/Users/user/development/my/team_logger/test/logger/log_copy_with_test.dart`

**Interfaces:**
- Consumes: `CustomLog.copy` (Task 1, из logger_builder 0.5.0).
- Produces:
  `Log copyWith({String? message, Object? data = _unset, Set<String>? tags, Object? error = _unset, Object? stackTrace = _unset, String? path, List<TraceId>? traceIds})` —
  sentinel `_unset` = «не менять»; `num`/`time`/уровень/`zone` всегда
  сохраняются. Используется transformer'ами (Task 6).

- [ ] **Step 0: Подтянуть logger_builder 0.5.0**

`pubspec.yaml`: `logger_builder: ^0.4.0` → `^0.5.0`. Затем
`cd /Users/user/development/my/team_logger && dart pub upgrade` (подтянет и `example/`).
Проверить в `pubspec.lock`: `logger_builder ... 0.5.0`.

- [ ] **Step 1: Write the failing test**

Создать `test/logger/log_copy_with_test.dart`:

```dart
import 'package:team_logger/team_logger.dart';
import 'package:test/test.dart';

void main() {
  group('Log.copyWith', () {
    Log capture(void Function(Logger logger) emit) {
      final logs = <Log>[];
      final logger = Logger('test')
        ..level = LogLevels.all
        ..publisher = CustomLogPublisher(logs.add);
      emit(logger);

      return logs.single;
    }

    test('no arguments: an equivalent copy, identity preserved', () {
      final original = capture(
        (log) => log.i(
          'hello',
          data: {'a': 1},
          tags: {'t'},
          error: StateError('boom'),
        ),
      );
      final before = Log.lastNum;
      final copy = original.copyWith();

      expect(Log.lastNum, before, reason: 'no new number is minted');
      expect(copy.num, original.num);
      expect(copy.time, original.time);
      expect(copy.level, original.level);
      expect(copy.levelName, original.levelName);
      expect(copy.zone, same(original.zone));
      expect(copy.path, original.path);
      expect(copy.message, original.message);
      expect(copy.data, same(original.data));
      expect(copy.tags, original.tags);
      expect(copy.traceIds, original.traceIds);
      expect(copy.error, same(original.error));
      expect(copy.stackTrace, same(original.stackTrace));
    });

    test('replaces the message, keeps number and time', () {
      final original = capture((log) => log.i('token secret-1'));
      final copy = original.copyWith(message: 'token ***');

      expect(copy.message, 'token ***');
      expect(copy.num, original.num);
      expect(copy.time, original.time);
    });

    test('replaces and clears data', () {
      final original = capture((log) => log.i('m', data: {'pin': 1234}));

      final masked = original.copyWith(data: {'pin': '***'});
      expect(masked.data, {'pin': '***'});
      expect(masked.hasData, isTrue);

      final cleared = original.copyWith(data: Log.noData);
      expect(cleared.hasData, isFalse);
    });

    test('data can be set to null (a valid value)', () {
      final original = capture((log) => log.i('m', data: {'a': 1}));
      final copy = original.copyWith(data: null);

      expect(copy.data, isNull);
    });

    test('clears the error without re-deriving the stack trace', () {
      // У не-брошенного StateError stackTrace == null, поэтому трейс
      // передаётся явно — иначе утверждения были бы слепыми.
      final original = capture(
        (log) => log.e(
          'fail',
          error: StateError('secret'),
          stackTrace: StackTrace.current,
        ),
      );
      expect(original.stackTrace, isNotNull);

      final cleared = original.copyWith(error: null, stackTrace: null);
      expect(cleared.error, isNull);
      expect(cleared.stackTrace, isNull);
    });

    test('replacing the error keeps the original stack trace', () {
      final original = capture(
        (log) => log.e(
          'fail',
          error: StateError('secret'),
          stackTrace: StackTrace.current,
        ),
      );
      expect(original.stackTrace, isNotNull);

      final copy = original.copyWith(error: 'redacted');

      expect(copy.error, 'redacted');
      expect(copy.stackTrace, same(original.stackTrace));
    });

    test('replaces tags, path and traceIds; empty collections clear', () {
      final original = capture((log) => log.i('m', tags: {'a', 'b'}));
      final copy = original.copyWith(
        tags: const {},
        path: 'other',
        traceIds: const [TraceId.manual('req', 1)],
      );

      expect(copy.tags, isEmpty);
      expect(copy.path, 'other');
      expect(copy.traceIds, hasLength(1));

      final clearedTraces = copy.copyWith(traceIds: const []);
      expect(clearedTraces.traceIds, isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/user/development/my/team_logger && dart test test/logger/log_copy_with_test.dart`
Expected: COMPILE ERROR — `copyWith` не существует.

- [ ] **Step 3: Write minimal implementation**

В `lib/src/logger/log.dart` (part of logger.dart):

1. Приватный sentinel над классом `Log` (рядом с `LogNoData`):

```dart
final class _Unset {
  const _Unset._();
}
```

2. Внутри `Log` — константа, копирующий конструктор и `copyWith` (после
основного конструктора):

```dart
  static const _unset = _Unset._();

  Log._copy(
    Log original, {
    required this.path,
    required this.traceIds,
    required this.message,
    required this.data,
    required this.tags,
    required Object? error,
    required StackTrace? stackTrace,
  })  : num = original.num,
        time = original.time,
        super.copy(original, error: error, stackTrace: stackTrace);

  /// Creates a copy of this log with the given fields replaced.
  ///
  /// The copy keeps the log's identity: [num], [time], the level and
  /// [zone] are always preserved — no new sequence number is consumed.
  /// This is the intended building block for [LogTransformer]s (masking
  /// secrets/PII); constructing a `Log` with the main constructor inside
  /// a transformer would mint a new number and time instead.
  ///
  /// Omitted parameters keep the original values. Fields where `null` is
  /// a meaningful value use an internal sentinel as the default, so
  /// `copyWith(error: null)` really clears the error (and
  /// `stackTrace: null` — the stack trace, which is NOT re-derived from
  /// [error]); `data: Log.noData` clears the data. Collections are
  /// cleared with empty values (`tags: {}`, `traceIds: []`).
  /// [stackTrace], when passed, must be a [StackTrace] or `null`.
  Log copyWith({
    String? message,
    Object? data = _unset,
    Set<String>? tags,
    Object? error = _unset,
    Object? stackTrace = _unset,
    String? path,
    List<TraceId>? traceIds,
  }) =>
      Log._copy(
        this,
        path: path ?? this.path,
        traceIds: traceIds ?? this.traceIds,
        message: message ?? this.message,
        data: identical(data, _unset) ? this.data : data,
        tags: tags ?? this.tags,
        error: identical(error, _unset) ? this.error : error,
        stackTrace: identical(stackTrace, _unset)
            ? this.stackTrace
            : stackTrace as StackTrace?,
      );
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/user/development/my/team_logger && dart test && dart analyze && dart format --set-exit-if-changed .`
Expected: все PASS (214 старых + новые), analyze чист.

- [ ] **Step 5: Commit**

```bash
git -C /Users/user/development/my/team_logger add -A
git -C /Users/user/development/my/team_logger commit -m "feat: add Log.copyWith on logger_builder 0.5.0 CustomLog.copy

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: `processLog` → `publishLog` + e2e transformer-тесты (team_logger)

**Files:**
- Modify: `/Users/user/development/my/team_logger/lib/src/logger/logger.dart:72` (`publisher.publish(` → `publishLog(`)
- Modify: `/Users/user/development/my/team_logger/lib/src/logger/logger.dart` (dartdoc `Logger`)
- Create: `/Users/user/development/my/team_logger/test/logger/transformer_test.dart`

**Interfaces:**
- Consumes: `publishLog` и `logger.transformer` (Task 3, через re-export),
  `TransformPublisher` (Task 2), `Log.copyWith` (Task 5),
  `ConsoleLogPrinter(theme:, rows:, output:)`,
  `FileLogStorage(directory:)` из `package:team_logger/team_logger_io.dart`.
- Produces: активацию `logger.transformer` в team_logger (единственная
  правка пайплайна).

- [ ] **Step 1: Write the failing test**

Создать `test/logger/transformer_test.dart`:

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:team_logger/team_logger_io.dart';
import 'package:test/test.dart';

String _mask(String s) => s.replaceAll(RegExp('secret-[0-9]+'), '***');

void main() {
  group('Logger.transformer (e2e)', () {
    (Logger, List<String>) setUpPrinter() {
      final lines = <String>[];
      final logger = Logger('app')
        ..level = LogLevels.all
        ..publisher = ConsoleLogPrinter(
          theme: LogMainTheme.noColors,
          rows: const [
            LogRow(maxLength: 120, children: [LogMessage()]),
          ],
          output: lines.add,
        );

      return (logger, lines);
    }

    test('masks the message before the console printer', () {
      final (logger, lines) = setUpPrinter();
      logger
        ..transformer = ((log) => log.copyWith(message: _mask(log.message)))
        ..i('token secret-123');

      final output = lines.join('\n');
      expect(output, contains('***'));
      expect(output, isNot(contains('secret-123')));
    });

    test('masks the data before the console printer', () {
      final (logger, lines) = setUpPrinter();
      logger
        ..publisher = ConsoleLogPrinter(
          theme: LogMainTheme.noColors,
          rows: const [
            LogRow(maxLength: 200, children: [LogMessage()]),
          ],
          output: lines.add,
        )
        ..transformer = ((log) => log.copyWith(data: {'pin': '***'}))
        ..i('payment', data: {'pin': 1234});

      final output = lines.join('\n');
      // Положительное утверждение защищает от слепого теста: если data
      // вообще не печатается с этой конфигурацией rows, тест упадёт —
      // поправить rows, а не убирать проверку.
      expect(output, contains('***'));
      expect(output, isNot(contains('1234')));
    });

    test('drops the log entirely on null', () {
      final (logger, lines) = setUpPrinter();
      logger
        ..transformer =
            ((log) => log.message.contains('secret') ? null : log)
        ..i('token secret-123')
        ..i('plain');

      final output = lines.join('\n');
      expect(output, isNot(contains('secret-123')));
      expect(output, contains('plain'));
    });

    test('fail-closed: a throwing transformer publishes nothing', () {
      final (logger, lines) = setUpPrinter();
      final errors = <Object>[];
      runZonedGuarded(
        () {
          logger
            ..transformer = ((log) => throw StateError('bug'))
            ..i('token secret-123');
        },
        (error, stackTrace) => errors.add(error),
      );

      expect(lines, isEmpty);
      expect(errors.single, isA<StateError>());
    });

    test('a child logger inherits the transformer', () {
      final (logger, lines) = setUpPrinter();
      logger.transformer =
          (log) => log.copyWith(message: _mask(log.message));
      final child = logger.createChild(name: 'net');

      child.i('token secret-9');

      expect(lines.join('\n'), isNot(contains('secret-9')));
    });

    test('TransformPublisher masks one destination only', () {
      final console = <Log>[];
      final file = <Log>[];
      final logger = Logger('app')
        ..level = LogLevels.all
        ..publisher = MultiPublisher([
          CustomLogPublisher(console.add),
          TransformPublisher(
            CustomLogPublisher(file.add),
            transformer: (log) => log.copyWith(message: _mask(log.message)),
          ),
        ]);

      logger.i('token secret-123');

      expect(console.single.message, contains('secret-123'));
      expect(file.single.message, isNot(contains('secret-123')));
    });

    test('masked logs reach FileLogStorage as masked JSONL', () async {
      final tmp = await Directory.systemTemp.createTemp('transformer_test');
      addTearDown(() => tmp.delete(recursive: true));

      final storage = FileLogStorage(directory: tmp.path);
      final logger = Logger('app')
        ..level = LogLevels.all
        ..publisher = storage
        ..transformer =
            ((log) => log.copyWith(message: _mask(log.message)));

      logger.i('token secret-123');
      await storage.flush();
      await storage.close();

      final content = Directory(tmp.path)
          .listSync()
          .whereType<File>()
          .map((f) => utf8.decode(f.readAsBytesSync()))
          .join('\n');
      expect(content, contains('***'));
      expect(content, isNot(contains('secret-123')));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/user/development/my/team_logger && dart test test/logger/transformer_test.dart`
Expected: FAIL — `transformer` уже есть (re-export 0.5.0), но
`processLog` зовёт `publisher.publish` напрямую, поэтому маскирование не
применяется (тесты «masks…» красные). Если вместо этого COMPILE ERROR —
проверить, что Task 5 Step 0 подтянул logger_builder 0.5.0.

- [ ] **Step 3: Write minimal implementation**

В `lib/src/logger/logger.dart` в `LevelLogger.processLog` (строка ~72)
заменить:

```dart
        publisher.publish(
          Log(
```

на:

```dart
        publishLog(
          Log(
```

Обновить dartdoc класса `Logger` — в абзац «Contract notes» добавить:

```dart
/// [transformer] is applied to every log right before publishing —
/// mask secrets/PII or drop logs entirely (see [LogTransformer]); it is
/// inherited by subloggers the same way as `level` and `publisher`.
/// Write transformers with [Log.copyWith] — it preserves the log's
/// number and time.
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/user/development/my/team_logger && dart test && dart analyze && dart format --set-exit-if-changed .`
Expected: все PASS, analyze чист. Дополнительно прогнать пример:
`cd /Users/user/development/my/team_logger/example && dart pub get && dart run bin/example.dart`
— вывод не изменился (transformer по умолчанию null).

- [ ] **Step 5: Commit**

```bash
git -C /Users/user/development/my/team_logger add -A
git -C /Users/user/development/my/team_logger commit -m "feat: route publishing through publishLog to enable logger.transformer

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 7: Релиз team_logger 0.5.2 — ГЕЙТ: одобрение пользователя

**Files:**
- Modify: `/Users/user/development/my/team_logger/pubspec.yaml` (version)
- Modify: `/Users/user/development/my/team_logger/CHANGELOG.md`

- [ ] **Step 1: Подтвердить номер версии у пользователя**

Изменения аддитивные ⇒ по прецеденту 0.4.2 предлагается **0.5.2**;
альтернатива **0.6.0**, если пользователь хочет сигнализировать заметную
фичу. Спросить и применить выбор.

- [ ] **Step 2: Bump + changelog**

`pubspec.yaml`: `version: 0.5.2` (или выбранная). В начало
`CHANGELOG.md` (стиль пакета — `-`-буллеты, `[имена]` в скобках):

```markdown
## 0.5.2

- Pre-publication log processing (primarily for security — masking
  secrets/PII, dropping forbidden logs): require `logger_builder` ^0.5.0,
  whose new API flows through the re-export. Assign
  [Logger.transformer] (`Log? Function(Log)`) to process every log right
  before publishing — subloggers inherit it like `level`/`publisher`;
  returning `null` drops the log. Wrap a single publisher in
  [TransformPublisher] to transform for one destination only. Fail-closed:
  a throwing transformer drops the log and reports the error to
  `onError`/the current zone — the untransformed log is never published.
- Add [Log.copyWith] — the building block for transformers: replaces
  message/data/tags/error/stackTrace/path/traceIds while always preserving
  the log's identity ([Log.num], [Log.time], the level and zone; no new
  sequence number is consumed). `copyWith(error: null)` clears the error,
  `data: Log.noData` clears the data.
```

- [ ] **Step 3: Verify**

Run: `cd /Users/user/development/my/team_logger && dart test && dart analyze && dart format --set-exit-if-changed . && dart pub publish --dry-run`
Expected: 0 issues (кроме предупреждения о незакоммиченном состоянии).

- [ ] **Step 4: ГЕЙТ — показать дифф пользователю**

Показать полный дифф релиза (`git -C /Users/user/development/my/team_logger diff v0.5.1..HEAD`
+ незакоммиченное) и ДОЖДАТЬСЯ явного одобрения. Заодно спросить, нужна
ли секция про маскирование в README (спека: опционально).

- [ ] **Step 5: Commit, publish, tag, push**

```bash
git -C /Users/user/development/my/team_logger add -A
git -C /Users/user/development/my/team_logger commit -m "feat: pre-publication log processing (logger.transformer, Log.copyWith)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
cd /Users/user/development/my/team_logger && dart pub publish --force
git -C /Users/user/development/my/team_logger tag v0.5.2
git -C /Users/user/development/my/team_logger push origin main --tags
```

Дождаться доступности на pub.dev (цикл по
`https://pub.dev/api/packages/team_logger`), отчитаться пользователю.
