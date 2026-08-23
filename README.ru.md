# Team Logger

> **Перевод `README.md` для владельца и агентов. В pub-архив не попадает
> (отдельная строка в `.pubignore`) и на pub.dev не публикуется.**
> Источник истины — английский `README.md`; этот файл обязан меняться
> вместе с ним (см. `docs/conventions.md`).

[![Pub Version](https://img.shields.io/pub/v/team_logger)](https://pub.dev/packages/team_logger)
[![Dart SDK](https://img.shields.io/badge/dart-3.6.0-blue.svg)](https://dart.dev)
[![Flutter](https://img.shields.io/badge/flutter-3.27.0-blue.svg)](https://flutter.dev)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)

Гибко настраиваемая библиотека структурного логирования с поддержкой
трассировки — для больших команд, сложных приложений и больших объёмов логов
в Dart и Flutter.

`team_logger` даёт вложенные логгеры-неймспейсы, автоматическую трассировку
через зоны, собственное форматирование объектов (`Loggable`), инлайновый
BBCode и настраиваемые темы оформления.

---

## Возможности

* **Цвета и динамические темы**: оформление каждого элемента лога
  ANSI-кодами, готовые палитры (оттенки серого или RGB) и динамический сдвиг
  цвета скобок по глубине вложенности, чтобы структура читалась.
* **Активные и неактивные темы**: отдельные правила оформления для активных
  и фоновых логов — фон остаётся видимым, но малоконтрастным, а важное
  подсвечивается.
* **Построчная раскладка консоли**: свой формат лога из модульных
  компонентов строки — порядковый номер, имя уровня, время, trace ID, теги,
  путь неймспейса, сообщение.
* **Трассировка через зоны**: trace ID автоматически распространяется по
  асинхронным путям исполнения средствами Dart Zones (`log.trace()`), так что
  контекст не нужно передавать параметрами вручную.
* **Своё форматирование объектов (`Loggable`)**: примешайте `Loggable` к
  классу и опишите, как в логах выглядят его свойства, единицы измерения,
  форматы чисел и коллекции.
* **Конвертеры типов**: собственные конвертеры форматирования для сторонних
  классов, которые не реализуют `Loggable` напрямую.
* **BBCode в консоли**: разметка прямо в сообщении — стандартные и
  пользовательские теги вроде `[success]...[/success]` или `[b]bold[/b]`,
  компилируемые в ANSI-последовательности.
* **Логгеры-неймспейсы**: дочерние логгеры через `createChild()` образуют
  структурную иерархию путей (например, `app/network/polling`).
* **Кольцевой буфер в памяти (`LogStorage`)**: хранит фиксированное число
  последних логов для диагностического экспорта или просмотра внутри
  приложения.
* **Файлы логов (`FileLogStorage`)**: пишет логи на устройство в формате
  JSON Lines, по сессии на запуск, с ротацией и бюджетами хранения на чанк,
  на сессию и на все сессии сразу. Сессии можно перечислить, прочитать и
  слить в один gzip-файл, чтобы отправить для диагностики.

---

## Оглавление

- [Быстрый старт](#быстрый-старт)
- [Подробно](#подробно)
  - [1. Раскладка сообщения](#1-раскладка-сообщения)
  - [2. Цвета и динамические темы](#2-цвета-и-динамические-темы)
  - [3. Активный и неактивный режимы](#3-активный-и-неактивный-режимы)
  - [4. BBCode-теги](#4-bbcode-теги)
  - [5. Вывод данных](#5-вывод-данных)
  - [6. Форматирование сложных объектов](#6-форматирование-сложных-объектов)
  - [7. Трассировка (`TraceId`)](#7-трассировка-traceid)
  - [8. Кольцевой буфер (`LogStorage`)](#8-кольцевой-буфер-logstorage)
  - [9. Запись логов в файлы (`FileLogStorage`)](#9-запись-логов-в-файлы-filelogstorage)
  - [10. Редактирование логов (`Logger.transformer` и `Loggable.sanitizer`)](#10-редактирование-логов-loggertransformer-и-loggablesanitizer)
  - [11. Недоверенный текст и вывод в терминал](#11-недоверенный-текст-и-вывод-в-терминал)
- [Лицензия](#лицензия)

---

## Быстрый старт

Пример ниже настраивает тему, собирает свою раскладку строки консоли,
создаёт дочерние логгеры и выполняет код в зоне трассировки.

```dart
import 'package:team_logger/team_logger.dart';

// Инициализация логгера со своей раскладкой
final log = Logger('app')
  ..level = LogLevels.all
  ..publisher = ConsoleLogPrinter(
    theme: LogMainTheme.defaultActiveTheme,
    rows: const [
      LogRow(
        maxLength: 120,
        children: [
          LogNum(),
          LogLevelName.short(),
          LogTime.onlyTime(),
          LogPath(),
          LogTraceId(),
          LogMessage(),
        ],
        tail: [
          LogTags(),
        ],
      ),
    ],
  );

Future<void> main() async {
  log.i('App started');

  // Дочерние логгеры
  final paymentLog = log.createChild(name: 'payment');

  // Внутри зоны трассировки TraceId подхватывается и выводится сам
  await log.trace(TraceId.auto('payment'), () async {
    paymentLog.i('Initiating payment request...');
    await payment(10, 'USD');
    paymentLog.i('Payment processed successfully');
  });
}

Future<void> payment(int amount, String currency) async {
  final networkLog = log.createChild(name: 'network', tags: {'http'});

  networkLog.d(
    'https://api.example.com/[b]v1/payment[/b]',
    tags: ['request'],
    data: {'amount': amount, 'currency': currency},
  );

  // ... вызов api ...

  networkLog.d(
    '[success][200 OK][/success] https://api.example.com/[b]v1/payment[/b]',
    tags: ['response'],
    data: {'payment_id': 123},
  );
}
```

Вывод:

![Быстрый старт](screenshots/quick_start_1.png)

При фильтрации по порядковому номеру показываются **все строки**, входящие в
сообщение:

![Быстрый старт. Фильтр по номеру](screenshots/quick_start_2.png)

При фильтрации по trace ID показываются все сообщения, отправленные внутри
`log.trace`, и **все строки** этих сообщений:

![Быстрый старт. Фильтр по trace ID](screenshots/quick_start_3.png)

При фильтрации по тегу показываются все сообщения с тегом `#http` и **все
строки** этих сообщений:

![Быстрый старт. Фильтр по тегу](screenshots/quick_start_4.png)

---

## Подробно

### 1. Раскладка сообщения

Раскладка вывода настраивается параметром `rows` у `ConsoleLogPrinter`. Он
принимает список `LogRow`.

`LogRow` состоит из двух необязательных списков: `children` и `tail`.
- `children`: элементы, составляющие основное тело сообщения.
- `tail`: элементы, добавляемые справа от тела, обычно теги.

И `children`, и `tail` принимают список `LogBlock`. `LogBlock` — интерфейс
одного элемента лога: порядкового номера, имени уровня, времени, trace ID,
пути или сообщения.

```dart
import 'package:team_logger/team_logger.dart';

final log = Logger('app')
  ..level = LogLevels.all
  ..publisher = ConsoleLogPrinter(
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
        tail: [
          LogTags(),
        ],
      ),
    ],
  );

log.d(
  'User info',
  traceId: TraceId.auto('user'),
  data: {
    'firstName': 'Alex',
    'lastName': 'Brown',
    'age': 30,
    'sex': 'male',
    'children': [
      {'name': 'Mary', 'age': 5},
      {'name': 'Bob', 'age': 2},
    ],
  },
);
```

![Раскладка сообщения](screenshots/layout_1.png)

У `LogBlock` есть несколько реализаций для разных элементов лога:
- `LogNum()`: порядковый номер сообщения.
- `LogLevelName.full()`: полное имя уровня.
- `LogLevelName.short()`: короткое имя уровня.
- `LogTime.dateTime()`: дата и время сообщения.
- `LogTime.iso8601()`: дата и время в формате ISO 8601.
- `LogTime.onlyTime()`: время сообщения.
- `LogPath()`: путь сообщения.
- `LogTraceId()`: trace ID сообщения.
- `LogMessage()`: само сообщение.
- `LogTags()`: теги сообщения.

Параметр `maxLength` ограничивает ширину сообщения. Если сообщение шире
`maxLength`, оно переносится на следующую строку.

Ширина считается в **колонках терминала**, а не в символах и не в UTF-16 code
units: `世` и большинство эмодзи занимают две колонки, `e` с комбинирующим
акцентом — одну, а текст никогда не режется внутри графемного кластера.
Кластер, не влезающий в остаток строки, целиком переносится на следующую,
поэтому строка может оказаться на колонку уже `maxLength` — но глиф не будет
разрезан пополам.

`LogMessage` занимает всё оставшееся место в строке. Если нужно поместить
что-то правее `LogMessage`, используйте параметр `tail` (как сделано для
`LogTags`).

#### Одна строка

Сообщение можно выводить одной строкой (переносить будет сам терминал):

```dart
final log = Logger('app')
  ..level = LogLevels.all
  ..publisher = ConsoleLogPrinter(
    rows: const [
      LogRow.singleLine(
        children: [
          // ...
        ],
      ),
    ],
  );
```

![Одна строка](screenshots/layout_2.png)

Однострочный лог тяжелее читать глазами, зато он занимает одну строку буфера
консоли IDE. Это важно, когда у буфера есть лимит (10 000 строк для
VSCode/Antigravity), а логов много. Такие строки и фильтровать проще: при
фильтрации IDE покажет только строки с искомым текстом, а не всё сообщение
целиком, если оно многострочное.

#### Фильтрация логов

`team_logger` немного облегчает поиск и фильтрацию, дублируя ключевую
информацию сообщения в каждой строке, но скрывает её, чтобы она не мешала
читать логи:

```dart
final theme = LogMainTheme.defaultActiveTheme.copyWith(
  hiddenStyle: Styles.rgb050,
);
```

![Фильтрация логов](screenshots/layout_3.png)

Так вы всегда сможете отфильтровать по порядковому номеру, уровню, времени,
пути неймспейса, trace ID и тегам.

При фильтрации по содержимому сообщения или данных всё сообщение вы всё равно
не увидите. Но, найдя нужный лог, всегда можно отфильтровать по его
порядковому номеру. Помните: даже если номера не видно, он там есть —
выделите его мышью, скопируйте и вставьте в поле фильтра.

Некоторые IDE не поддерживают ANSI-стиль hidden (Android Studio). Тогда цвет
`hiddenStyle` придётся подобрать под цвет фона отладочной консоли вашей IDE.

#### Зачем нужны строки

Когда в логе есть стек вызовов, по умолчанию он выводится внутри
`LogMessage`, прямо под сообщением и строго в отведённом сообщению месте:

```dart
void someOperation() {
  try {
    calcResult();
  } on Object catch (error, stackTrace) {
    log.d('Operation failed', error: error, stackTrace: stackTrace);
  }
}

int calcResult() {
  return 1 ~/ 0;
}

// ...

someOperation();
```

![Стек внутри сообщения](screenshots/layout_4.png)

Стеку может понадобиться больше места. Тогда лучше вынести его в отдельную
строку:

```dart
final log = Logger('app')
  ..level = LogLevels.all
  ..publisher = ConsoleLogPrinter(
    rows: [
      const LogRow(
        maxLength: 100,
        children: [
          LogNum(),
          LogLevelName.short(),
          LogTime.onlyTime(),
          LogPath(),
          LogTraceId(),
          LogMessage(showStackTrace: false), // убираем стек из сообщения
        ],
        tail: [LogTags()],
      ),
      LogRow(
        when: (log) => log.stackTrace != null,
        maxLength: 100,
        children: [
          // Убираем всё лишнее, оставляя только порядковый номер, но
          // визуально его прячем (по умолчанию первая строка видима).
          LogNum(hidden: true),
          LogStackTrace(),
        ],
        // Теги оставим, но спрячем.
        tail: [LogTags(hidden: true)],
      ),
    ],
  );
```

![Отдельная строка для стека](screenshots/layout_5.png)

#### LogConstraints

Ограничения размера можно задать любому элементу:

```dart
final log = Logger('app')
  ..level = LogLevels.all
  ..publisher = ConsoleLogPrinter(
    rows: [
      LogRow(
        maxLength: 100,
        children: [
          LogNum(
            // Резервируем место под нумерацию
            constraints: LogConstraints(min: 7),
            // Выравниваем вправо
            textAlign: LogTextAlign.right,
          ),
          LogLevelName.short(),
          LogTime.onlyTime(),
          LogPath(
            // Место под путь неймспейса растёт по мере поступления данных,
            // но рост не ограничиваем
            constraints: LogConstraints.growable(max: 20),
          ),
          LogTraceId(),
          LogMessage(),
        ],
        tail: [LogTags()],
      ),
    ],
  );
```

![LogConstraints](screenshots/layout_6.png)

#### Куда уходит вывод

`ConsoleLogPrinter` пишет через параметр `output`, по умолчанию — `print`.
Замените его, чтобы строки уходили в другое место: в `log()` из
`dart:developer` во Flutter-приложении, в буфер в тесте, в сокет, в файл:

```dart
import 'dart:developer' as developer;

final log = Logger('app')
  ..level = LogLevels.all
  ..publisher = ConsoleLogPrinter(
    rows: const [/* ... */],
    output: (line) => developer.log(line, name: 'app'),
  );
```

`output` можно заменить в любой момент, и замена действует со следующей
строки сразу для всех уровней — удобно, когда sink подменяют в тесте.

**Он вызывается на каждую отрисованную строку, а не на каждый лог.**
Сообщение с переносом стоит одного вызова на строку, а раскладка из двух
`LogRow` — двух:

```dart
log.i('a very long message that will definitely wrap across lines');
// (2) a very long message that -
// (2) will definitely wrap acro-
// (2) ss lines
```

Три вызова, а не один. Поэтому же каждая строка повторяет порядковый номер,
уровень, время и остальное — скрыто по умолчанию, см. «Фильтрация логов»
выше: строка обязана быть самодостаточной, ведь тот, кто её принимает, может
проставить ей время, префикс или переставить её независимо от соседей.

Значит, sink на `developer.log` создаёт по записи на *строку*. Сигнала о
том, где строки лога кончились, нет, и `output` — неподходящий шов, если
нужна одна запись на лог: реализуйте `CustomLogPublisher` и рендерите лог
сами.

Если приёмник не отображает ANSI-коды, используйте вместе с ним
`LogMainTheme.noColors` (см. «Без цветов» ниже), чтобы текст приходил
чистым, а не с неотрисованными кодами.

**На iOS это не вопрос вкуса.** `print` там калечит escape-коды: байт `ESC`
приходит печатным текстом, поэтому цветная строка попадает в консоль
`flutter run` и в лог устройства как мусор `\^[[31m…` вместо цвета. Выхода
два, и они различаются тем, куда попадают логи:

- `LogMainTheme.noColors` — чистый текст и в консоли `flutter run`, и в логе
  устройства;
- `log()` из `dart:developer` — escape-коды доходят нетронутыми, но вывод
  уходит в VM service, то есть в DevTools или в отладочную консоль IDE. Ни в
  терминал `flutter run`, ни в системный лог устройства он не попадает
  вовсе.

### 2. Цвета и динамические темы

`team_logger` поддерживает цветной и структурированный вывод в консоль через
пакет [ansi_escape_codes](https://pub.dev/packages/ansi_escape_codes).
`Style`, `NoStyle`, `Color16`, `Color256` и таблица готовых стилей `Styles`
(`Styles.red`, `Styles.rgb050`, `Styles.bold`) реэкспортируются, так что для
оформления прямая зависимость от него не нужна.

#### Цветовые темы и палитры

Можно взять тему по умолчанию:

```dart
final theme = LogMainTheme.defaultActiveTheme;
final log = Logger('app')
    ..level = LogLevels.all
    ..publisher = ConsoleLogPrinter(
      theme: theme,
      // ...
    );
```

Или настроить её под себя готовыми палитрами:

* **Палитры оттенков серого**: от `LogThemeData.gray5` до
  `LogThemeData.gray20` — серые тона под тёмный или светлый фон терминала.
* **RGB-палитры**: конфигурации, названные по своим RGB-значениям, например
  `rgb411` (красный для ошибок), `rgb431` (золотой для предупреждений) и
  `rgb234` (синий для info).

```dart
final theme = LogMainTheme.defaultActiveTheme.copyWith(
  info: LogThemeData.rgb122,
);
```

Или собрать свою палитру:

```dart
final theme = LogMainTheme.defaultActiveTheme.copyWith(
  info: LogThemeData.seed(
    normal: Styles.rgb030,
    emphasis: Styles.rgb252,
    dim: Styles.rgb020,
    punctuation: Styles.rgb550,
    // ...
  ),
);
```

![Цветовые темы и палитры](screenshots/themes_1.png)

#### Динамический сдвиг цвета по глубине (`LogDepthTheme`)

Чтобы вложенные коллекции (мапы, списки, свои объекты) читались лучше,
`team_logger` умеет менять цвет в зависимости от глубины. Если задать список
`LogDepthTheme`, цвета скобок, пунктуации и описаний сдвигаются по уровню
вложенности:

```dart
final theme = LogMainTheme.defaultActiveTheme.copyWith(
  info: LogThemeData.seed(
    // ...
    depthThemes: [
      LogDepthTheme.yellow,
      LogDepthTheme.orange,
      LogDepthTheme.magenta,
      LogDepthTheme.red,
    ],
  ),
);
```

Или так:

```dart
final theme = LogMainTheme.defaultActiveTheme.copyWith(
  info: LogThemeData.seed(
    // ...
    depthThemes: [
      LogDepthTheme(
        brackets: Styles.gray20,
        punctuation: Styles.gray20,
        description: Styles.gray20,
      ),
      LogDepthTheme(
        brackets: Styles.gray16,
        punctuation: Styles.gray16,
        description: Styles.gray16,
      ),
      LogDepthTheme(
        brackets: Styles.gray12,
        punctuation: Styles.gray12,
        description: Styles.gray12,
      ),
      LogDepthTheme(
        brackets: Styles.gray8,
        punctuation: Styles.gray8,
        description: Styles.gray8,
      ),
    ],
  ),
);
```

![Динамический сдвиг цвета по глубине](screenshots/themes_2.png)

#### Без цветов

Чтобы убрать ANSI-коды, используйте `LogMainTheme.noColors`:

```dart
final noColorsTheme = LogMainTheme.noColors;
log = Logger('app')
    ..level = LogLevels.all
    ..publisher = ConsoleLogPrinter(
      theme: LogMainTheme.noColors,
      // ...
    );
```

![Без цветов](screenshots/themes_3.png)

---

### 3. Активный и неактивный режимы

Чтобы вывод в консоль оставался чистым, но контекст исполнения не терялся,
`team_logger` поддерживает активный и неактивный режимы оформления:

* **Активная тема** (`theme`): применяется к логам, попавшим под активные
  неймспейсы, порог уровня, активные группы трассировки или теги.
* **Неактивная тема** (`inactiveTheme`): применяется к остальным логам. Они
  печатаются малоконтрастными цветами — фоновый контекст остаётся видимым и
  не мешает читать важное.

Любой активный фильтр требует `inactiveTheme`; неверная комбинация бросает
`ArgumentError` при создании принтера.

Если задать `inactiveTheme`, все логи автоматически становятся неактивными:

```dart
final log = Logger('app')
  ..level = LogLevels.all
  ..publisher = ConsoleLogPrinter(
    theme: LogMainTheme.defaultActiveTheme,
    inactiveTheme: LogMainTheme.defaultInactiveTheme, // готовая приглушённая тема
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
```

![Неактивная тема](screenshots/active_1.png)

#### Активация по уровню

Логи можно активировать по разным признакам. Например, по минимальному
уровню:

```dart
final log = Logger('app')
  ..level = LogLevels.all
  ..publisher = ConsoleLogPrinter(
    theme: LogMainTheme.defaultActiveTheme,
    inactiveTheme: LogMainTheme.defaultInactiveTheme,
    activeMinLevel: LogLevels.info,
    // ...
  );
```

Или по произвольному набору уровней:

```dart
final log = Logger('app')
  ..level = LogLevels.all
  ..publisher = ConsoleLogPrinter(
    theme: LogMainTheme.defaultActiveTheme,
    inactiveTheme: LogMainTheme.defaultInactiveTheme,
    activeLevels: {LogLevels.info, LogLevels.warning, LogLevels.error, LogLevels.critical},
    // ...
  );
```


![Активация по уровню](screenshots/active_2.png)

#### Активация по неймспейсу

```dart
final log = Logger('app')
  ..level = LogLevels.all
  ..publisher = ConsoleLogPrinter(
    theme: LogMainTheme.defaultActiveTheme,
    inactiveTheme: LogMainTheme.defaultInactiveTheme,
    activeNamespaces: {'net'},
    // ...
  );
```

![Активация по неймспейсу](screenshots/active_3.png)

#### Активация по trace ID

```dart
final log = Logger('app')
  ..level = LogLevels.all
  ..publisher = ConsoleLogPrinter(
    theme: LogMainTheme.defaultActiveTheme,
    inactiveTheme: LogMainTheme.defaultInactiveTheme,
    activeTraceGroups: {'user', 'net'},
    // ...
  );
```

![Активация по trace ID](screenshots/active_4.png)

#### Активация по тегам

```dart
final log = Logger('app')
  ..level = LogLevels.all
  ..publisher = ConsoleLogPrinter(
    theme: LogMainTheme.defaultActiveTheme,
    inactiveTheme: LogMainTheme.defaultInactiveTheme,
    activeTags: {'success'},
    // ...
  );
```

![Активация по тегу](screenshots/active_5.png)

#### Активация колбэком

```dart
final log = Logger('app')
  ..level = LogLevels.all
  ..publisher = ConsoleLogPrinter(
    theme: LogMainTheme.defaultActiveTheme,
    inactiveTheme: LogMainTheme.defaultInactiveTheme,
    isLogActive: (log) => log.hasData,
    // ...
  );
```

![Активация колбэком](screenshots/active_6.png)

#### Как этим пользоваться

Активация и деактивация логов полезна только тогда, когда каждый разработчик
настраивает её под себя — чтобы временно отсеять чужие логи и сосредоточиться
на своих.

Но `team_logger` не поддерживает динамическую активацию и деактивацию: все
условия активации задаются в момент создания корневого логгера. Возникает
резонный вопрос: как тогда применять это в большой команде?

**Ответ:** через собственное окружение разработчика. Вот как это делается.

##### а) заведите класс с личными настройками окружения разработчика:

```dart
final MyDevEnvironment myDevEnvironment = MyDevEnvironment._();

// Настройки окружения разработчика.
final class MyDevEnvironment {
  MyDevEnvironment._();

  bool logSingleLine = false;
  int logLength = 120;
  int? logMaxLines;
  bool logAlwaysIsActive = false;
  bool Function(Log log)? logIsActive;
  int logActiveMinLevel = LogLevels.off;
  Set<int> logActiveLevels = <int>{};
  Set<String> logActiveNamespaces = <String>{};
  Set<String> logActiveTraceGroups = <String>{};
  Set<String> logActiveTags = <String>{};
}
  ```

##### б) создайте `main_dev.dart`:

```dart
import 'main.dart' as production;

void main() {
  myDevEnvironment
    ..logLength = 130
    ..logMaxLines = 20
    ..logActiveNamespaces = {'app', 'network'}
    ..logActiveTraceGroups = {'events'};

  production.main();
}
```

##### в) настройте IDE запускать `main_dev.dart` вместо `main.dart`:

Пример для VSCode/Antigravity:

```json
// .vscode/launch.json
{
    // ...
    "configurations": [
        {
            "name": "My awesome program",
            "request": "launch",
            "type": "dart",
            "program": "lib/main_dev.dart",
            // ...
        },
        // ...
    ]
}
```

А CI/CD пусть продолжает использовать `main.dart`.

##### г) добавьте `main_dev.dart` в `.gitignore`:

`main_dev.dart` должен остаться личным файлом каждого разработчика, поэтому в
систему контроля версий он не добавляется.

Теперь каждому разработчику придётся создать свою версию `main_dev.dart` со
своими настройками.

Или этот процесс можно автоматизировать.

##### д) создайте шаблон `main_dev.template.dart` для `main_dev.dart`:

```dart
// template: Do not change this file directly. This file is used as a template to generate `main_dev.dart`

import 'main.dart' as production;

void main() {
  myDevEnvironment
    ..logLength = 120
    ..logMaxLines = 20
    ..logActiveNamespaces = {'app', 'network'}
    ..logActiveTraceGroups = {'events'};

  production.main();
}
```

##### е) заведите `preLaunchTask`:

```json
// .vscode/launch.json
{
    // ...
    "configurations": [
        {
            "name": "My awesome program",
            "preLaunchTask": "initDevEnvironment",
            // ...
        },
        // ...
    ]
}

// .vscode/tasks.json
{
    // ...
    "tasks": [
        {
            "label": "initDevEnvironment",
            "type": "shell",
            "command": "[[ -e lib/main_dev.dart ]] || cp lib/main_dev.template.dart lib/main_dev.dart && sed -i '' '/^\\/\\/ template:/d' lib/main_dev.dart",
            "presentation": {
                "echo": true,
                "reveal": "silent",
                "focus": false,
                "panel": "shared",
                "showReuseMessage": true,
                "clear": false
            }
        },
        // ...
    ]
}
```

Эта задача выполнится перед каждой сборкой приложения и при необходимости
создаст `main_dev.dart`.

---

### 4. BBCode-теги

У `LogMainTheme` есть параметр `messageFormatter` для форматирования
сообщений. По умолчанию это `BbCodeFormatter`.

#### Стандартные теги

`BbCodeFormatter` разбирает BBCode-теги в сообщениях и применяет стили,
заданные в теме:

```dart
log.d('This is a [b]bold[/b] text');
log.d('This is a [success]success[/success] text');
log.d('This is a [warning]warning[/warning] text within the not-warning text');
log.d('This is a [error]error[/error] text within the not-error text');
log.d('This is a [signal]signal[/signal] to get attention');
```

Теги можно вкладывать, в том числе одноимённые. Закрывающий тег закрывает
только последний открытый; неизвестные, незакрытые и несовпадающие теги
остаются литералами.

![BBCode-теги](screenshots/bbcode_1.png)

#### Свои теги

Можно добавить собственные теги:

```dart
final theme = LogMainTheme.defaultActiveTheme.copyWith(
  messageStyles: {
    'b': LogStyle(Styles.bold),
    'i': LogStyle(Styles.italic),
    's': LogStyle(Styles.strikethrough),
    'u': LogStyle(Styles.underline),
  },
);

log.d('This is a [b]bold[/b] text', theme: theme);
log.d('This is a [i]italic[/i] text', theme: theme);
log.d('This is a [s]strikethrough[/s] text', theme: theme);
log.d('This is a [u]underline[/u] text', theme: theme);
```

![Пользовательские теги](screenshots/bbcode_2.png)

#### Ленивый стиль

Если стиль зависит от текущих настроек темы, используйте `LogLazyStyle`:

```dart
final theme = LogMainTheme.defaultActiveTheme.copyWith(
  messageStyles: {
    'fatal': LogLazyStyle((theme) => theme.main.critical.data.normal),
  },
);

log.d('This is [fatal]a fatal error[/fatal]');
```

![LogLazyStyle](screenshots/bbcode_3.png)

#### Без цветов

При переключении на тему `LogMainTheme.noColors` теги остаются в тексте
сообщения, потому что стилей сообщения в этой теме нет:

```dart
final theme = LogMainTheme.noColors;
```

![Без цветов](screenshots/bbcode_4.png)

Чтобы теги убрались, добавьте их в `messageStyles`:

```dart
final theme = LogMainTheme.noColors.copyWith(
  messageStyles: const {
    'b': LogNoStyle(),
    'i': LogNoStyle(),
    's': LogNoStyle(),
    'u': LogNoStyle(),
  },
);
```

![Без цветов и без тегов](screenshots/bbcode_5.png)

Для стандартных тегов есть готовая тема: `LogMainTheme.noColorsNoTags`.

```dart
final theme = LogMainTheme.noColorsNoTags;
```

![Без цветов и без тегов 2](screenshots/bbcode_6.png)

---

### 5. Вывод данных

#### Параметр data

Обычно вывод данных в лог выглядит примерно так:

```dart
const person = {'firstName': 'John', 'lastName': 'Smith', 'age': 42};
log.d('Person: $person');
```

`team_logger` предлагает другой подход:

```dart
log.d('Person', data: person);
```

![Параметр data](screenshots/data_1.png)

Это не только даёт более читаемое сообщение в консоли, оформленное
ANSI-кодами, но и упрощает отправку данных в базу или в аналитику.

#### Ленивые сообщения и данные

Лог, который вы не печатаете, не должен ничего стоить. `message`, `data` и
`tags` принимают либо значение, либо замыкание, и замыкание вызывается только
если лог вообще создаётся:

```dart
log.d(
  () => 'Report for ${expensiveSummary()}',
  data: () => buildDiagnostics(),
  tags: () => collectTags(),
);
```

При включённом уровне печатается ровно то же, что и при передаче значений.
При выключенном не выполняется ни одно из трёх замыканий — ни сводка, ни
диагностика, ни теги, — и лог стоит одного сравнения.

Это тот же аргумент, что у параметра `data`, но на шаг дальше:
`log.d('Person: $person')` собирает строку до того, как её увидит логгер, и
даже `log.d('Person', data: person)` собирает `person` на месте вызова.
Замыкание откладывает работу до момента, когда она точно нужна.

**Решает `level` самого логгера и ничто другое.** Фильтры, живущие на
публишере, работают позже — с логом, который уже существует:

```dart
log.level = LogLevels.all;          // замыкание выполнится
log.publisher = ConsoleLogPrinter(
  activeMinLevel: LogLevels.error,  // это лишь приглушит его потом
  // ...
);
```

То же касается `FileLogStorage.minLevel` и `Logger.transformer`: к моменту,
когда у них появляется право голоса, замыкание уже вызвано. Не дать работе
выполниться может только поднятие уровня самого логгера.

Исключение, брошенное внутри такого замыкания, не глотается — оно доходит до
строки, которая логировала:

```dart
log.i(() => throw StateError('boom')); // бросит StateError в этой строке
```

В остальном ленивые значения — обычные значения. Что вернуло замыкание, то и
приняла бы сама по себе: `data` проходит то же форматирование, те же лимиты и
те же правила редактирования, что и любое другое значение, а `tags` принимает
одну строку или любой их iterable.

#### Глубоко вложенные объекты

Цвет скобок динамически меняется в зависимости от уровня вложенности, чтобы
структуру было легче понять:

```dart
log.d(
  'deeply nested',
  data: {
    'deeply': {
      'nested': {'object': person},
    },
  },
);
```

![Глубоко вложенные объекты](screenshots/data_2.png)

#### Секции данных

Данные можно разделить на секции:

```data
log.d(
  'Add new user',
  data: LoggableMultiData({
    'HEADERS': {'Content-Type': 'application/json'},
    'BODY': person,
  }),
);
```

![Секции данных](screenshots/data_3.png)

#### Обрезка и форматирование коллекций

Большие списки и мапы можно динамически обрезать, оставляя только границы
(первые и последний элементы), через `LoggableConfig`:

```dart
log.d(
  'List',
  data: [1.2, 2.3, 3.4, 4.5, 5.6],
  config: const LoggableConfig(
    collectionMaxCount: 3,
    collectionShowCount: true,
    collectionShowIndexes: true,
  ),
);

log.d(
  'Set',
  data: {1.2, 2.3, 3.4, 4.5, 5.6},
  config: const LoggableConfig(collectionMaxCount: 3),
);

log.d(
  'Iterable',
  data: [1.2, 2.3, 3.4, 4.5, 5.6].where((e) => true),
  config: const LoggableConfig(collectionMaxCount: 3),
);
```

![Обрезка и форматирование коллекций](screenshots/data_4.png)

Для строкового вывода `collectionMaxCount` должен быть неотрицательным, а
`collectionMaxStringLength`, если задан, — положительным. Неверные лимиты
бросают `ArgumentError` на границе рендеринга.

`Map` подчиняется тем же двум лимитам и так же сообщает свой размер:

```dart
log.d(
  'Map',
  data: {'a': 1, 'b': 2, 'c': 3, 'd': 4, 'e': 5},
  config: const LoggableConfig(collectionMaxCount: 3),
);
// Map: {₌₅ a: 1, b: 2, …, e: 5}
```

При обрезке сохраняются первые записи и последняя — как у списка: мапа
упорядочена и переобходима. Две детали стоит знать, если установлено правило
редактирования: лимит считает записи, пережившие правило, поэтому выброшенная
запись слот не занимает; а сообщаемый размер — это размер мапы, а не вывода,
потому что другого следа выброшенная запись не оставляет.
`collectionShowIndexes` неприменим: у записей есть ключи.

`Loggable.mapBuilder()` печатается теми же фигурными скобками, но является
структурой свойств, а не коллекцией, так что лимиты и счётчик к нему не
относятся.

Обратите внимание на `Iterable` выше: он обрезан до `(₀:1.2, ₁:2.3, ₂:3.4, …)`,
а не до `(₌₅ ₀:1.2, ₁:2.3, …, ₄:5.6)`. `List` и `Set` обходятся свободно — их
длина и последний элемент дёшевы, — а голый `Iterable` может быть
однопроходным или дорогим для повторного обхода, поэтому читается ровно один
раз: первые элементы, многоточие и никакого количества.

Если вы знаете лучше — скажите это через `iterableEfficientLength`:

```dart
log.d(
  'Iterable',
  data: [1.2, 2.3, 3.4, 4.5, 5.6].where((e) => true),
  config: const LoggableConfig(
    collectionMaxCount: 3,
    iterableEfficientLength: true,
  ),
);
// Iterable: (₌₅ ₀:1.2, ₁:2.3, …, ₄:5.6)
```

Это утверждение вызывающего, как и `units`: пакет не отличает коллекцию с
эффективной длиной от генератора, и на однопроходной он всё равно прочитает
длину и последний элемент. Такой же флаг есть у `LoggableJsonConfig`, где он
превращает `":trim": true` в настоящую длину `":l"`.

#### Настройки форматирования

Для enum можно использовать сокращённую запись через точку (по умолчанию):

```dart
log.d(
  'Enum',
  data: MyEnum.value1,
  config: LoggableConfig(enumDotShorthand: true),
);
log.d(
  'Enum',
  data: MyEnum.value2,
  config: LoggableConfig(enumDotShorthand: false),
);
```

![Настройки форматирования. Enum](screenshots/data_5.png)

Числа принимают шаблон форматирования, но пакет его не интерпретирует:
`intFormat`/`doubleFormat` уходят в `numberFormatter` темы вместе со
значением, а тема без форматтера печатает число как есть. Чтобы шаблоны
заработали, поставьте форматтер — например, поверх пакета
[format](https://pub.dev/packages/format), который тогда принадлежит вашему
`pubspec.yaml`, а не этому:

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

![Настройки форматирования. Числа](screenshots/data_6.png)

Шаблон значит ровно то, что скажет установленный форматтер: выше это шаблон
`format`, а с `(theme, value, pattern) => sprintf(pattern, [value])` вместо
него писали бы `'%d'`. С `format` правила локали — его собственные: `,` и `_`
группируют в любой локали, `n` — локалезависимая форма, и, поскольку он
перестал зависеть от `intl`, никакой внешней локали он не читает: `n`
следует C-локали, а `Intl.defaultLocale` ничего не меняет. `'{:,n}'` там
бросает исключение, потому что `n` не принимает опцию группировки.

Строку можно показывать в кавычках и без:

```dart
log.d(
  'String',
  data: 'abc',
  config: const LoggableConfig(stringInQuotes: true),
);
log.d(
  'String',
  data: 'abc',
  config: const LoggableConfig(stringInQuotes: false),
);
```

![Настройки форматирования. Строки](screenshots/data_7.png)

#### Дефолты и политика уровня приложения

`LoggableConfig` на месте вызова отвечает за этот вызов. За приложение
отвечают ещё два слоя, и незаданное (`null`) поле разрешается через все
четыре, от слабого к сильному:

1. дефолт пакета — что печатается, если никто ничего не сказал;
2. `Loggable.defaultConfig` — предпочтение приложения;
3. место вызова и конфиги контейнеров по пути к значению (ближайший к
   значению побеждает);
4. `Loggable.forceConfig` — политика приложения.

`Loggable.defaultConfig` избавляет от повторов. Задайте один раз, и каждый
лог, который не сказал иначе, будет ему следовать:

```dart
Loggable.defaultConfig = const LoggableConfig(
  stringInQuotes: false,
  collectionShowIndexes: false,
);
```

`Loggable.forceConfig` — то, что не снимается. Ничто ниже не может снять
поле, которое он задал: ни вызов, логирующий значение, ни конфиг контейнера,
подмешанный на полпути внутрь данных:

```dart
Loggable.forceConfig = const LoggableConfig(collectionMaxCount: 10);

// Всё равно десять: место вызова не может расширить потолок.
log.d('items', data: hugeList,
    config: const LoggableConfig(collectionMaxCount: 10000));
```

`defaultConfig` — для вкуса, `forceConfig` — для правил. Поле, оставленное
`null` в любом из них, правилом не является и решается слоями ниже.

Обе статики — на изолят, как `Loggable.sanitizer`: в порождённом изоляте
задайте их заново. Они действуют и в `Loggable.objectToString()`, и в
`Loggable.objectToJson()`, и в этом весь смысл: политика, действующая только
для консольного принтера, политикой не была бы.

Одно поле сохраняет собственное правило против слоя force: `units`
по-прежнему
снимаются со значения, подставленного санитайзером: единицы утверждают
что-то об исходной величине, а маска ею не является.

---

### 6. Форматирование сложных объектов

#### Примесь `Loggable`

Примешав `Loggable` к своим моделям, вы получаете контроль над тем, какие
свойства видны, какие у них единицы измерения, точность и способ
отображения.

Обычный способ:

```dart
final class Person {
  final String name;
  final int age;

  const Person(this.name, this.age);

  @override
  String toString() => 'Person(name: $name, age: $age)';
}

log.d('Person (usual)', data: Person('John', 42));
```

Способ `team_logger`:

```dart
final class Person with Loggable {
  final String name;
  final int age;

  const Person(this.name, this.age);

  @override
  void collectLoggableData(LoggableData data) {
    data
      ..prop('name', name)
      ..prop('age', age);
  }
}

log.d('Person (Loggable)', data: Person('John', 42));
```

Совместно с [freezed](https://pub.dev/packages/freezed):

```dart
@freezed
abstract class Person with _$Person, Loggable {
  const Person._(); // объявите приватный пустой конструктор

  const factory Person(String name, int age) = _Person;

  @override
  void collectLoggableData(LoggableData data) {
    data
      ..name = 'Person' // смените имя, иначе именем станет _Person
      ..prop('name', name)
      ..prop('age', age);
  }
}

log.d('Person (freezed)', data: Person('John', 42));
```

![Примесь Loggable](screenshots/loggable_1.png)

#### Настройка свойств

Стандартный полный вид:

```dart
final class Point with Loggable {
  final double lat;
  final double lon;

  const Point(this.lat, this.lon);

  @override
  void collectLoggableData(LoggableData data) {
    data
      ..round('lat', lat, precision: 5)
      ..round('lon', lon, precision: 5);
  }
}

final class Speed with Loggable {
  final double value;
  final double accuracy;

  const Speed(this.value, this.accuracy);

  @override
  void collectLoggableData(LoggableData data) {
    data
      ..prop('value', value)
      ..prop('accuracy', accuracy);
  }
}


log.d('Point (full)', data: Point(51.894167, 1.482222));
log.d('Speed (full)', data: Speed(143, 2.5));
```

Краткий вид:

```dart
final class Point with Loggable {
  // ...

  @override
  void collectLoggableData(LoggableData data) {
    data
      ..showName = false
      ..round('lat', lat, precision: 5, showName: false, units: '°')
      ..round('lon', lon, precision: 5, showName: false, units: '°');
  }
}

final class Speed with Loggable {
  // ...

  @override
  void collectLoggableData(LoggableData data) {
    data
      ..showName = false
      ..showBrackets = false
      ..prop(
        'value',
        value,
        showName: false,
        view: '${value.toStringAsFixed(1)}±${accuracy.toStringAsFixed(1)}',
        units: 'm/s',
      )
      ..prop('accuracy', accuracy, hidden: true); // для GUI
  }
}

log.d('Point (short)', data: Point(51.894167, 1.482222));
log.d('Speed (short)', data: Speed(143, 2.5));
```

![Настройка свойств](screenshots/loggable_2.png)

#### Несколько представлений

```dart
final class RouteInfo with Loggable {
  final Duration duration;
  final double distance;

  const RouteInfo({
    required this.duration,
    required this.distance,
  });

  @override
  void collectLoggableData(LoggableData data) {
    data
      ..prop(
        'duration',
        duration,
        view: LoggableMultiView([
          LoggableView(duration),
          LoggableView(duration.inMinutes, units: 'min'),
        ]),
      )
      ..prop(
        'distance',
        distance,
        view: LoggableMultiView([
          LoggableView(distance.toStringAsFixed(1), units: 'km'),
          LoggableView((distance / 1.852).toStringAsFixed(1), units: 'NM'),
        ]),
      );
  }
}

final routeInfo = RouteInfo(
  duration: Duration(minutes: 90),
  distance: 124,
);

log.d('Route info', data: routeInfo);
```

![Несколько представлений](screenshots/loggable_3.png)

#### Помощники Map и Builder

Для быстрого сбора свойств или для сторонних объектов используйте
`Loggable.mapBuilder` или `Loggable.builder`:

```dart
final class NotLoggableObject {
  final double weight;
  final double height;

  NotLoggableObject(this.weight, this.height);
}

final notLoggableObject = NotLoggableObject(85.5, 1.80);

log.d(
  'Quick Info',
  data: Loggable.mapBuilder()
    ..prop('weight', notLoggableObject.weight, units: 'kg')
    ..prop('height', notLoggableObject.height, units: 'm'),
);

log.d(
  'Quick Info',
  data: Loggable.builder(notLoggableObject)
    ..prop('weight', notLoggableObject.weight, units: 'kg')
    ..prop('height', notLoggableObject.height, units: 'm'),
);
```

![Помощники Map и Builder](screenshots/loggable_4.png)

---

#### Собственные конвертеры типов

Чтобы форматировать сторонние классы, которые не могут напрямую реализовать
примесь `Loggable`, зарегистрируйте `LoggableTypeConverter`:

```dart
class MyConverter implements LoggableTypeConverter<NotLoggableObject> {
  @override
  LoggableData convertToData(NotLoggableObject obj) => Loggable.builder(obj)
    ..prop('weight', obj.weight, units: 'kg')
    ..prop('height', obj.height, units: 'm');
}

final notLoggableObject = NotLoggableObject(85.5, 1.80);
log.d('NotLoggableObject (toString)', data: notLoggableObject);

Loggable.registerTypeConverter(MyConverter());
log.d('NotLoggableObject (MyConverter)', data: notLoggableObject);
```

Конвертер подбирается строго по `runtimeType` объекта: к наследникам
зарегистрированного типа он не применяется.

![Собственные конвертеры типов](screenshots/loggable_5.png)

### 7. Трассировка (`TraceId`)

#### Трассировка через зоны

Вместо того чтобы передавать идентификаторы корреляции вручную через
вложенные вызовы, `team_logger` использует **Dart Zones** и связывает
`TraceId` со всеми синхронными и асинхронными операциями внутри контекста
исполнения:

```dart
final searchTrace = TraceId.auto('search'); // разрешится в '#search-1'

await log.trace(searchTrace, () async {
  log.d('Searching database...');    // подхватывает и выводит '#search-1'
  await Future.delayed(Duration(milliseconds: 100));
  log.i('Database fetch completed'); // подхватывает и выводит '#search-1'
});
```

![Трассировка через зоны](screenshots/trace_1.png)

#### Теги и вложенность в зоне трассировки

Зона может нести не только trace ID, но и теги. Каждый лог, сделанный
внутри, их подхватывает, и ни один промежуточный вызов о них не знает:

```dart
log.trace(TraceId.manual('t', 1), tags: {'zone'}, () {
  log.i('inside');
});
// {t-1} inside                                          #zone
```

Зоны вкладываются, и вложенность **накапливает**, а не заменяет. Лог,
сделанный во внутренней зоне, несёт оба идентификатора, начиная с внешнего:

```dart
log.trace(TraceId.manual('outer', 1), () {
  log.trace(TraceId.manual('inner', 2), () {
    log.i('nested');
  });
});
// {outer-1} {inner-2} nested
```

Зона заканчивается вместе с колбэком — в том числе когда он заканчивается
исключением. Исключение покидает `trace()` так же, как покинуло бы любой
другой вызов, и логи после него не несут от него ничего:

```dart
try {
  log.trace(TraceId.manual('boom', 1), () => throw StateError('x'));
} on StateError {
  // ...
}
log.i('after the exception');
// after the exception          ← ни trace ID, ни тегов зоны
```

У `trace()` есть и параметр `zone:`, как и у каждого вызова логирования, —
для случаев, когда зона, в которой нужно выполниться или из которой нужно
прочитать контекст, не текущая.

#### Чтение контекста зоны

`Logger.zonedTraceIds()` и `Logger.zonedTags()` отвечают, что несёт текущая
зона. Это полезно, чтобы прицепить тот же контекст к чему-то, что логом не
является: к HTTP-заголовку, к спану, к отчёту об ошибке:

```dart
log.trace(TraceId.manual('r', 1), tags: {'a'}, () {
  Logger.zonedTraceIds(); // [r-1]
  Logger.zonedTags();     // {a}
});
```

Оба возвращают неизменяемые view. Попытка добавить бросает
`UnsupportedError`, а не перетегирует молча все последующие логи той же
зоны: контекст задаётся в `trace()`, а во всех остальных местах только
читается. Оба принимают необязательную зону, если спросить нужно не про
текущую.

#### Виды `TraceId`

Поддерживаются:
* `TraceId.auto(group)`: автоматически инкрементируемые идентификаторы в
  рамках конкретной группы.
* `TraceId.global()`: автоматически инкрементируемые последовательные
  идентификаторы без префикса группы: `{1}`, `{2}`…
* `TraceId.manual(group, num)`: заранее заданные идентификаторы — полезно,
  когда нужно совпадение с внешними идентификаторами транзакций.

![Виды TraceId](screenshots/trace_2.png)

#### Суффикс `TraceId`

К любому TraceID можно добавить суффикс:

```dart
Future<Response> request(Uri uri) async {
  final traceId = TraceId.auto('request');

  log.i('$uri', traceId: traceId);
  // ... запрос ...

  // Если запрос не удался, повторяем:
  for (var i = 0; i < 3; i++) {
    log.w('$uri. Attempt #${i + 2}', traceId: traceId.withSuffix('${i + 2}'));
    // ... повтор ...
  }
}
```

![Суффикс TraceId](screenshots/trace_3.png)

#### Ленивость `TraceId`

`TraceId.auto` и `TraceId.global` инкрементируются лениво. Иначе говоря,
номер увеличивается только тогда, когда `TraceId` действительно используется:

```dart
log.level = LogLevels.all;

log.d('Debug message', traceId: TraceId.auto('lazy'));   // lazy-1
log.i('Info message', traceId: TraceId.auto('lazy'));    // lazy-2
log.w('Warning message', traceId: TraceId.auto('lazy')); // lazy-3

log.level = LogLevels.warning;

log.d('Debug message', traceId: TraceId.auto('lazy'));   // не показано
log.i('Info message', traceId: TraceId.auto('lazy'));    // не показано
log.w('Warning message', traceId: TraceId.auto('lazy')); // lazy-4
```

![Ленивость TraceId](screenshots/trace_4.png)

---

### 8. Кольцевой буфер (`LogStorage`)

`LogStorage` держит в памяти фиксированное количество логов. Он нужен для
диагностических снимков, показа телеметрии на отладочных экранах или передачи
логов в локальное хранилище. `maxCount` должен быть положительным; неверные
значения бросают `ArgumentError` при создании.

```dart
final logStorage = LogStorage(maxCount: 1000);

// Подключаем к публишеру логгера
log.publisher = MultiPublisher([
  ConsoleLogPrinter(rows: [...]),
  logStorage,
]);

// Забираем историю логов из памяти
List<Log> history = logStorage.snapshot();
```

См. также [flutter_team_logger](https://pub.dev/packages/flutter_team_logger),
который использует `LogStorage`.

![flutter_team_logger](screenshots/flutter_team_logger.png)

---

### 9. Запись логов в файлы (`FileLogStorage`)

`FileLogStorage` хранит логи на устройстве пользователя, чтобы их можно было
потом отправить для диагностики. Он живёт в отдельной библиотеке, построенной
на `dart:io`: импортируйте `package:team_logger/team_logger_io.dart` вместо
`team_logger.dart` (она реэкспортирует весь основной API). На вебе
продолжайте пользоваться основной библиотекой.

У каждого запуска приложения своя **сессия**. Сессия — это цепочка файлов
чанков `<sessionId>.<index>.jsonl` в формате JSON Lines, по одному JSON-объекту
на лог. Первая строка каждого чанка — строка метаданных (ключ `":meta"`) с
идентификатором сессии, временем старта и любыми полями, переданными в `meta`.

Собственные идентификаторы сессий очищаются до букв, цифр, `-` и `_`; пустой
идентификатор отклоняется с `ArgumentError`. Файлы с посторонним именем или с
числовым индексом вне диапазона Dart `int` игнорируются при перечислении
сессий и при startup-очистке.

Используйте приватный каталог приложения. Symlink'и и прочие не-обычные
записи игнорируются, каждый чанк создаётся эксклюзивно и держится открытым,
пока активен. Это защита по мере возможностей от случайных или ранее
существовавших ссылок, а не песочница против другого процесса, способного
состязаться за файловые операции в том же каталоге.

```dart
final storage = FileLogStorage(
  directory: '/path/to/logs',            // например, из path_provider
  meta: {'appVersion': '1.2.3'},         // попадёт в строку метаданных
  maxSessionSize: 10 * 1024 * 1024,      // целевой размер хранимой сессии
  maxChunkSize: 1024 * 1024,             // порог ротации чанка
  maxTotalSize: 100 * 1024 * 1024,       // бюджет хранения на старте
  maxAge: const Duration(days: 7),       // сессии старше этого удаляются
);

log.publisher = MultiPublisher([
  ConsoleLogPrinter(rows: [...]),
  storage,
]);
```

Три ограничения размера, снаружи внутрь (количество сессий и чанков не
ограничивается никогда):

- **Все сессии** (`maxTotalSize`, `maxAge`): на старте удаляются сессии
  старше `maxAge`, затем самые старые сессии удаляются, пока остальные не
  уложатся в `maxTotalSize` (за вычетом резерва в `maxSessionSize` под
  текущую сессию).
- **Одна сессия** (`maxSessionSize`): когда суммарный размер сессии
  превышает лимит, удаляется самый старый чанк — свежие логи сохраняются
  всегда.
- **Один чанк** (`maxChunkSize`): когда файл чанка достигает лимита,
  начинается следующий. Должен укладываться в `maxSessionSize` минимум
  дважды.

`maxChunkSize` должен быть положительным, `maxSessionSize` — вмещать хотя бы
два чанка, а ненулевой `maxTotalSize` — быть не меньше `maxSessionSize`.
Неверные конфигурации размеров бросают `ArgumentError` до начала
инициализации файлов. `maxQueueSize`, если задан, тоже должен быть
положительным.

Эти значения — цели ротации и хранения, а не жёсткие потолки в байтах.
Каждая запись JSON Lines атомарна: она никогда не разрезается, не обрезается
и не отбрасывается только из-за своего размера. Отдельная запись больше
`maxChunkSize` пишется целиком, а новейший чанк не удаляется никогда,
поэтому и он, и текущая сессия могут превысить `maxSessionSize`. Как
следствие, `maxTotalSize` тоже не гарантирует жёсткого потолка во время
работы. Если исчерпание диска — реальная угроза, ограничивайте размер
метаданных сессии, сообщений, ошибок, стеков и рендеримых данных до их
публикации.

Запись идёт в фоне, пакетами, а очередь перед ней ограничена `maxQueueSize` —
по умолчанию 100 000 принятых, но ещё не записанных логов. На пределе
отказывают *входящему* логу, поэтому не поспевающий диск стоит новейших
логов, а не процесса. Отклонённый лог уходит в `onDropped`, а если
`onDropped` не задан, о потере сообщается в stdout, а не замалчивается:
передайте `onDropped: (_) {}` для молчаливого хранилища или
`maxQueueSize: null`, чтобы отказаться от ограничения совсем.

Успешно завершившийся `flush()` гарантирует, что всё опубликованное к этому
моменту лежит на диске. Если инициализация или запись падает уже после того,
как лог был принят, ошибка сообщается в `onError`, затронутые логи уходят в
`onDropped`, а каждый последующий `flush()` завершается этой первой ошибкой,
слив перед этим новые логи. Хранилище может восстановиться и сохранять
дальнейшие логи, но отменить прежнюю потерю это не может; для чистого
состояния надёжности создайте новый `FileLogStorage`.

`close()` дожидается инициализации, сливает принятые логи и закрывает
активный handle чанка. Если надёжность была нарушена, он сначала закрывает
ресурсы, а затем завершается той же сохранённой ошибкой. `isClosed`
становится `true` сразу с началом закрытия, а `flush()`, вызванный после
этого, возвращает тот же future полного жизненного цикла, что и `close()`.
Вызовы `publish()` после него игнорируются.

```dart
FileLogStorage(
  directory: '...',
  maxQueueSize: 100000,                  // null — без ограничения (растёт до OOM)
  onDropped: (logs) => metrics.lostLogs += logs.length,
);
```

Параметр `data` сохраняется либо текстом через `Loggable.objectToString` (по
умолчанию), либо структурным JSON через `Loggable.objectToJson`:

```dart
FileLogStorage(
  directory: '...',
  dataFormat: FileLogDataFormat.json,    // objectToJson
);

FileLogStorage(
  directory: '...',
  // dataFormat: FileLogDataFormat.text — значение по умолчанию
  // (objectToString). Форматированием управляет тема; ANSI-коды
  // сохраняются в файле, а LogMainTheme.noColors (по умолчанию) даёт
  // чистый текст.
  theme: LogMainTheme.defaultActiveTheme,
);
```

Ключи JSON-объекта обязаны остаться уникальными после преобразования в
строки. Например, `Loggable.objectToJson({1: 'number', '1': 'string'})`
бросает `ArgumentError`, а не теряет молча первое значение. В JSON-режиме
`FileLogStorage` ошибка доходит до `onError`, эта запись превращается в
fallback `encodeError`, а соседние записи всё равно пишутся.

Чтобы отправить логи для диагностики, слейте сохранённые сессии в один
GZIP-сжатый файл JSON Lines или выгрузите их отдельными обычными файлами.
Сжатый поток сохраняет порядок выбранных сессий и строку метаданных каждой,
поэтому границы остаются различимыми после распаковки, а весь
диагностический пакет не буферизуется в памяти:

```dart
await storage.flush();                   // убедиться, что всё на диске

final sessions = await storage.sessions.list();
await storage.sessions.gzipTo(File('/tmp/logs.jsonl.gz'));        // один gzip
await storage.sessions.exportTo(Directory('/tmp/logs'));          // обычные файлы

// Посмотреть или прибраться:
for (final session in sessions) {
  print('${session.id}: ${session.size} bytes, ${session.lastModified}');
  print(await session.readMeta());       // {'sessionId': ..., 'appVersion': ...}
}
```

Цель GZIP должна быть отдельным файлом, а не выбранным чанком сессии и не
symlink'ом/hardlink'ом на него. `gzipTo()` отклоняет такие псевдонимы до
открытия цели, поэтому экспорт не может обнулить собственный источник.

Удалять текущую сессию, пока её `FileLogStorage` активен, не поддерживается:
POSIX может продолжить писать в отвязанный файл, а Windows может отказать в
удалении. Запомните текущий идентификатор, закройте хранилище и затем
выберите именно эту сессию:

```dart
final currentId = storage.sessionId;
await storage.close();
final current = (await storage.sessions.list())
    .singleWhere((session) => session.id == currentId);
await current.delete();
```

---

### 10. Редактирование логов (`Logger.transformer` и `Loggable.sanitizer`)

У team_logger два хука редактирования, и они решают разные задачи —
выбирайте по тому, что вам нужно, ещё до примеров ниже:

| | `Logger.transformer` | `Loggable.sanitizer` |
| --- | --- | --- |
| Видит | Лог целиком: сообщение, данные, теги, trace ID, путь, ошибку, стек | Каждое значение внутри `data` с его именем/путём/глубиной |
| Выбросить лог целиком | Да — вернуть `null` | Нет — только отдельные значения, через `Sanitize.drop` |
| Если правило бросает | Fail-closed — лог не публикуется, ошибка уходит в `onError`/зону | Не fail-closed — ошибка уходит в публишер (см. ниже) |
| Сырое значение в памяти | Заменяется в `Log.data` | Оригинал остаётся в `Log.data`; маскируется только отрендеренный вывод |
| Область действия | На логгер (наследуется подлоггерами); на приёмник — через `TransformPublisher` | Глобально, в пределах изолята |
| Покрывает `message`/`error`/`stackTrace` | Да | Нет — они не проходят через обходчики рендеринга |

Коротко: `Logger.transformer` — чтобы выбросить лог или отредактировать
`message`/`error`/`stackTrace`; `Loggable.sanitizer` — чтобы отредактировать
значения внутри `data`, не трогая сам объект.

Правило санитайзера не должно бросать исключений. В отличие от трансформера,
fail-closed-защиты у него нет: ошибка уходит в тот публишер, который в этот
момент рендерил. `FileLogStorage` сообщит о ней своему `onError` и запишет
fallback-строку без данных; `ConsoleLogPrinter` её не ловит, поэтому
исключение покинет `publish()` — `MultiPublisher` его изолирует, но принтер
сам по себе пробросит его в точку логирования.

Назначайте `Logger.transformer`, чтобы маскировать секреты и персональные
данные или целиком выбрасывать недопустимые логи прямо перед публикацией: он
наследуется дочерними логгерами так же, как `level`/`publisher`, а возврат
`null` выбрасывает лог. Стройте его через `Log.copyWith`, который всегда
сохраняет идентичность лога (его номер и время); бросающий трансформер
fail-closed — лог выбрасывается, и незамаскированная версия не публикуется
никогда.

`Log.tags` и `Log.traceIds` — неизменяемые снимки. Изменение исходной
коллекции после создания или копирования лога этот лог не меняет, а попытка
изменить выставленные наружу коллекции бросает `UnsupportedError`. Вызов
`copyWith()`, который их не заменяет, переиспользует существующие снимки без
повторного копирования.

```dart
log.transformer = (entry) => entry.copyWith(
  message: entry.message.replaceAll(RegExp(r'\d{16}'), '**** **** **** ****'),
);
```

Чтобы замаскировать только один приёмник, оберните его в
`TransformPublisher` внутри `MultiPublisher` — остальные публишеры продолжат
получать лог нетронутым:

```dart
log.publisher = MultiPublisher([
  ConsoleLogPrinter(rows: [...]),                       // остаётся как есть
  TransformPublisher(fileStorage, transformer: redact), // маскируется перед записью
]);
```

#### Пер-значное редактирование (`Loggable.sanitizer`)

`Logger.transformer` заменяет лог целиком. Чтобы редактировать значения
**внутри** `data` — включая вложенные в объекты, мапы и коллекции —
назначьте глобальный санитайзер: он вызывается для каждого значения на пути к
выводу, поэтому ни один публишер его не пропустит (консоль, файловое
хранилище, экспорт сессий, встроенный просмотрщик логов — все идут через один
и тот же код рендеринга).

```dart
Loggable.sanitizer = (ctx) => switch (ctx.name) {
  'password' || 'token' => Sanitize.drop,      // свойство исчезает
  'pan' => '**** **** **** ${(ctx.value! as String).substring(12)}',
  _ => ctx.value,
};

log.i(
  'checkout',
  data: {
    'user': 'ann',
    'token': 'abc123',
    'card': {'pan': '4111111111111234'},
  },
);
// checkout: {₌₂ user: "ann", card: {₌₁ pan: "**** **** **** 1234"}}
```

`ctx` (это `SanitizeContext`) несёт также `path` (`user.card.pan`) и `depth`.
Возврат замены прекращает предложение правилу детей *оригинала*, но сама
замена рендерится обычным порядком — её собственные дети предлагаются правилу
как любое другое значение. Правило, чья замена сама подходит под то же
правило, зациклится.

Что стоит знать до написания правила:

- Правило обязано быть чистой функцией без побочных эффектов и не должно
  рендерить или логировать изнутри себя — даже неявно, через
  `toString()`/интерполяцию значения, которое ему передали.
- **Корневое** значение — весь объект `data` — тоже предлагается, без имени,
  на `depth == 0`. Это включает прямой путь `toString()`: `'$obj'`,
  `print(obj)` и просмотр `Loggable` или `LoggableData` в отладчике идут
  через то же предложение, поэтому правило на `depth == 0` меняет то, что
  печатает обычная интерполяция, а `Sanitize.drop` там даёт пустую строку.
  (Класс, примешавший `Loggable`, уже согласился, что его `toString()` — это
  и есть рендеринг лога: его свойства санитизируются на этом пути в любом
  случае.)
- Замена рендерится форматированием контейнера — `collectionMaxCount`,
  `stringInQuotes`, форматы чисел, — но никогда его `units`: единицы
  утверждают что-то об исходной величине, а маска ею не является. Это верно и
  для свойства, и для корня.
- Для свойства с `view` (см. «Настройка свойств» выше) правило видит объект
  `view`, а не текст, который тот рендерит: редактируйте такие свойства по
  `name`/`path`, а не сопоставлением отрендеренного содержимого.
- Ключ `Map` правилу не предлагается: правило получает *значение* записи и
  видит ключ как `ctx.name`. Секрет в самом ключе (`{'ann@example.com': {...}}`)
  заменить нельзя — правило по имени может только выбросить запись целиком
  через `Sanitize.drop`.
- Значения *внутри* объекта-ключа предлагаются только там, где рендеринг
  ключа проходит через обходчики: **всегда в строковом выводе, но в JSON —
  только для ключей, которые сами заходят в обходчики через собственный
  `toString()`**: `Loggable`, `LoggableData`, `LoggableWrapper` и
  `LoggableMultiData`. Любой другой ключ `objectToJson` рендерит обычным
  `key.toString()`, поэтому секрет внутри обычного контейнера-ключа
  маскируется в консоли и **уцелевает в `objectToJson`** — а значит, и в
  JSONL-файлах, записанных с `dataFormat: FileLogDataFormat.json` (по
  умолчанию `FileLogDataFormat.text` пишет замаскированную строковую форму):

  ```dart
  Loggable.sanitizer = (ctx) => ctx.name == 'pw' ? '<masked>' : ctx.value;
  log.i('m', data: <Object?, Object?>{{'pw': 'hunter2'}: 'primary'});
  // консоль:    {{pw: "<masked>"}: "primary"}
  // json JSONL: "data":{"{pw: hunter2}":"primary"}  ← секрет в файле
  ```

  Правильный способ — выбросить запись целиком, а не заменять значение
  внутри неё, причём сопоставлять по *значению* записи, а не по тексту
  ключа: как объясняет следующий пункт, нестроковый ключ доходит до правила в
  той форме, в какой его рендерит текущий вывод, поэтому `ctx.name`
  отличается между консолью и JSON, и правило по тексту ключа выбросило бы
  запись только в одном из них. А там, где содержимое ключа *предлагается*,
  оно несёт путь **контейнера**, а не записи: в `{'acc': {Account('DE89'): 'x'}}`
  свойство ключа приходит как `acc.iban`, тогда как сама запись —
  `acc.Account(iban: "DE89")`.
- Для нестрокового ключа `ctx.name` — это ключ в том виде, в каком его
  рендерит **именно этот вывод**: строковый — через обходчик и тему
  (`[₌₂ ₀:1, ₁:2]`, `.admin`), JSON — через `key.toString()` (`[1, 2]`,
  `Role.admin`). Формы разные, а строковая ещё и зависит от темы, поэтому
  правило по тексту ключа сработает в одном выводе и пропустит запись в
  другом. Редактируйте такие записи по значению или выбрасывайте целиком.
- В позиции элемента коллекции `Sanitize.drop` рендерится как `'<dropped>'`,
  а не удаляет элемент, поэтому печатаемая длина коллекции остаётся честной.
  `Prop`, отрендеренный сам по себе (список `LoggableData.props` публичен),
  делает то же: удалять его неоткуда, поэтому он печатает маркер, а не
  исчезает.
- `Loggable.sanitizer` — статика на изолят: в порождённом изоляте задайте её
  заново.
- Санитизация происходит во время рендеринга, поэтому защита от циклов,
  лимиты коллекций и ленивые итерируемые не затрагиваются, а отфильтрованные
  логи по-прежнему ничего не стоят. Сырое значение остаётся в `Log.data` —
  берите `Logger.transformer`, когда значения не должно быть в памяти вовсе.

### 11. Недоверенный текст и вывод в терминал

Залогируйте текст, пришедший извне вашей программы — HTTP-заголовок,
сообщение исключения, имя файла, query-параметр, — и он может нести
управляющие последовательности терминала. Если их не трогать, они дойдут до
терминала как команды: очистят экран, переместят курсор, перезапишут уже
выведенные строки, перекрасят остаток вывода, подделают визуальную структуру
лога и создадут кликабельную ссылку. Ничто из этого не нарушает
memory-safety; всё это заставляет лог врать о произошедшем.

**Безопасный режим включён по умолчанию.** Последовательность в
залогированном тексте *показывается*, а не отправляется: печатается по
частям, и `ESC` в результате не остаётся, поэтому собрать из этого команду
больше не из чего:

```dart
log.i('\x1B[2Jforged');                       // [CSI 2 ED]forged
log.i('m', data: {'ua': '\x1B[31mred'});    // m: {₌₁ ua: "[CSI 31 SGR]red"}
log.i('m', data: {'\x1B[31mk': 1});         // m: {₌₁ [CSI 31 SGR]k: 1}
```

Вы видите, что пришло, а не теряете это и не исполняете. Обычный текст не
трогается, как и собственное оформление темы: преобразование идёт по сырому
тексту, до того как тема что-либо нарисует.

Покрыты сообщение, текст ошибки, строковые значения, ключи мап, имена
свойств, имена enum и значение, переданное в `LoggableView`, — и в консоли, и
в `FileLogStorage`. BBCode, который вы пишете в сообщении, компилируется как
обычно: `[b]bold[/b]` — это разметка, а не управляющая последовательность.

То, что *рендерит* view, не трогается, и это намеренно: view — точка
расширения рендеринга, ей передаётся тема, а `LoggableMultiView` и суффиксы
единиц кладут в её результат собственное оформление темы. Обезвредить его
значило бы сломать любой view, который форматирует свой вывод. Значение,
переданное во view, обезвреживается до того, как туда попадёт.

#### Сырой ANSI — явный отказ

Логировать текст, который вы оформили сами, — законное занятие. Скажите об
этом:

```dart
log.d('progress', data: {'bar': '\x1B[32m████\x1B[0m'},
    config: const LoggableConfig(escapeAnsiCodes: false));
```

Настройка подчиняется обычным слоям, поэтому приложение может отказаться от
режима и повсеместно — через `Loggable.defaultConfig`. Чего оно не может —
отказаться из-под политики: `Loggable.forceConfig`, включающий безопасный
режим, держится против любого места вызова и любого контейнера:

```dart
Loggable.forceConfig = const LoggableConfig(escapeAnsiCodes: true);

// Всё равно показано, а не отправлено: место вызова не может снять политику.
log.d('m', data: untrusted,
    config: const LoggableConfig(escapeAnsiCodes: false));
```

Это та настройка, к которой стоит тянуться в сервисе, чьи логи несут внешний
ввод. О том, как разрешаются слои, см. «Дефолты и политика уровня приложения»
выше.

#### Ручка уровня темы

`ControlCodeFormatter` — `LogMainTheme.valueFormatter` по умолчанию —
превращает управляющие символы C0 в видимые обозначения (`\x07` для BEL,
`\r` для CR) и пропускает `ESC`, потому что к моменту его работы безопасный
режим уже убрал последовательности. Его `excludeEscCode: false` остаётся
грубой альтернативой уровня темы, экранирующей `ESC` в текст `\x1B`, но
тянуться к ней теперь незачем: она хуже читается и ничего не говорит о том,
где проходит граница доверия.

#### Файлы

`FileLogStorage` пишет сообщение тем же путём, поэтому в строку JSONL
попадает уже обезвреженный текст. Опасен был не сам файл: `jsonEncode`
записывает `ESC` как escape `\u001b`, так что `cat` и `tail` были безопасны
всегда. Опасен был читатель, который расшифровывает строку и печатает
сообщение в терминал, — и теперь безопасен и он.

---
## Лицензия

Библиотека распространяется по лицензии MIT. Подробности — в
[LICENSE](https://github.com/vi-k/team_logger/blob/main/LICENSE).
