import 'package:example/readme_examples/log.dart';
import 'package:team_logger/team_logger.dart';

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

void run() {
  log.d('Point (full)', data: Point(51.894167, 1.482222));
}
