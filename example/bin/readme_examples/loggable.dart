import 'package:team_logger/team_logger.dart';

final log = Logger('app')
  ..level = LogLevels.all
  ..publisher = ConsoleLogPrinter(
    theme: LogMainTheme.defaultActiveTheme,
    rows: const [
      LogRow(
        maxLength: 100,
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
  const point1 = Point(51.894167, 1.482222);
  const point2 = Point(51.47, -0.179444);
  log.d('Sealand', data: point1);
  log.d('London Heliport', data: point2);

  const routeInfo = RouteInfo([point1, point2], Duration(minutes: 50), 124.5);
  log.d('Route from Sealand to London Heliport', data: routeInfo);
}

final class Point with Loggable {
  final double lat;
  final double lon;

  const Point(this.lat, this.lon);

  @override
  void collectLoggableData(LoggableData data) {
    data
      ..showName = false
      ..fixed('lat', lat, 5, showName: false)
      ..fixed('lon', lon, 5, showName: false);
  }
}

final class RouteInfo with Loggable {
  final List<Point> points;
  final Duration duration;
  final double distance;

  const RouteInfo(this.points, this.duration, this.distance);

  @override
  void collectLoggableData(LoggableData data) {
    data
      ..prop(
        'duration',
        duration,
        view: LoggableView(duration.inMinutes, 'min'),
      )
      ..prop(
        'distance',
        distance,
        view: LoggableMultiView(
          [
            LoggableView(distance.toStringAsFixed(1), 'km'),
            LoggableView((distance / 1.852).toStringAsFixed(1), 'NM'),
          ],
          separator: ' / ',
        ),
      )
      ..prop('points', points);
  }
}
