import 'package:example/readme_examples/default_log.dart';
import 'package:team_logger/team_logger.dart';

final class Speed with Loggable {
  final double value;
  final double accuracy;

  const Speed(this.value, this.accuracy);

  @override
  void collectLoggableData(LoggableData data) {
    data
      ..prop('value', value)
      ..prop('accuracy', accuracy);
  }
}

void run() {
  log.d('Speed (full)', data: Speed(143, 2.5));
}
