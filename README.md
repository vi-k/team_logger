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

![Quick Start](screenshots/quick_start_1.png)


**Filter by sequence number**

All lines included in the message will be displayed.

![Filter #1](screenshots/quick_start_2.png)

**Filter by trace ID**

All messages sent within `log.trace` scope will be displayed.

![Filter #2](screenshots/quick_start_3.png)

**Filter by tag**

All messages with tag `#http` will be displayed.

![Filter #3](screenshots/quick_start_4.png)

---

## Deep Dive

### 1. Zone-Based Trace Propagation (`TraceId`)

Instead of passing correlation IDs manually through nested function calls, `team_logger` uses **Dart Zones** to associate a `TraceId` with all synchronous and asynchronous operations inside the execution context:

```dart
final searchTrace = TraceId.auto('search'); // Resolves to '#search-1'

log.trace(searchTrace, () async {
  log.d('Searching database...');           // Captures and outputs '#search-1'
  await Future.delayed(Duration(milliseconds: 100));
  log.i('Database fetch completed');        // Captures and outputs '#search-1'
});
```

Supported `TraceId` configurations:
*   `TraceId.auto(group)`: Automatically incremented IDs scoped to a specific group name.
*   `TraceId.global()`: Automatically incremented sequential IDs without a group prefix.
*   `TraceId.manual(group, num)`: Pre-defined IDs, useful when matching external transaction identifiers.

---

### 2. Formatting Complex Objects (`Loggable`)

Implementing the `Loggable` mixin on your data models allows you to format objects with specific controls for property visibility, units, floating-point precision, and display format.

```dart
final class UserPoint with Loggable {
  final double lat;
  final double lon;

  const UserPoint(this.lat, this.lon);

  @override
  void collectLoggableData(LoggableData data) {
    data
      ..name = 'Point'
      ..showName = false
      ..fixed('lat', lat, 5, showName: false)
      ..fixed('lon', lon, 5, showName: false);
  }
}

final class RouteInfo with Loggable {
  final int distance;
  final Duration duration;
  final UserPoint location;

  RouteInfo(this.distance, this.duration, this.location);

  @override
  void collectLoggableData(LoggableData data) {
    data
      ..name = 'RouteInfo'
      ..prop('distance', distance, units: 'm')
      ..prop(
        'duration',
        duration,
        view: LoggableView(duration.inSeconds, 'sec'),
      )
      ..prop('location', location);
  }
}
```

Formatting output:
```text
RouteInfo(distance: 120m, duration: 80sec, location: (43.24947, 76.93931))
```

#### Map and Builder Helpers
For quick property collection or third-party objects, use `Loggable.builder` or `Loggable.mapBuilder`:
```dart
log.d(
  'Quick Info',
  data: Loggable.mapBuilder()
    ..prop('weight', 85.5, units: 'kg')
    ..prop('height', 1.80, units: 'm'),
);
// Output -> Quick Info: {weight: 85.5kg, height: 1.80m}
```

---

### 3. Collection Truncation & Formatting

Large lists or maps can be truncated dynamically to show only the boundaries (first and last elements) using `LoggableConfig`:

```dart
log.d(
  'Coordinates list',
  data: [1.2, 2.3, 3.4, 4.5, 5.6],
  config: const LoggableConfig(
    collectionMaxLength: 3,         // Maximum items to print
    collectionShowLength: true,     // Appends total item count (e.g. ₌₅)
    collectionShowIndexes: true,    // Prefixes elements with subscript indexes (e.g. ₀:)
  ),
);
// Output -> Coordinates list: [₌₅ ₀:1.2, ₁:2.3, …, ₄:5.6]
```

---

### 4. Custom Type Converters

To format third-party classes that cannot implement the `Loggable` mixin directly, register a `LoggableTypeConverter`:

```dart
class NotLoggableObject {
  final String name;
  const NotLoggableObject(this.name);
}

class MyConverter implements LoggableTypeConverter<NotLoggableObject> {
  @override
  String call(NotLoggableObject obj, LogTheme theme, int depth, LoggableResolvedConfig config) {
    return '${theme.data.dataNameStyle('NotLoggableObject')}(name: ${obj.name})';
  }
}

// Register at application startup
Loggable.registerTypeConverter<NotLoggableObject>(MyConverter());
```

---

### 5. Circular Buffer (`LogStorage`)

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

### 6. Colors & Dynamic Themes

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

## Console BBCode Tags

The `BbCodeFormatter` parses BBCode tags in log messages to apply styles defined in the active theme:

| Tag | Result |
| :--- | :--- |
| `[b]bold text[/b]` | Bold text |
| `[success]Operation completed[/success]` | Success style (Green) |
| `[error]Failure[/error]` | Error style (Red) |
| `[warning]Caution[/warning]` | Warning style (Gold) |

---

## License

This library is licensed under the MIT License. See [LICENSE](file:///Users/user/development/my/team_logger/LICENSE) for details.
