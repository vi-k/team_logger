import 'dart:async';

import 'package:team_logger/team_logger.dart';

import 'data.dart';

final theme = LogTheme.defaultActiveTheme.copyWith(
  hiddenStyle: LogTheme.defaultActiveTheme.hiddenStyle.resetInvisible,
);
final inactiveTheme = LogTheme.defaultInactiveTheme.copyWith(
  hiddenStyle: LogTheme.defaultInactiveTheme.hiddenStyle.resetInvisible,
  // minLevel: LogLevels.debug,
);

final logStorage = LogStorage(maxCount: 100);

final log = Logger('app')
  ..level = LogLevels.all
  ..publisher = MultiPublisher(
    [
      ConsoleLogPrinter(
        theme: theme,
        inactiveTheme: inactiveTheme,
        isLogActive: (log) => true,
        // activeLevel: LogLevels.error,
        // activeLoggers: {'events'},
        // activeTraceGroups: {'feature'},
        // activeTags: {'response'},
        // isLogActive: (log) => log.hasData,
        rows: const [
          // LogRow.singleLine(
          LogRow(
            maxLength: 140,
            maxLines: 20,
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
          // LogRow.singleLine(
          LogRow(
            maxLength: 100,
            when: _hasStackTrace,
            // alignTail: false,
            children: [
              LogSequenceNum(hidden: true),
              LogLevelName.short(hidden: true),
              LogTime.onlyTime(hidden: true),
              LogPath(hidden: true),
              LogTraceId(hidden: true),
              LogStackTrace(),
            ],
            tail: [
              LogTags(hidden: true),
            ],
          ),
        ],
      ),
      logStorage,
    ],
  );

void main() {
  runZoned(
    f,
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
        eventLog[level].log('Loggable object', data: Data.loggableObject);

        final httpTraceId = TraceId.auto('http');

        httpLog[level].log(
          Data.postUrl,
          traceId: httpTraceId,
          data: LoggableMultiData(
            {
              'HEADERS': Data.postHeaders,
              'BODY': Data.postBody,
            },
            config: const LoggableConfig(collectionMaxLength: 2),
          ),
          tags: ['post'],
        );
        httpLog[level].log(
          '[success][200 OK][/success] ${Data.postUrl}',
          traceId: httpTraceId,
          data: Loggable.from(
            Data.succesResponse,
            config: const LoggableConfig(collectionMaxLength: 2),
          ),
          tags: ['response'],
        );

        if (level >= LogLevels.error) {
          httpLog[level].log(
            '[500 Internal Server Error] ${Data.postUrl}',
            traceId: httpTraceId,
            data: Data.errorResponse,
            tags: ['response', 'error'],
          );
        }
      });
    }
  }

  log.d(
    'json',
    data: Loggable.from(
      Data.json,
      config: const LoggableConfig(collectionMaxLength: 2),
    ),
  );
  log.d(
    '',
    data: LoggableMultiData(
      {'JSON': Data.json},
      config: const LoggableConfig(collectionMaxLength: 2),
    ),
  );
  log.d(
    '',
    data: Loggable.from(
      Data.json,
      config: const LoggableConfig(collectionMaxLength: 2),
    ),
  );

  for (final l in LogLevels.values) {
    log[l].log(
      '',
      data: Loggable.from(
        Data.listOfLists,
        config: const LoggableConfig(collectionMaxLength: 2),
      ),
    );
  }

  log.d('LogTheme', data: theme);
  for (final l in LogLevels.values) {
    log[l].log(
      'LogLevelTheme',
      traceId: TraceId.auto('theme'),
      data: theme[l],
    );
  }

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
    'enums',
    data: {
      'textAlign': LogTextAlign.left,
      'verticalAlign': LogVerticalAlign.top,
    },
  );
  log.d(
    'wrapped enums',
    data: Loggable.from(
      {
        'textAlign': LogTextAlign.left,
        'verticalAlign': LogVerticalAlign.top,
      },
      config: const LoggableConfig(enumDotShorthand: false),
    ),
  );

  log.d('list', data: [1, 2, 3]);
  log.d(
    'wrapped list',
    data: Loggable.from(
      [1, 2, 3],
      config: const LoggableConfig(collectionMaxLength: 2),
    ),
  );

  const notLoggableObject = NotLoggableObject('abc', [1, 2, 3]);
  log.d('NotLoggableObject', data: notLoggableObject);
  log.d(
    'NotLoggableObject',
    data: Loggable.builder(notLoggableObject)
      ..prop('name', notLoggableObject.name)
      ..prop('list', notLoggableObject.list),
  );
  Loggable.registerTypeConverter<NotLoggableObject>(
    NotLoggableObjectConverter(),
  );
  log.d('NotLoggableObject', data: notLoggableObject);
  Loggable.registerTypeConverter<NotLoggableObject>(
    ManualNotLoggableObjectConverter(),
  );
  log.d('NotLoggableObject', data: notLoggableObject);
  Loggable.unregisterTypeConverter<NotLoggableObject>();
  log.d('NotLoggableObject', data: notLoggableObject);

  log.d(
    'map',
    data: {'a': 1, 'b': 2, 'c': 3},
  );
  log.d(
    'built map',
    data: Loggable.mapBuilder()
      ..prop('a', 1, units: 'kg')
      ..prop('b', 2, units: 'm')
      ..prop('c', 3, units: 'sec'),
  );

  log.d(
    'storage snapshot',
    data: Loggable.from(
      logStorage.snapshot(),
      config: const LoggableConfig(collectionMaxLength: 3),
    ),
  );

  log.d(
    'double',
    data: Loggable.from(
      123456.0,
      config: const LoggableConfig(doubleFormat: '.2f', units: 'kg'),
    ),
  );

  log.d(
    'int',
    data: Loggable.from(
      123456,
      config: const LoggableConfig(intFormat: ' d', units: 'items'),
    ),
  );

  const duration = Duration(seconds: 5023);
  log.d('duration', data: duration);
}
