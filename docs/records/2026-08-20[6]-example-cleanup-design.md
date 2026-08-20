> **Состояние на 2026-08-20:** спека согласована с владельцем, к реализации
> не приступали.
> **Что это:** дизайн уборки `example/` — вместо «всё подряд для проверки»
> один короткий сквозной пример.
> **Связанные записи:** `2026-08-20[5]-number-formatter-report.md`.

# Уборка example/

## Что не так сейчас

`example/` писался как место, где владелец проверял глазами всё сразу.
Отсюда его состояние:

- `bin/example.dart` — 288 строк «всё подряд»: дамп трёх тем целиком, все
  ручки коллекций, циклические ссылки, not-loggable конвертеры, стеки.
- `example/README.md` — нетронутая болванка `dart create`: «A sample
  command-line application with an entrypoint in `bin/`, library code in
  `lib/`, and example unit test in `test/`». Каталога `test/` там нет.
- **Именно эту болванку показывает pub.dev.** Проверено на выпущенной
  версии: вкладка Example у `team_logger` содержит ровно текст
  `example/README.md` и больше ничего. `bin/example.dart` туда не попадает
  — pub.dev ищет пример по фиксированным путям, и `bin/` среди них нет.
- `example/CHANGELOG.md` — болванка `## 1.0.0 Initial version` у пакета с
  `publish_to: none`.
- `example/example/bin` — пустой каталог-хвост.
- В `pubspec.yaml` примера четыре зависимости, которыми никто не
  пользуется (см. ниже), и `description: A sample command-line
  application`.

## Решения владельца

1. **Проверочная роль уезжает в `tool/`** и не публикуется — рядом с
   `scripts/` и `docs/`, которые уже вынесены в `.pubignore` как
   «внутренняя кухня».
2. **Форма главного примера — файл плюс короткий README примера.**
3. **История — один запрос к API**, сквозной сценарий живого приложения, а
   не каталог возможностей.
4. **Скриншоты постановочные, и картинки — источник истины.** Код в
   `bin/readme_examples/` самостоятельным никогда не был: владелец
   комментировал лишнее руками и снимал кадр. Уборка их не трогает;
   автоматизация съёмки — отдельная работа, здесь её нет.

## Раскладка после правки

```
tool/                          новое, в .pubignore
  playground.dart              бывший example/bin/example.dart
  playground_data.dart         бывший example/lib/data.dart

example/
  README.md                    переписан
  pubspec.yaml                 description и зависимости почищены
  analysis_options.yaml        без изменений
  example.dart                 новый главный, self-contained
  bin/
    file_storage_example.dart  без изменений
    readme_examples/…          без изменений
  lib/
    readme_examples/…          без изменений
```

Удаляются: `example/CHANGELOG.md`, пустой `example/example/`,
`example/lib/data.dart` (уезжает в `tool/`), `example/bin/example.dart`
(уезжает туда же).

`.pubignore` в корне получает строку `tool/` — рядом с `docs/`, `scripts/`
и `screenshots/`, которые там уже есть.

Перенос кухни ничего за собой не рвёт: `lib/data.dart` импортирует **только**
`bin/example.dart` — проверено. В корневом пакете кухня компилируется: ей
нужны `team_logger`, `stack_trace` (обычная зависимость) и `format`
(dev-зависимость). При переносе правятся два импорта:
`package:example/data.dart` → `playground_data.dart` (относительный, файлы
рядом), а `package:team_logger/team_logger.dart` остаётся — пакет вправе
импортировать сам себя по `package:`-URI из `tool/`.

## Главный пример: `example/example.dart`

**Self-contained, и это принципиально.** pub.dev рендерит ровно один файл;
если половина истории лежит в `lib/`, читатель вкладки Example видит
импорты, за которыми не может пройти. Поэтому настройка, модели и сама
история — в одном файле, ~130 строк.

Скелет (идиомы `LoggableData` сверены с существующими моделями примера):

```dart
import 'package:team_logger/team_logger.dart';

// Логгер приложения: один принтер, одна строка — номер, уровень, время,
// пространство имён, trace id, сообщение. Теги уходят к правому краю.
final log = Logger('app')
  ..level = LogLevels.all
  ..publisher = ConsoleLogPrinter(
    theme: LogMainTheme.defaultActiveTheme,
    rows: const [
      LogRow(
        maxLength: 100,
        children: [
          LogNum(),
          LogLevelName.short(),
          LogTime.onlyTime(),
          LogPath(),
          LogTraceId(),
          LogMessage(),
        ],
        tail: [LogTags()],
      ),
    ],
  );

// Подлоггер HTTP-слоя: путь `app/api`, и каждый его лог несёт тег `http`.
final api = log.createChild(name: 'api', tags: {'http'});

Future<void> main() async {
  // Маскирование — глобальное и по значениям: правилу предлагают каждое
  // значение на пути в вывод, вместе с именем, под которым оно печатается.
  Loggable.sanitizer =
      (ctx) => ctx.name == 'authorization' ? 'Bearer ***' : ctx.value;

  log.i('Application started', data: {'version': '1.2.3', 'env': 'demo'});

  // Всё, что залогировано внутри, подхватывает trace id — на любой глубине
  // и через любые await.
  await log.trace(TraceId.auto('req'), () async {
    api.d(
      'POST /addresses',
      data: LoggableMultiData({'HEADERS': _headers, 'BODY': _body}),
    );

    final address = await _fetchAddress();
    api.i('200 OK', data: address);

    try {
      await _fetchAddress(fail: true);
    } on Object catch (error, stackTrace) {
      api.e('request failed', error: error, stackTrace: stackTrace);
    }
  });

  log.i('Done');
}
```

Данные и поддельный запрос:

```dart
const _headers = {
  'content-type': 'application/json',
  'authorization': 'Bearer eyJhbGciOiJub25lIn0.super-secret.signature',
  'accept-language': 'en',
};

const _body = {
  'point': {'lat': 12.345678, 'lon': 23.456789},
  'radius': 500,
};

Future<Address> _fetchAddress({bool fail = false}) async {
  await Future<void>.delayed(const Duration(milliseconds: 50));
  if (fail) throw const FormatException('unexpected end of input');

  return const Address(
    id: 1704,
    name: 'Cake Lab',
    street: 'Baker Street, 91',
    point: Point(12.349473, 23.439319),
    distance: 1240,
  );
}
```

Модели — единственное, что класс обязан написать, это
`collectLoggableData`:

```dart
final class Address with Loggable {
  final int id;
  final String name;
  final String street;
  final Point point;
  final int distance;

  const Address({
    required this.id,
    required this.name,
    required this.street,
    required this.point,
    required this.distance,
  });

  @override
  void collectLoggableData(LoggableData data) => data
    ..name = '$Address'
    ..prop('id', id)
    ..prop('name', name)
    ..prop('street', street)
    ..prop('point', point)
    ..prop(
      'distance',
      distance,
      units: 'm',
      view: LoggableMultiView([
        LoggableView(distance, units: 'm'),
        LoggableView(distance / 1000, units: 'km'),
      ]),
    );
}

final class Point with Loggable {
  final double lat;
  final double lon;

  const Point(this.lat, this.lon);

  @override
  void collectLoggableData(LoggableData data) => data
    ..name = 'Point'
    ..showName = false
    ..round('lat', lat, precision: 5, showName: false)
    ..round('lon', lon, precision: 5, showName: false);
}
```

### Почему санитайзер, а не трансформер

В первом наброске маскирование было трансформером — это была ошибка
выбора инструмента. Трансформер работает с логом целиком, и чтобы затереть
одно значение внутри `HEADERS`, ему пришлось бы переписать весь
`Log.data`. Санитайзер сделан ровно для этого случая: ему предлагают
каждое значение с его именем и путём. В примере это одна строка, и она
показывает то, чем пакет отличается от прочих.

### Чего в примере не будет

Сознательно: файлового хранилища (у него свой
`bin/file_storage_example.dart`), трансформера (два механизма маскирования
в одном примере — перебор, в README они разведены), форматирования чисел
(нишевая ручка, к тому же требующая зависимости у читателя), всех ручек
коллекций, дампа тем, циклических ссылок, not-loggable конвертеров. Всё
это — в `tool/playground.dart` и в README.

## `example/README.md`

10–15 строк вместо болванки:

- что показывает пример — одним абзацем, перечислением сцен;
- как запустить: `cd example && dart pub get && dart run example.dart`;
- карта остального: `bin/file_storage_example.dart` — файловое хранилище;
  `bin/readme_examples/` — код разделов основного README, из которого
  **вручную** набираются кадры для картинок (сами картинки — источник
  истины, код самостоятельным не задумывался).

`description` в `example/pubspec.yaml` — вместо «A sample command-line
application» сказать, что это примеры к `team_logger`.

## Зависимости примера

Проверено grep'ом по `bin/` и `lib/`:

| зависимость | кто пользуется | решение |
| --- | --- | --- |
| `ansi_escape_codes` | `bin/readme_examples/themes.dart` | оставить |
| `format` | `lib/readme_examples/default_log.dart` | оставить |
| `freezed_annotation` | `lib/readme_examples/loggable/person3.dart` | оставить |
| `build_runner`, `freezed` | генерация `person3.freezed.dart` | оставить |
| `lints` | `analysis_options.yaml` | оставить |
| `equatable` | никто | **убрать** |
| `path` | никто | **убрать** |
| `stack_trace` | только `bin/example.dart` (уезжает в `tool/`) | **убрать** |
| `test` | никто, каталога `test/` нет | **убрать** |

## Границы: чего не делаем

- `bin/readme_examples/` и `lib/readme_examples/` не трогаем вовсе.
- Скриншоты не переснимаем: они постановочные и сейчас актуальны.
- Автоматизацию съёмки не делаем — отдельная работа со своей спекой.
  Набросок для неё: кадр становится единицей кода (файл или именованная
  сцена на картинку) плюс манифест «имя PNG → команда» и скрипт, который
  прогоняет весь манифест; после этого источник истины переезжает из PNG в
  код. Сцен около двадцати.
- Основной `README.md` пакета не трогаем.

## Проверки

- `dart analyze` в корне — теперь он видит `tool/`, там должно быть чисто.
- `dart analyze` в `example/`.
- Запускается всё: `example/example.dart`,
  `example/bin/file_storage_example.dart`, восемь
  `example/bin/readme_examples/*.dart`, `tool/playground.dart` из корня.
- `dart test` и `dart format .` в корне — не должны пострадать.
- `dart pub publish --dry-run`: в архиве **нет** `tool/`, **есть**
  `example/example.dart`, **нет** `example/CHANGELOG.md`.
