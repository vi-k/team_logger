import 'package:example/readme_examples/log.dart';
import 'package:team_logger/team_logger.dart';

final class Point with Loggable {
  final double lat;
  final double lon;

  const Point(this.lat, this.lon);

  @override
  void collectLoggableData(LoggableData data) {
    data
      ..showName = false
      ..fixed('lat', lat, 5, showName: false, units: '°')
      ..fixed('lon', lon, 5, showName: false, units: '°');
  }
}

void run() {
  log.d('Point (short)', data: Point(51.894167, 1.482222));
}
