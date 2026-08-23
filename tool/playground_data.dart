import 'package:team_logger/team_logger.dart';

// ignore: avoid_classes_with_only_static_members
abstract final class Data {
  // Everything below is synthetic demo data.
  static const postUrl =
      '[b]POST[/b] https://api.example.com/[b]clients/addresses[/b]';

  static const postHeaders = {
    'content-type': 'application/json',
    'accept': 'application/json',
    'the-timezone-iana': 'Europe/London',
    'connection-type': 'wifi',
    'platform': 'android',
    'device-id': '00000000-1111-2222-3333-444444444444',
    'Device-Type': 'Demo Phone X',
    'Device-OS-Version': '16',
    'App-Version': '1.8.25',
    'App-Build': '164',
    'authorization':
        'Bearer eyJhbGciOiJub25lIiwidHlwIjoiSldUIn0.eyJ1c2VyX2lkIjo0MiwidXNlcl90eXBlIjoiZGVtbyIsInNlc3Npb25faWQiOjF9.fake-signature-for-docs',
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

  static const postBody = {
    'point': {'lon': '23.4567890', 'lat': '12.3456780'},
    'allow_outside_area': false,
  };

  static const succesResponse = [
    {
      'id': 1704,
      'name': 'Cake Lab, кондитерская',
      'type': 'work',
      'address': 'ул. Вымышленная, 91',
      'address_ru': 'ул. Вымышленная, 91',
      'address_kk': '',
      'points': [
        {'lat': '12.349473', 'lon': '23.439319'},
      ],
      'client_name': 'Кондитер',
    },
    {
      'id': 1706,
      'name': 'Aqua Club, бассейн',
      'type': 'other',
      'address': 'пр. Демонстрационный, 404',
      'address_ru': 'пр. Демонстрационный, 404',
      'address_kk': '',
      'points': [
        {'lat': '12.367741', 'lon': '23.432179'},
      ],
      'client_name': 'Бассейн',
    },
    {
      'id': 1844,
      'name': '',
      'type': 'other',
      'address': 'улица Примерная, 147а',
      'address_ru': 'улица Примерная, 147а',
      'address_kk': 'Мысал көшесі, 147а',
      'points': [
        {'lat': '12.33288724409935', 'lon': '23.43205011077225'},
      ],
      'client_name': 'Salon',
    },
  ];

  static const errorResponse = {'code': 50000, 'error': 'Something went wrong'};

  static const loggableObject = LoggableObject(
    id: 1,
    duration: Duration(seconds: 143),
    bearing: 90,
    speed: 10,
    distance: 100,
    point: Point(12.345678, 23.456789),
    points: [
      Point(12.345678, 23.456789),
      Point(12.333664, 23.411589),
      Point(12.196249, 23.484717),
    ],
    destinations: {
      'a': [
        Point(12.345678, 23.456789),
        Point(12.333664, 23.411589),
        Point(12.196249, 23.484717),
      ],
      'b': [
        Point(12.345678, 23.456789),
        Point(12.333664, 23.411589),
        Point(12.196249, 23.484717),
      ],
    },
  );

  static const json = {
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

  static const _list1 = [1, 2, 3];
  static const _list2 = [_list1, ..._list1];
  static const _list3 = [_list2, ..._list1];
  static const listOfLists = [_list3, ..._list1];
}

final class LoggableObject with Loggable {
  final int id;
  final Duration duration;
  final int bearing;
  final int speed;
  final int distance;
  final Point point;
  final List<Point> points;
  final Map<String, List<Point>> destinations;

  const LoggableObject({
    required this.id,
    required this.duration,
    required this.bearing,
    required this.speed,
    required this.distance,
    required this.point,
    required this.points,
    required this.destinations,
  });

  @override
  void collectLoggableData(LoggableData data) => data
    ..name = '$LoggableObject'
    ..prop('id', id)
    ..prop('point', point)
    ..prop(
      'duration',
      duration,
      view: LoggableMultiView([
        LoggableView(duration),
        LoggableView(duration.inMinutes, units: 'min'),
        LoggableView(duration.inSeconds, units: 'sec'),
      ]),
    )
    ..prop('bearing', bearing, units: '°')
    ..prop(
      'speed',
      speed,
      units: 'm/s',
      view: LoggableMultiView([
        LoggableView(speed, units: 'm/s'),
        LoggableView(speed * 3.6, units: 'km/h'),
      ]),
    )
    ..prop('distance', distance, units: 'm')
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
    ..round('lat', lat, precision: 5, showName: false)
    ..round('lon', lon, precision: 5, showName: false);
}

final class NotLoggableObject {
  final String name;
  final List<int> list;

  const NotLoggableObject(this.name, this.list);

  @override
  String toString() => '$NotLoggableObject(name: $name, list: $list)';
}

final class NotLoggableObjectConverter
    implements LoggableTypeConverter<NotLoggableObject> {
  @override
  LoggableData convertToData(NotLoggableObject obj) => Loggable.builder(obj)
    ..prop('name', obj.name)
    ..prop('list', obj.list);
}
