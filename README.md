# Team Logger

[![Pub Version](https://img.shields.io/pub/v/team_logger)](https://pub.dev/packages/team_logger)
[![Dart SDK](https://img.shields.io/badge/dart-3.6.0-blue.svg)](https://dart.dev)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)

A highly-configurable, trace-aware, structured logging library designed for
large teams, complex applications, and high-volume logs in Dart & Flutter.

`team_logger` provides nested namespace loggers, automated zone-based
trace propagation, custom object formatting (`Loggable`), inline BBCode
formatting, and customizable styling themes.

---

## Features

* **Color & Dynamic Themes**: Style individual log elements using ANSI escape
  codes, apply ready-made grayscale or RGB palettes, and dynamically shift
  bracket colors based on nesting depth to clarify nested structures.
* **Active vs. Inactive Themes**: Configure active and inactive styling rules
  to keep background logs visible but low-contrast, while emphasizing active
  or high-severity logs.
* **Row-Based Console Layouts**: Configure custom log formats using modular
  row components: sequence numbers, log level names, timestamps, trace IDs,
  tags, namespace paths, and messages.
* **Zone-Based Trace Propagation**: Automatically propagate and associate
  trace IDs across asynchronous execution paths using Dart Zones
  (`log.trace()`), reducing the need to pass context parameters manually.
* **Custom Object Formatting (`Loggable`)**: Mixin `Loggable` on classes to
  specify how properties, unit suffixes, number formats, and collections
  should be formatted inside logs.
* **Type Converters**: Register custom formatting converters for third-party
  classes that do not directly implement `Loggable`.
* **BBCode Console Formatting**: Apply formatting in log messages using
  standard and customizable tags like `[success]...[/success]` or
  `[b]bold[/b]`, which compile to ANSI escape sequences.
* **Namespace Loggers**: Instantiate child loggers via `createChild()` to
  generate structured path hierarchies (e.g. `app/network/polling`).
* **In-Memory Circular Buffer (`LogStorage`)**: Collect a fixed number of
  recent logs in memory for diagnostic exports or in-app inspection.

---

## Installation

Add `team_logger` to your `pubspec.yaml` file:

```yaml
dependencies:
  team_logger: ^0.1.69
```

Or run:

```bash
dart pub add team_logger
```

---

## Quick Start

The following example configures theme, builds a custom console row layout,
creates child loggers, and executes code in a trace zone.

```dart
import 'package:team_logger/team_logger.dart';

// Initialize the logger with a custom layout
final log = Logger('app')
  ..level = LogLevels.all
  ..publisher = ConsoleLogPrinter(
    theme: LogMainTheme.defaultActiveTheme,
    rows: const [
      LogRow(
        maxLength: 120,
        children: [
          LogSequenceNum(),
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

  // Create child loggers
  final paymentLog = log.createChild(name: 'payment');

  // Execute within a Trace Zone to automatically capture and output the TraceId
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

  // ... api call ...

  networkLog.d(
    '[success][200 OK][/success] https://api.example.com/[b]v1/payment[/b]',
    tags: ['response'],
    data: {'payment_id': 123},
  );
}
```

Output:

![Quick start](screenshots/quick_start_1.png)


When filtering by sequence number **all lines** included in the message will be
displayed:

![Quick start. Filter by num](screenshots/quick_start_2.png)

When filtering by trace ID, all messages sent within `log.trace` scope and
**all lines** within those messages will be displayed:

![Quick start. Filter by trace ID](screenshots/quick_start_3.png)

When filtering by tag, all messages with tag `#http` and
**all lines** within those messages will be displayed:

![Quick start. Filter by tag](screenshots/quick_start_4.png)

---

## Deep Dive

### 1. Trace Propagation (`TraceId`)

#### Zone-Based Trace Propagation

Instead of passing correlation IDs manually through nested function calls,
`team_logger` uses **Dart Zones** to associate a `TraceId` with all synchronous
and asynchronous operations inside the execution context:

```dart
final searchTrace = TraceId.auto('search'); // resolves to '#search-1'

await log.trace(searchTrace, () async {
  log.d('Searching database...');    // captures and outputs '#search-1'
  await Future.delayed(Duration(milliseconds: 100));
  log.i('Database fetch completed'); // captures and outputs '#search-1'
});
```

![Zone-based trace propagation](screenshots/trace_1.png)

#### `TraceId` configurations

Supported `TraceId` configurations:
* `TraceId.auto(group)`: Automatically incremented IDs scoped to a specific
  group name.
* `TraceId.global()`: Automatically incremented sequential IDs without a group
  prefix: `{1}`, `{2}`...
* `TraceId.manual(group, num)`: Pre-defined IDs, useful when matching external transaction identifiers.

![TraceId configurations](screenshots/trace_2.png)

#### `TraceId` suffix

A suffix can be added to any TraceID:

```dart
Future<Response> request(Uri uri) async {
  final traceId = TraceId.auto('request');

  log.i('$uri', traceId: traceId);
  // ... request ...

  // If request failed, retry:
  for (var i = 0; i < 3; i++) {
    log.w('$uri. Attempt #${i + 2}', traceId: traceId.withSuffix('${i + 2}'));
    // ... retry ...
  }
}
```

![TraceId suffix](screenshots/trace_3.png)

#### `TraceId` laziness

`TraceId.auto` and `TraceId.global` use lazy increment. In other words, the
number is incremented only when `TraceId` is actually used:

```dart
log.level = LogLevels.all;

log.d('Debug message', traceId: TraceId.auto('lazy'));   // lazy-1
log.i('Info message', traceId: TraceId.auto('lazy'));    // lazy-2
log.w('Warning message', traceId: TraceId.auto('lazy')); // lazy-3

log.level = LogLevels.warning;

log.d('Debug message', traceId: TraceId.auto('lazy'));   // not displayed
log.i('Info message', traceId: TraceId.auto('lazy'));    // not displayed
log.w('Warning message', traceId: TraceId.auto('lazy')); // lazy-4
```

![TraceId laziness](screenshots/trace_4.png)

---

### 2. Data Output

#### Data Parameter

Typically, the output of data logging looks something like this:

```dart
const person = {'firstName': 'John', 'lastName': 'Smith', 'age': 42};
log.d('Person: $person');
```

`team_logger` offers a different approach to data logging:

```dart
log.d('Person', data: person);
```

![Data parameter](screenshots/data_1.png)

This will not only allow you to display a more readable message in the console,
formatted using ANSI escape codes, but also make it easier to log the data to
a database or analytics system.

#### Deeply Nested Objects

The color of the brackets changes dynamically depending on the nesting level
to make nested structures easier to understand:

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

![Deeply nested objects](screenshots/data_2.png)

#### Multi Data

The data can be divided into sections:

```data
log.d(
  'Add new user',
  data: LoggableMultiData({
    'HEADERS': {'Content-Type': 'application/json'},
    'BODY': person,
  }),
);
```

![Multi data](screenshots/data_3.png)

#### Collection Truncation & Formatting

Large lists or maps can be truncated dynamically to show only the boundaries
(first and last elements) using `LoggableConfig`:

```dart
log.d(
  'List',
  data: [1.2, 2.3, 3.4, 4.5, 5.6],
  config: const LoggableConfig(
    collectionMaxLength: 3,
    collectionShowLength: true,
    collectionShowIndexes: true,
  ),
);

log.d(
  'Set',
  data: {1.2, 2.3, 3.4, 4.5, 5.6},
  config: const LoggableConfig(collectionMaxLength: 3),
);

log.d(
  'Iterable',
  data: [1.2, 2.3, 3.4, 4.5, 5.6].where((e) => true),
  config: const LoggableConfig(collectionMaxLength: 3),
);
```

![Collections truncation & formatting](screenshots/data_4.png)

#### Formatting Settings

You can use dot shorthand syntax for enums (default):

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

![Formatting settings. Enum](screenshots/data_5.png)

Numbers can be formatted in the
[format](https://docs.python.org/3/library/string.html#format-string-syntax)/[sprintf](https://en.cppreference.com/w/c/io/fprintf)
style (using the [format](https://pub.dev/packages/format) package):

```dart
log.d(
  'Float number with fixed precision',
  data: 1.23456789,
  config: const LoggableConfig(doubleFormat: '.4f'),
);

log.d(
  'Integer number with grouping',
  data: 123456789,
  config: const LoggableConfig(intFormat: ',d'),
);

Intl.defaultLocale = 'bn';
log.d(
  'Integer number (Bengali locale)',
  data: 123456789,
  config: const LoggableConfig(intFormat: ',n'),
);
```

![Formatting settings. Numbers](screenshots/data_6.png)

String can be displayed with or without quotation marks:

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

![Formatting settings. Strings](screenshots/data_7.png)

---

### 3. Formatting Complex Objects

#### `Loggable` Mixin

Implementing the `Loggable` mixin on your data models allows you to format
objects with specific controls for property visibility, units, floating-point
precision, and display format.

The usual way:

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

The `team_logger` way:

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

Use together in [freezed](https://pub.dev/packages/freezed):

```dart
@freezed
abstract class Person with _$Person, Loggable {
  const Person._(); // define a private empty constructor

  const factory Person(String name, int age) = _Person;

  @override
  void collectLoggableData(LoggableData data) {
    data
      ..name = 'Person' // change the name, otherwise _Person will be used as the name
      ..prop('name', name)
      ..prop('age', age);
  }
}

log.d('Person (freezed)', data: Person('John', 42));
```

![Loggable mixin](screenshots/loggable_1.png)

#### Property Configuration

Standard full view:

```dart
final class Point with Loggable {
  final double lat;
  final double lon;

  const Point(this.lat, this.lon);

  @override
  void collectLoggableData(LoggableData data) {
    data
      ..fixed('lat', lat, 5)
      ..fixed('lon', lon, 5);
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

Short view:

```dart
final class Point with Loggable {
  // ...

  @override
  void collectLoggableData(LoggableData data) {
    data
      ..showName = false
      ..fixed('lat', lat, 5, showName: false, units: '°')
      ..fixed('lon', lon, 5, showName: false, units: '°');
  }
}

final class Speed with Loggable {
  final double value;
  final double accuracy;

  const Speed(this.value, this.accuracy);

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
      ..prop('accuracy', accuracy, hidden: true); // For GUI
  }
}

log.d('Point (short)', data: Point(51.894167, 1.482222));
log.d('Speed (short)', data: Speed(143, 2.5));
```

![Property configuration](screenshots/loggable_2.png)

#### Multi View

```dart
final class RouteInfo with Loggable {
  final List<Point> points;
  final Duration duration;
  final double distance;

  const RouteInfo({
    required this.points,
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
          LoggableView(duration.inMinutes, 'min'),
        ]),
      )
      ..prop(
        'distance',
        distance,
        view: LoggableMultiView([
          LoggableView(distance.toStringAsFixed(1), 'km'),
          LoggableView((distance / 1.852).toStringAsFixed(1), 'NM'),
        ]),
      )
      ..prop('points', points);
  }
}

final routeInfo = RouteInfo(
  points: [Point(51.894167, 1.482222), Point(51.47, -0.179444)],
  duration: Duration(minutes: 90),
  distance: 124,
);

log.d('Route info', data: routeInfo);
```

![Multi view](screenshots/loggable_3.png)

#### Map and Builder Helpers

For quick property collection or third-party objects, use `Loggable.mapBuilder`
or `Loggable.builder`:

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

![Map and builder helpers](screenshots/loggable_4.png)

---

#### Custom Type Converters

To format third-party classes that cannot implement the `Loggable` mixin
directly, register a `LoggableTypeConverter`:

```dart
class MyConverter implements LoggableTypeConverter<NotLoggableObject> {
  @override
  String call(
    NotLoggableObject obj,
    LogTheme theme,
    int depth,
    LoggableResolvedConfig config,
  ) {
    final loggable = Loggable.builder(obj)
      ..prop('weight', obj.weight, units: 'kg')
      ..prop('height', obj.height, units: 'm');

    return loggable.toLogString(theme: theme, depth: depth, config: config);
  }
}

final notLoggableObject = NotLoggableObject(85.5, 1.80);
log.d('NotLoggableObject (toString)', data: notLoggableObject);

Loggable.registerTypeConverter(MyConverter());
log.d('NotLoggableObject (MyConverter)', data: notLoggableObject);
```

![Custom type converters](screenshots/loggable_5.png)

---

### 4. Colors & Dynamic Themes

`team_logger` supports color-coded and structured console output using
the [ansi_escape_codes](https://pub.dev/packages/ansi_escape_codes) package.

#### Active vs. Inactive Mode
To keep console output clean without losing execution context, `team_logger` supports Active and Inactive styling modes:
*   **Active Theme** (`theme`): Applied to logs that match active namespaces, level thresholds, active trace groups, or tags.
*   **Inactive Theme** (`inactiveTheme`): Applied to other logs. These logs are printed using lower-contrast colors (such as dimmed grays), keeping background context visible without cluttering the output of high-priority events.

```dart
final activeTheme = LogMainTheme.defaultActiveTheme;
final inactiveTheme = LogMainTheme.defaultInactiveTheme; // Pre-configured dimmed theme
```

#### Color Themes & Palettes

The package includes several pre-configured theme options:
*   **Grayscale Palettes**: `LogThemeData.gray5` to `LogThemeData.gray20`, providing gray tones to match dark or light terminal backgrounds.
*   **RGB Palettes**: Color configurations named after coordinate values, such as `rgb411` (red for errors), `rgb431` (gold for warnings), and `rgb234` (blue for info logs).

#### Granular Component Styling
`LogThemeData` allows you to customize the `ansi.Style` (foreground, background, bold, italic, underline) of each component:

```dart
final myCustomTheme = LogThemeData.seed(
  normal: const ansi.Style(foreground: ansi.rgb555), // White text
  emphasis: const ansi.Style(foreground: ansi.rgb530, bold: true), // Orange text
  dim: const ansi.Style(foreground: ansi.gray8), // Dimmed text
  punctuation: const ansi.Style(foreground: ansi.rgb333), // Braces and colons
  dataNameStyle: const ansi.Style(foreground: ansi.rgb245, italic: true), // Class names
  dataKeyStyle: const ansi.Style(foreground: ansi.rgb444, bold: true), // Keys
  dataValueStyle: const ansi.Style(foreground: ansi.rgb555), // Values
  depthThemes: [
    // Depth styling configurations
  ],
);
```

#### Dynamic Depth Color Shifting (`LogDepthTheme`)
To improve readability of nested collections (maps, lists, or custom objects), `team_logger` supports depth-based color configurations. By specifying a list of `LogDepthTheme` configs, brackets and punctuation colors shift dynamically based on their nesting level:

```dart
final customDepthThemeData = LogThemeData.seed(
  depthThemes: const [
    LogDepthTheme(
      brackets: ansi.rgb355, // Blue brackets at depth 0
      punctuation: ansi.gray10,
    ),
    LogDepthTheme(
      brackets: ansi.rgb535, // Purple brackets at depth 1
      punctuation: ansi.gray8,
    ),
    LogDepthTheme(
      brackets: ansi.rgb553, // Yellow brackets at depth 2
      punctuation: ansi.gray6,
    ),
  ],
);
```

Nested elements shift themes sequentially (`depth % depthThemes.length`), allowing distinct colors to mark different hierarchy levels.

---

### 5. Console BBCode Tags

The `BbCodeFormatter` parses BBCode tags in log messages to apply styles defined in the active theme:

| Tag | Result |
| :--- | :--- |
| `[b]bold text[/b]` | Bold text |
| `[success]Operation completed[/success]` | Success style (Green) |
| `[error]Failure[/error]` | Error style (Red) |
| `[warning]Caution[/warning]` | Warning style (Gold) |

---

### 6. Circular Buffer (`LogStorage`)

`LogStorage` retains a fixed count of logs in memory. This is designed for capturing diagnostic snapshots, telemetry display in debug screens, or passing logs to local storage.

```dart
final logStorage = LogStorage(maxCount: 100);

// Attach to the logger publisher
log.publisher = MultiPublisher([
  ConsoleLogPrinter(rows: [...]),
  logStorage,
]);

// Retrieve the in-memory log history
List<Log> history = logStorage.snapshot();
```

---

## License

This library is licensed under the MIT License. See [LICENSE](file:///Users/user/development/my/team_logger/LICENSE) for details.
