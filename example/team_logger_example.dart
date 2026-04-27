import 'dart:async';

import 'package:ansi_escape_codes/style.dart' as ansi;
import 'package:team_logger/team_logger.dart';

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

void f() {
  // final theme = LogTheme.defaultInactiveTheme.copyWith(
  final theme = LogTheme.defaultActiveTheme.copyWith(
    // padding: '.',
    // showIndexes: false,
    // showCount: false,
    hiddenStyle: LogTheme.defaultActiveTheme.hiddenStyle.resetInvisible,
  );

  final log = Logger('app')
    ..level = LogLevels.all
    ..publisher = ConsoleLogPrinter(
      theme: theme,
      rows: [
        // const LogRow.singleLine(
        const LogRow(
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
          maxLength: 110,
          maxLines: 20,
          when: (log) => log.stackTrace != null,
          alignTail: false,
          children: const [
            LogSequenceNum(hidden: true),
            LogStackTrace(showIndexes: true),
          ],
          tail: const [
            LogTags(hidden: true, tags: {'stacktrace'}),
          ],
        ),
      ],
    );

  log.d('test');
  log.d('test', data: null, traceId: TraceId.global());
  // return;

  final postHeaders = {
    'content-type': 'application/json',
    'accept': 'application/json',
    'the-timezone-iana': 'Asia/Almaty',
    'connection-type': 'wifi',
    'platform': 'android',
    'device-id': 'ef211e2c-29b8-4119-a4dd-d8c8b0c36324',
    'Device-Type': 'Samsung SM-A556E',
    'Device-OS-Version': '16',
    'App-Version': '1.8.25',
    'App-Build': '164',
    'authorization':
        'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoxODc0MiwidXNlcl90eXBlIjoiY2xpZW50Iiwic2Vzc2lvbl9pZCI6MzUzNzN9.LWgB2NPJKf6rQ5nhxtq3Eecc2o5I5Es-9kfLLjdxIUQ\n',
    'accept-language': 'ru',
    'null': null,
    'false': false,
    'true': true,
    'int': 42,
    'double': 123.456,
    'record': (12, 'abc', true, null),
    'list': [1, 2, 3],
    'map': {'a': 1, 'b': 2, 'c': 3},
    'set': {1, 2, 3},
    'control-codes': 'abc\ndef\tghi\rjkl\bmno',
  };
  final postBody = {
    'point': {'lon': '76.9456697', 'lat': '43.2308028'},
    'allow_outside_area': false,
  };
  final succesResponse = [
    {
      'id': 1704,
      'name': 'Sweet sisters.kz, кондитерская',
      'type': 'work',
      'address': 'ул. Кабанбай батыра, 91',
      'address_ru': 'ул. Кабанбай батыра, 91',
      'address_kk': '',
      'points': [
        {'lat': '43.249473', 'lon': '76.939319'},
      ],
      'client_name': 'Кондитер',
    },
    {
      'id': 1706,
      'name': 'Continental, бассейн',
      'type': 'other',
      'address': 'пр. Сейфуллина, 404',
      'address_ru': 'пр. Сейфуллина, 404',
      'address_kk': '',
      'points': [
        {'lat': '43.267741', 'lon': '76.932179'},
      ],
      'client_name': 'Бассейн треня',
    },
    {
      'id': 1844,
      'name': '',
      'type': 'other',
      'address': 'улица Байтурсынова, 147а',
      'address_ru': 'улица Байтурсынова, 147а',
      'address_kk': 'Байтұрсынов көшесі, 147а',
      'points': [
        {'lat': '43.23288724409935', 'lon': '76.93205011077225'},
      ],
      'client_name': 'Salon',
    }
  ];
  final errorResponse = {'code': 50000, 'error': 'Something went wrong'};

  final loggableObject = LoggableTest(
    id: 1,
    bearing: 90,
    speed: 10,
    distance: 100,
    createdAt: DateTime.now(),
    point: const Point(43.250229, 76.926352),
    points: const [
      Point(43.250229, 76.926352),
      Point(43.233664, 76.911589),
      Point(43.196249, 76.984717),
    ],
    destinations: {
      'a': const [
        Point(43.250229, 76.926352),
        Point(43.233664, 76.911589),
        Point(43.196249, 76.984717),
      ],
      'b': const [
        Point(43.250229, 76.926352),
        Point(43.233664, 76.911589),
        Point(43.196249, 76.984717),
      ],
    },
  );

  final networkLog = log.copyWith(name: 'network', tags: {'http'});
  final eventLog = log.copyWith(name: 'events').createChild(name: 'polling');

  for (var i = 0; i < 1; i++) {
    for (final level in LogLevels.values) {
      log.trace(TraceId.auto('feature'), () {
        eventLog[level].log('Loggable object', data: loggableObject);

        final httpTraceId = TraceId.auto('http');

        networkLog[level].log(
          'POST https://test-api.tezapp.org/[b]locations/address-by-point[/b]',
          traceId: httpTraceId,
          data: LoggableMultiData(
            {
              'HEADERS': postHeaders,
              'BODY': postBody,
            },
            collectionMaxCount: 2,
          ),
          tags: ['post'],
        );
        networkLog[level].log(
          '[success][200 OK][/success] RESPONSE for https://test-api.tezapp.org/[b]clients/addresses?[/b]',
          traceId: httpTraceId,
          data: LoggableObject(succesResponse, collectionMaxCount: 2),
          tags: ['response'],
        );
        log[level].log(
          '[error][500][/error] RESPONSE for https://test-api.tezapp.org/[b]clients/addresses?[/b]',
          traceId: httpTraceId,
          data: errorResponse,
          tags: ['response', 'error'],
        );
      });
    }
  }

  final json = {
    'active_cities': [
      {
        'id': 12,
        'title': 'Актобе',
        'is_active': true,
        'center_point': {'lat': '0.000000', 'lon': '0.000000'},
        'city_polygon': [
          [
            [56.897667241460255],
            [50.2187685702103],
            [11.111111],
            [22.222222],
            [56.897667241460255],
          ],
          [
            [56.950893744325896],
            [50.182233885471334],
            [11.111111],
            [22.222222],
            [56.950893744325896],
          ],
          [
            [56.9918157263381],
            [50.20415823088945],
            [11.111111],
            [22.222222],
            [56.9918157263381],
          ],
          [
            [57.02535158229375],
            [50.186004802921815],
            [11.111111],
            [22.222222],
            [57.02535158229375],
          ],
          [
            [11.111111],
            [11.111111],
            [11.111111],
            [11.111111],
          ],
          [
            [22.222222],
            [22.222222],
            [22.222222],
            [22.222222],
          ],
          [
            [56.897667241460255],
            [50.2187685702103],
            [11.111111],
            [56.897667241460255],
          ],
        ],
      },
    ],
  };

  log.v('json', data: LoggableObject(json, collectionMaxCount: 2));
  log.d('', data: LoggableNamedData('JSON', json, collectionMaxCount: 2));
  log.d('', data: LoggableObject(json, collectionMaxCount: 2));
  log.i('json', data: LoggableObject(json, collectionMaxCount: 2));

  const list = [
    [
      [
        [
          [
            [
              [
                [123],
              ]
            ]
          ]
        ]
      ]
    ]
  ];

  for (final l in LogLevels.values) {
    log[l].log('list', data: LoggableObject(list));
  }
  const list1 = [123, 234, 345];
  final list2 = [list1, ...list1];
  final list3 = [list2, ...list1];
  final list4 = [list3, ...list1];
  final list5 = [list4, ...list1];
  for (final l in LogLevels.values) {
    log[l].log(
      list4,
      data: LoggableObject(list4, collectionMaxCount: 2),
    );
  }

  // log.d('LogTheme', data: theme);
  for (final l in LogLevels.values) {
    log[l].log(
      'LogLevelTheme',
      traceId: TraceId.auto('theme'),
      data: theme[l],
      error: Exception('test'),
      stackTrace: StackTrace.current,
    );
  }

  // // log.d('    Info LogLevelTheme', data: theme[LogLevels.info]);
  // // log.w(' Warning LogLevelTheme', data: theme[LogLevels.warning]);
  // // log.e('   Error LogLevelTheme', data: theme[LogLevels.error]);
  // // log.critical('Critical LogLevelTheme', data: theme[LogLevels.critical]);

  print(
    ansi.bold(
      '${ansi.rgb540('[]')}' //+ yellow
      '${ansi.rgb051('[]')}' //+ green
      '${ansi.rgb025('[]')}' //+ blue
      // '${ansi.rgb530('[]')}' // +orange
      '${ansi.rgb145('[]')}' //+ cyan
      '${ansi.rgb515('[]')}' //+ magenta
      // '${ansi.rgb045('[]')}'
      // '${ansi.rgb035('[]')}'
      // '${ansi.rgb025('[]')}'
      // '${ansi.rgb115('[]')}' //?
      // '${ansi.rgb415('[]')}' //?
      // '${ansi.rgb425('[]')}'
      ,
    ),
  );
}

final class LoggableTest with Loggable {
  final int id;
  final int bearing;
  final int speed;
  final int distance;
  final DateTime createdAt;
  final Point point;
  final List<Point> points;
  final Map<String, List<Point>> destinations;

  const LoggableTest({
    required this.id,
    required this.bearing,
    required this.speed,
    required this.distance,
    required this.createdAt,
    required this.point,
    required this.points,
    required this.destinations,
  });

  @override
  void collectLoggableData(LoggableData data) => data
    ..name = 'LoggableTest'
    ..prop('id', id)
    ..prop('point', point)
    ..prop('bearing', bearing, units: '°')
    ..prop('speed', speed, units: 'm/s')
    ..prop('distance', distance, units: 'm')
    ..prop('createdAt', createdAt)
    ..prop('points', points, collectionMaxCount: 2)
    ..prop('destinations', destinations);
}

final class Point with Loggable {
  final double lat;
  final double lon;

  const Point(this.lat, this.lon);

  @override
  void collectLoggableData(LoggableData data) => data
    ..name = 'Point'
    ..showName = false
    ..prop('lat', lat, showName: false, view: lat.toStringAsFixed(5))
    ..prop('lon', lon, showName: false, view: lon.toStringAsFixed(5));
}
