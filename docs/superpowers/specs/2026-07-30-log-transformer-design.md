# Обработка лога до публикации (LogTransformer) — security-хук

Дата: 2026-07-30
Статус: на ревью

## Цель

Дать возможность обработать запись лога между её созданием и публикацией —
в первую очередь для безопасности: маскирование секретов и PII в сообщении
и данных, удаление чувствительных полей из ошибок, полный запрет отдельных
логов. Обработка должна быть доступна на двух уровнях:

- **глобально на логгере** — сырой лог не попадает ни в один publisher,
  политика переживает смену publisher'ов;
- **per-publisher** — разная обработка для разных назначений (например,
  консоль полная, файл/сеть — маскированные).

## Решения, принятые при обсуждении

- **Оба уровня**: хук на логгере + composable обёртка-publisher.
- **Возможности**: сигнатура `Log? Function(Log)` — вернул изменённый лог,
  публикуется он; вернул `null` — лог отбрасывается (редакция и фильтрация
  одним API).
- **Пакеты**: оба примитива — в `logger_builder` (рядом с `MultiPublisher`
  и машинерией propagation), `team_logger` получает их через существующий
  re-export и добавляет `Log.copyWith`.
- **Ошибки — fail-closed**: исключение из обработчика ⇒ лог НЕ публикуется
  (немаскированный лог гарантированно не утекает), ошибка репортится в
  `onError`, а без него — в `Zone.current.handleUncaughtError` (паттерн
  `MultiPublisher` 0.3.2+).
- **Нейминг** — семейство «transform»: typedef `LogTransformer`, поле
  `logger.transformer` (agent-noun, параллельно `publisher`), обёртка
  `TransformPublisher`. «Transform» покрывает и drop — оговаривается в
  dartdoc явно. Защищённый метод публикации — `publishLog` (он про
  публикацию, не про трансформацию).

## Архитектура

Пайплайн: **Logger → Log → [transformer] → Publisher**. Точка врезки —
между построением `Log` в `LevelLogger.processLog` и `publisher.publish`.

### logger_builder: typedef

```dart
typedef LogTransformer<Log extends CustomLog> = Log? Function(Log log);
```

### logger_builder: `CustomLogger.transformer`

- Одно значение на логгер (`LogTransformer<Log>?`, по умолчанию `null` —
  без обработки). Per-level гранулярность не нужна: она достигается
  `TransformPublisher` на publisher'е конкретного уровня.
- Наследование сублоггерами — push-паттерн, зеркально `level`:
  - флаг `_transformerLinked`; сеттер `transformer` propagate'ит значение
    в залинкованные subloggers и отвязывает данный логгер от родителя;
  - идиома unlink без смены значения: `child.transformer = child.transformer`;
  - `relink()` заново наследует transformer родителя (вместе с level и
    publisher);
  - `_relink()` в конструкторе `.sub` — сублоггер наследует transformer
    родителя при создании.
- Геттер `transformer` публичный (в отличие от `publisher`, у которого
  геттера на логгере нет, — transformer один на логгер, геттер однозначен).

### logger_builder: `CustomLevelLogger.publishLog`

```dart
@protected
void publishLog(Log log);
```

Применяет `logger.transformer` (fail-closed: исключение ⇒ drop + ошибка в
`Zone.current.handleUncaughtError`), затем `_publisher.publish(...)`.
`null` от transformer'а ⇒ лог не публикуется.

Контракт для авторов кастомных логгеров: `processLog` должен вызывать
`publishLog` вместо `publisher.publish`, иначе `transformer` игнорируется.
Мягкое изменение контракта ⇒ бамп logger_builder 0.5.0.

Отдельного onError у логгер-хука нет — только Zone. Кому нужен колбэк,
использует `TransformPublisher`.

### logger_builder: `TransformPublisher`

```dart
final class TransformPublisher<Log extends CustomLog>
    implements CustomLogPublisher<Log>, Flushable, Closable {
  TransformPublisher(
    CustomLogPublisher<Log> inner, {
    required LogTransformer<Log> transformer,
    void Function(Object error, StackTrace stackTrace)? onError,
  });
}
```

- `publish`: transformer → `null` = drop; исключение = drop + `onError`,
  без него `Zone.current.handleUncaughtError`. Бросающий `onError` не
  прерывает работу: его собственная ошибка репортится в
  `Zone.current.handleUncaughtError` (зеркально `MultiPublisher`).
- `flush()`/`close()` делегируются inner'у, если тот реализует
  `Flushable`/`Closable`, иначе no-op (`Future.value`) — обёртка вокруг
  `FileLogStorage`/`MultiPublisher` не ломает жизненный цикл.
- `isClosed` не вводится: обёртка не имеет собственного состояния.

### team_logger: `Log.copyWith`

Инструмент для написания transformer'ов — иммутабельный `Log` иначе нельзя
изменить.

```dart
Log copyWith({
  String? message,      // null — «не менять»
  Object? data,         // sentinel — «не менять»; Log.noData — очистить
  Set<String>? tags,    // null — «не менять»; {} — очистить
  Object? error,        // sentinel — «не менять»; null — очистить
  Object? stackTrace,   // StackTrace; sentinel — «не менять»; null — очистить
  String? path,         // null — «не менять»
  List<TraceId>? traceIds, // null — «не менять»; [] — очистить
});
```

- Реализация — приватный копирующий конструктор поверх нового защищённого
  `CustomLog.copy(original, {required error, required stackTrace})` в
  logger_builder: поля `level`/`levelName`/`shortLevelName`/`zone` в базовом
  классе финальные и выводятся только из `levelLogger`, который лог не
  хранит, — без базового копирующего конструктора копия невозможна.
  `CustomLog.copy` присваивает `error`/`stackTrace` дословно (без
  повторного `stackTraceFromError`). **Сохраняются `num`, `time`, уровень
  и `zone`** — новый номер НЕ потребляется, это та же запись лога.
- Sentinel-дефолты (приватная const-заглушка) отличают «не передан» от
  «очистить» там, где `null`/`noData` — валидное целевое значение
  (`data`, `error`, `stackTrace`): `copyWith(error: null)` реально убирает
  error (секрет может сидеть в тексте исключения), `data: Log.noData`
  убирает данные. Поля, которые в `Log` не бывают null (`message`, `path`,
  `tags`, `traceIds`), обходятся обычным `null`-дефолтом = «не менять»;
  очистка коллекций — пустым значением (`{}`, `[]`).
- Уровень и `num`/`time` менять нельзя — смена уровня означала бы другой
  `LevelLogger` и другую маршрутизацию; вне рамок задачи.

**Нумерация.** Трансформация не влияет на нумерацию: `copyWith` не ходит в
счётчик `lastNum`, трансформированный лог сохраняет номер и время оригинала.
Отброшенный лог (`null` от transformer'а) номер уже потребил — дырка в
нумерации, что соответствует действующему контракту `Log.num` («filtered
out logs still consume numbers»). В dartdoc — рекомендация писать
transformer'ы через `copyWith`: конструирование `Log` обычным конструктором
внутри transformer'а потребит новый номер и новое время.

### team_logger: интеграция

- `LevelLogger.processLog`: единственная правка —
  `publisher.publish(Log(...))` → `publishLog(Log(...))`.
- `TransformPublisher` и `transformer` приходят через существующий
  re-export `logger_builder` в `lib/team_logger.dart` — правок экспорта
  не требуется.
- Dartdoc: контрактные заметки в классе `Logger` (упомянуть transformer),
  dartdoc `Log.copyWith`. README — короткая секция про маскирование
  (опционально, по решению при релизе).

## Обработка ошибок

| Ситуация | Поведение |
| --- | --- |
| transformer вернул `Log` | публикуется возвращённый лог |
| transformer вернул `null` | лог отброшен, ошибок нет |
| transformer бросил (логгер-хук) | лог отброшен, ошибка → `Zone.current.handleUncaughtError` |
| transformer бросил (`TransformPublisher`) | лог отброшен, ошибка → `onError`, без него → Zone |
| publisher бросил после трансформации | вне рамок: существующее поведение (изоляция — забота `MultiPublisher`) |

## Тестирование (TDD)

logger_builder:

- `TransformPublisher`: inner получает трансформированный лог; `null` —
  drop; исключение — drop + zone error (`runZonedGuarded`); `onError`
  получает ошибку; `flush`/`close` делегируются `Flushable`/`Closable`
  inner'у; не-Flushable inner — `flush()` завершается no-op.
- `CustomLogger.transformer`: применяется до publisher; `null` — лог не
  публикуется; исключение — drop + zone error; наследование: сублоггер,
  созданный после установки transformer'а, наследует его; установка на
  родителе после создания — propagate'ится; прямое присваивание на
  ребёнке — отвязывает; `child.transformer = child.transformer` —
  идиома unlink; `relink()` — восстанавливает.
- Взаимодействие: transformer логгера + per-level publisher.

team_logger:

- `Log.copyWith`: сохраняет `num`/`time`/уровень/`zone`; меняет
  message/data/tags/error/stackTrace/path/traceIds; sentinel-семантика
  (очистка error, `data: Log.noData`); `copyWith()` без аргументов —
  эквивалентная копия.
- e2e: `logger.transformer` маскирует сообщение и данные — проверка
  вывода `ConsoleLogPrinter` (инжектированный `output`) и содержимого
  JSONL `FileLogStorage`; drop-лог не появляется нигде; fail-closed.

## Релизы

По установленному циклу (дифф пользователю перед publish):

1. **logger_builder 0.5.0** — `LogTransformer`, `CustomLogger.transformer`,
   `CustomLevelLogger.publishLog`, `TransformPublisher`, защищённый
   `CustomLog.copy`; changelog отмечает мягкое изменение контракта
   `processLog`.
2. **team_logger 0.5.2** — `logger_builder: ^0.5.0`, `Log.copyWith`,
   переход `processLog` на `publishLog`. Изменения аддитивные — патч по
   прецеденту 0.4.2 (фича патчем). Альтернатива 0.6.0 — если пользователь
   захочет сигнализировать заметную фичу; решение при релизе.
