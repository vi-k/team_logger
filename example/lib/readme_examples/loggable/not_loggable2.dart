import 'package:example/readme_examples/default_log.dart';
import 'package:team_logger/team_logger.dart';

final class NotLoggableObject {
  final double weight;
  final double height;

  NotLoggableObject(this.weight, this.height);
}

class MyConverter implements LoggableTypeConverter<NotLoggableObject> {
  @override
  LoggableData convertToData(NotLoggableObject obj) => Loggable.builder(obj)
    ..prop('weight', obj.weight, units: 'kg')
    ..prop('height', obj.height, units: 'm');
}

void run() {
  final notLoggableObject = NotLoggableObject(85.5, 1.80);

  log.d('NotLoggableObject (toString)', data: notLoggableObject);

  Loggable.registerTypeConverter(MyConverter());

  log.d('NotLoggableObject (myConverter)', data: notLoggableObject);

  // A converter is removed by its target type, not by the converter's.
  Loggable.unregisterTypeConverter<NotLoggableObject>();
}
