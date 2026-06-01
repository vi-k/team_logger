import 'package:example/readme_examples/default_log.dart';
import 'package:team_logger/team_logger.dart';

final class NotLoggableObject {
  final double weight;
  final double height;

  NotLoggableObject(this.weight, this.height);
}

void run() {
  final notLoggableObject = NotLoggableObject(85.5, 1.80);

  log.d(
    'Quick Info',
    data: Loggable.mapBuilder()
      ..prop('weight', notLoggableObject.weight, units: 'kg')
      ..prop('height', notLoggableObject.height, units: 'm'),
  );

  log.d(
    'Quick Info',
    data: Loggable.builder(notLoggableObject)
      ..prop('weight', notLoggableObject.weight, units: 'kg')
      ..prop('height', notLoggableObject.height, units: 'm'),
  );
}
