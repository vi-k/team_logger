import 'dart:async';

import 'package:example/data.dart';
import 'package:format/format.dart';
import 'package:stack_trace/stack_trace.dart';
import 'package:team_logger/team_logger.dart';

final theme = LogMainTheme.defaultActiveTheme.copyWith(
  // hiddenStyle: LogMainTheme.defaultActiveTheme.hiddenStyle.resetInvisible,
  numberFormatter: (theme, value, pattern) => format(pattern, value),
);
final inactiveTheme = LogMainTheme.defaultInactiveTheme.copyWith(
  // hiddenStyle: LogMainTheme.defaultInactiveTheme.hiddenStyle.resetInvisible,
  // minLevel: LogLevels.debug,
  numberFormatter: (theme, value, pattern) => format(pattern, value),
);

final logStorage = LogStorage(maxCount: 100);

final log = Logger('app')
  ..level = LogLevels.all
  ..publisher = MultiPublisher([
    ConsoleLogPrinter(
      theme: theme,
      // theme: LogMainTheme.noColors,
      // theme: LogMainTheme.noColorsNoTags,
      inactiveTheme: inactiveTheme,
      isLogActive: (log) => true,
      // activeLevel: LogLevels.error,
      // activeNamespaces: {'events'},
      // activeTraceGroups: {'feature'},
      // activeTags: {'response'},
      // isLogActive: (log) => log.hasData,
      rows: const [
        // LogRow.singleLine(
        LogRow(
          maxLength: 120,
          maxLines: 20,
          children: [
            LogNum(),
            LogLevelName.short(),
            LogTime.onlyTime(),
            LogPath(),
            LogTraceId(),
            LogMessage(showStackTrace: false),
          ],
          tail: [LogTags()],
        ),
        // LogRow.singleLine(
        LogRow(
          maxLength: 100,
          when: _hasStackTrace,
          // alignTail: false,
          children: [
            LogNum(hidden: true),
            LogLevelName.short(hidden: true),
            LogTime.onlyTime(hidden: true),
            LogPath(hidden: true),
            LogTraceId(hidden: true),
            LogStackTrace(),
          ],
          tail: [LogTags(hidden: true)],
        ),
      ],
    ),
    logStorage,
  ]);

void main() {
  runZoned(
    () => Chain.capture(
      f,
      onError: (error, stackTrace) {
        print('Unhandled exception:');
        print(error);
        print(stackTrace);
      },
    ),
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        for (final line in line.split('\n')) {
          parent.print(zone, 'I/flutter (31194): $line');
        }
      },
    ),
  );

  // ignore: discarded_futures
  logStorage.dispose();
}

bool _hasStackTrace(Log log) => log.stackTrace != null;

void f() {
  final httpLog = log.copyWith(name: 'network', tags: {'http'});
  final eventLog = log.copyWith(name: 'events').createChild(name: 'polling');

  for (var i = 0; i < 1; i++) {
    for (final level in LogLevels.values) {
      log.trace(TraceId.auto('feature'), () {
        eventLog[level].log(
          'Loggable [signal]object[/signal]',
          data: Data.loggableObject,
        );

        final httpTraceId = TraceId.auto('http');

        httpLog[level].log(
          Data.postUrl,
          traceId: httpTraceId,
          data: LoggableMultiData({
            '': Data.postBody,
            'HEADERS': Data.postHeaders,
          }, config: const LoggableConfig(collectionMaxCount: 2)),
          tags: ['post'],
        );
        httpLog[level].log(
          '[success][200 OK][/success] ${Data.postUrl}',
          traceId: httpTraceId,
          data: Data.succesResponse,
          config: const LoggableConfig(collectionMaxCount: 2),
          tags: ['response'],
        );

        httpLog[level].log(
          '[error][500 Internal Server Error][/error] ${Data.postUrl}',
          traceId: httpTraceId,
          data: Data.errorResponse,
          tags: ['response', 'error'],
        );
      });
    }
  }

  log.d(
    'json',
    data: Data.json,
    config: const LoggableConfig(collectionMaxCount: 2),
  );
  log.d(
    '',
    data: LoggableMultiData({
      'JSON': Data.json,
    }, config: const LoggableConfig(collectionMaxCount: 2)),
  );

  log.d(
    '',
    data: Data.json,
    config: const LoggableConfig(collectionMaxCount: 2),
  );

  for (final l in LogLevels.values) {
    log[l].log(
      '',
      data: Data.listOfLists,
      config: const LoggableConfig(collectionMaxCount: 2),
    );
  }

  log.d('$LogMainTheme', data: theme);
  for (final l in LogLevels.values) {
    log[l].log('$LogTheme', traceId: TraceId.auto('theme'), data: theme[l]);
  }
  log.d('LogMainTheme.noColors: ${LogMainTheme.noColors}');
  log.d('LogThemeData.noColors: ${LogThemeData.noColors}');
  log.d('LogTheme.noColors: ${LogTheme.noColors}');

  log.d('Without error', stackTrace: StackTrace.current);
  log.d('With error', error: Exception('test'), stackTrace: StackTrace.current);
  log.d(
    '',
    error: Exception('Without message'),
    stackTrace: StackTrace.current,
  );
  log.d(
    'With data and error',
    data: {'error': 'internal error', 'code': 500},
    error: Exception('test'),
    stackTrace: StackTrace.current,
  );
  log.d(
    'With multi data and error',
    data: LoggableMultiData({
      'RESPONSE': {'error': 'internal error', 'code': 500},
    }),
    error: Exception('test'),
    stackTrace: StackTrace.current,
  );

  log.d(
    'short enums',
    data: {
      'textAlign': LogTextAlign.left,
      'verticalAlign': LogVerticalAlign.top,
    },
  );
  log.d(
    'full enums',
    data: {
      'textAlign': LogTextAlign.left,
      'verticalAlign': LogVerticalAlign.top,
    },
    config: const LoggableConfig(enumDotShorthand: false),
  );

  log.d('list', data: [1, 2, 3]);
  log.d(
    'wrapped list',
    data: [1, 2, 3],
    config: const LoggableConfig(collectionMaxCount: 2),
  );

  const notLoggableObject = NotLoggableObject('abc', [1, 2, 3]);
  log.d('NotLoggableObject #1', data: notLoggableObject);
  log.d(
    'NotLoggableObject #2',
    data: Loggable.builder(notLoggableObject)
      ..prop('name', notLoggableObject.name)
      ..prop('list', notLoggableObject.list),
  );
  Loggable.registerTypeConverter<NotLoggableObject>(
    NotLoggableObjectConverter(),
  );
  log.d('NotLoggableObject #3', data: notLoggableObject);
  Loggable.unregisterTypeConverter<NotLoggableObject>();
  log.d('NotLoggableObject #4', data: notLoggableObject);

  log.d('map', data: {'a': 1, 'b': 2, 'c': 3});
  log.d(
    'built map',
    data: Loggable.mapBuilder()
      ..prop('a', 1, units: 'kg')
      ..prop('b', 2, units: 'm')
      ..prop('c', 3, units: 'sec'),
  );
  log.d(
    'built map',
    data: Loggable.mapBuilder(config: const LoggableConfig(units: 'm'))
      ..prop('a', 1)
      ..prop('b', 2)
      ..prop('c', 3),
  );

  log.d(
    'storage snapshot',
    data: logStorage.snapshot(),
    config: const LoggableConfig(collectionMaxCount: 2),
  );

  log.d(
    'double',
    data: 123456.0,
    config: const LoggableConfig(doubleFormat: '{:.2f}', units: 'kg'),
  );

  log.d(
    'int',
    data: 123456,
    config: const LoggableConfig(intFormat: '{: d}', units: 'items'),
  );

  log.d(
    'string without quotes',
    data: {
      'a': {'c': 'test'},
      'b': 'test',
    },
    config: const LoggableConfig(stringInQuotes: false, units: 'kg'),
  );

  log.d('map',
      data: Loggable.mapBuilder(config: LoggableConfig(units: 'm'))
        ..prop('a', 1)
        ..prop('b', 2)
        ..prop('c', 3));

  final point = Point(27.988056, 86.925278);
  log.d(
    'Mount Everest',
    data: Loggable.builder(point,
        showName: false,
        showBrackets: false,
        config: LoggableConfig(units: 'm'))
      ..prop('lat', point.lat, showName: false)
      ..prop('lon', point.lon, showName: false),
  );
}
