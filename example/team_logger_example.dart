import 'dart:async';
import 'dart:developer' as developer;

import 'package:ansi_escape_codes/ansi_escape_codes.dart';
import 'package:ansi_escape_codes/extensions.dart';
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
  final theme = LogTheme.defaultTheme.copyWith(
    // padding: '.',
    // paddingStyle: const LogStyle.oneForAll(ansi.rgb012),
    // maxLength: 140,
    maxLines: 20,
    // maxLines: 1,
  );

  // final log = Logger('app') //.withAddedName('network')
  final log = Logger('app')
    ..level = LogLevels.all
    ..publisher = ConsoleLogPrinter(
      theme: theme,
      // output: print,
      formatters: [
        const LogSequenceNumFormatter(),
        const LogLevelFormatter.short(),
        MyLogTimeAndPathFormatter(
          getRealTime: (log) => log.time.add(const Duration(milliseconds: 123)),
        ),
        // const LogPathFormatter(),
        LogMessageFormatter(
          constraints: const Constraints.exact(80),
          dataPreFormatter: const ControlCodeLogPreFormatter(),
          messagePreFormatter: MultiLogPreFormatter([
            const ControlCodeLogPreFormatter(),
            BbCodeLogPreFormatter(
              formatters: {
                'b': BbCodeFormat.colorize(theme.bold),
                'ok': const BbCodeFormat.colorize(
                  LogStyle.oneForAll(ansi.rgb050),
                ),
                'trace': const BbCodeFormat.colorize(
                  LogStyle.oneForAll(ansi.magenta),
                ),
                'signal': const BbCodeFormat.colorize(
                  LogStyle.oneForAll(
                    ansi.Style(
                      foreground: Color256.rgb055,
                      background: Color256.rgb011,
                    ),
                  ),
                ),
                'error': BbCodeFormat.colorize(
                  LogStyle.oneForAll(theme.normal.error),
                ),
              },
            ),
          ]),
        ),
        // const LogMessageFormatter(constraints: Constraints.exact(20)),
        // const LogMessageFormatter(constraints: Constraints(min: 100)),
        const LogSystemTagsFormatter(),
        const LogTagsFormatter(),
      ],
    );

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
      'point': {'lat': '43.249473', 'lon': '76.939319'},
      'client_name': 'Кондитер',
    },
    {
      'id': 1706,
      'name': 'Continental, бассейн',
      'type': 'other',
      'address': 'пр. Сейфуллина, 404',
      'address_ru': 'пр. Сейфуллина, 404',
      'address_kk': '',
      'point': {'lat': '43.267741', 'lon': '76.932179'},
      'client_name': 'Бассейн треня',
    },
    {
      'id': 1844,
      'name': '',
      'type': 'other',
      'address': 'улица Байтурсынова, 147а',
      'address_ru': 'улица Байтурсынова, 147а',
      'address_kk': 'Байтұрсынов көшесі, 147а',
      'point': {'lat': '43.23288724409935', 'lon': '76.93205011077225'},
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

  final networkLog = log.withChangedName('network');
  final eventLog = log.withChangedName('events').withAddedName('polling');

  for (var i = 0; i < 1; i++) {
    for (final level in LogLevels.values) {
      eventLog[level].log('Loggable object', data: loggableObject);

      networkLog[level].log(
        'POST https://test-api.tezapp.org/[b]locations/address-by-point[/b]',
        data: MultiData({'HEADERS': postHeaders, 'BODY': postBody}),
        tags: ['post', 'api'],
      );
      networkLog[level].log(
        '[ok][[200]][/ok] RESPONSE for https://test-api.tezapp.org/[b]clients/addresses?[/b]',
        tags: ['response', 'api'],
        data: succesResponse,
      );
      // log[level].log(
      //   '[error][[500]][/error] RESPONSE for https://test-api.tezapp.org/[b]clients/addresses?[/b]',
      //   tags: ['response', 'api'],
      //   data: errorResponse,
      // );
    }
  }

  const showIndexes = true;
  const maxLength = 69;
  // const maxLength = 49;
  // const maxLength = 20;
  const int? maxCount = null;
  // const maxCount = 2;
  const units = 'm/s';
  print('-' * maxLength);
  const level = LogLevels.debug;
  final list = theme.normal[level](
    Loggable.listToString(
      [
        [1234567890],
        [1234567890],
        [1234567890],
      ],
      theme: theme.toDataTheme(level),
      showIndexes: showIndexes,
      units: units,
      maxLength: maxLength,
      maxCount: maxCount,
    ),
  );
  final set = theme.normal[level](
    Loggable.setToString(
      {
        {1234567890},
        {1234567890},
        {1234567890},
      },
      theme: theme.toDataTheme(level),
      showIndexes: showIndexes,
      units: units,
      maxLength: maxLength,
      maxCount: maxCount,
    ),
  );
  final iterable = theme.normal[level](
    Loggable.iterableToString(
      [
        [1234567890].skip(0),
        [1234567890].skip(0),
        [1234567890].skip(0),
      ],
      theme: theme.toDataTheme(level),
      showIndexes: showIndexes,
      units: units,
      maxLength: maxLength,
      maxCount: maxCount,
    ),
  );
  print(list);
  print(set);
  print(iterable);
  print('-' * maxLength);

  final parser = ansi.Parser(list);
  print(
    'length: ${list.length}'
    ', parser.length: ${parser.length}'
    ', text.lengthWithoutEscapeCodes: ${list.lengthWithoutEscapeCodes}',
  );
  print(parser.showControlFunctions());
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
    ..list('points', points, maxCount: 2)
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

final class MyLogTimeAndPathFormatter implements LogTimeFormatter {
  final DateTime Function(Log log) getRealTime;
  final LogStyle? style;
  final Constraints constraints;
  final bool microseconds;
  final bool utc;

  const MyLogTimeAndPathFormatter({
    required this.getRealTime,
    this.style,
    this.constraints = const Constraints.unlimited(),
    this.microseconds = false,
    this.utc = false,
  });

  @override
  LogFormatterBox call(Log log, LogTheme theme, int? maxWidth) {
    final pathStyle = (style ?? theme.path)[log.level];
    final timeStyle = (style ?? theme.time)[log.level];
    final dimStyle = (style ?? theme.dim)[log.level];
    final localTime = LogTimeFormatter.timeToString(
      utc ? log.time.toUtc() : log.time,
      microseconds: microseconds,
    );
    final realTime = LogTimeFormatter.timeToString(
      utc ? getRealTime(log).toUtc() : getRealTime(log),
      microseconds: microseconds,
    );

    final pathStr = pathStyle('[${log.path}]');
    final localTimeStr = '${dimStyle('L')}${timeStyle(localTime)}';
    final realTimeStr = '${dimStyle('R')}${timeStyle(realTime)}';

    return LogFormatterBox(
      log,
      theme,
      theme.maxLines == 1
          ? ['$localTimeStr $realTimeStr $pathStr']
          : [pathStr, localTimeStr, realTimeStr],
      constraints: constraints.restrict(maxWidth),
    );
  }
}
