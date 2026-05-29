import 'package:example/readme_examples/log.dart';
import 'package:team_logger/team_logger.dart';

import 'point2.dart';

final class RouteInfo with Loggable {
  final Duration duration;
  final double distance;

  const RouteInfo({required this.duration, required this.distance});

  @override
  void collectLoggableData(LoggableData data) {
    data
      ..prop(
        'duration',
        duration,
        view: LoggableMultiView([
          LoggableView(duration),
          LoggableView(duration.inMinutes, 'min'),
        ]),
      )
      ..prop(
        'distance',
        distance,
        view: LoggableMultiView([
          LoggableView(distance.toStringAsFixed(1), 'km'),
          LoggableView((distance / 1.852).toStringAsFixed(1), 'NM'),
        ]),
      );
  }
}

void run() {
  final routeInfo = RouteInfo(duration: Duration(minutes: 90), distance: 124);

  log.d('Route info', data: routeInfo);
}
