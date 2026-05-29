import 'package:example/readme_examples/log.dart';
import 'package:team_logger/team_logger.dart';

final class NotLoggableObject {
  final double weight;
  final double height;

  NotLoggableObject(this.weight, this.height);
}

class MyConverter implements LoggableTypeConverter<NotLoggableObject> {
  @override
  String call(
    NotLoggableObject obj,
    LogTheme theme,
    int depth,
    LoggableResolvedConfig config,
  ) {
    final loggable = Loggable.builder(obj)
      ..prop('weight', obj.weight, units: 'kg')
      ..prop('height', obj.height, units: 'm');

    return loggable.toLogString(theme: theme, depth: depth, config: config);
  }
}

void run() {
  final notLoggableObject = NotLoggableObject(85.5, 1.80);

  log.d('NotLoggableObject (toString)', data: notLoggableObject);

  Loggable.registerTypeConverter(MyConverter());

  log.d('NotLoggableObject (myConverter)', data: notLoggableObject);

  Loggable.unregisterTypeConverter<MyConverter>();
}
