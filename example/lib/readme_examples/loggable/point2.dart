import 'package:example/readme_examples/default_log.dart';
import 'package:team_logger/team_logger.dart';

final class Point with Loggable {
  final double lat;
  final double lon;

  const Point(this.lat, this.lon);

  @override
  void collectLoggableData(LoggableData data) {
    data
      ..showName = false
      ..round('lat', lat, precision: 5, showName: false, units: '°')
      ..round('lon', lon, precision: 5, showName: false, units: '°');
  }
}

void run() {
  log.d('Point (short)', data: Point(51.894167, 1.482222));
}
