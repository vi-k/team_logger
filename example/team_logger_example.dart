import 'dart:async';

import 'package:team_logger/team_logger.dart';

import 'data.dart';

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
}

bool _hasStackTrace(Log log) => log.stackTrace != null;

void f() {
  final theme = LogTheme.defaultActiveTheme.copyWith(
    hiddenStyle: LogTheme.defaultActiveTheme.hiddenStyle.resetInvisible,
  );
  final inactiveTheme = LogTheme.defaultInactiveTheme.copyWith(
    hiddenStyle: LogTheme.defaultInactiveTheme.hiddenStyle.resetInvisible,
    // minLevel: LogLevels.debug,
  );

  final log = Logger('app')
    ..level = LogLevels.all
    ..publisher = ConsoleLogPrinter(
      theme: theme,
      inactiveTheme: inactiveTheme,
      isActive: (log) => true,
      // activeLevel: LogLevels.error,
      // activePaths: {'events'},
      // activeTraceGroups: {'feature'},
      // activeTags: {'response'},
      // isActive: (log) => log.hasData,
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
    );

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
          data: const LoggableMultiData(
            {
              'HEADERS': Data.postHeaders,
              'BODY': Data.postBody,
            },
            collectionMaxLength: 2,
          ),
          tags: ['post'],
        );
        httpLog[level].log(
          '[success][200 OK][/success] ${Data.postUrl}',
          traceId: httpTraceId,
          data: LoggableObject(Data.succesResponse, collectionMaxLength: 2),
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

  log.d('json', data: LoggableObject(Data.json, collectionMaxLength: 2));
  log.d(
    '',
    data: const LoggableMultiData({'JSON': Data.json}, collectionMaxLength: 2),
  );
  log.d('', data: LoggableObject(Data.json, collectionMaxLength: 2));

  for (final l in LogLevels.values) {
    log[l].log(
      '',
      data: LoggableObject(Data.listOfLists, collectionMaxLength: 2),
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
    data: const LoggableMultiData({
      'RESPONSE': {'error': 'internal error', 'code': 500},
    }),
    error: Exception('test'),
    stackTrace: StackTrace.current,
  );

  log.d(
    'Enums',
    data: {
      'textAlign': LogTextAlign.left,
      'verticalAlign': LogVerticalAlign.top,
    },
  );
}
