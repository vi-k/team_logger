import 'package:example/readme_examples/default_log.dart';
import 'package:team_logger/team_logger.dart';

final class Speed with Loggable {
  final double value;
  final double accuracy;

  const Speed(this.value, this.accuracy);

  @override
  void collectLoggableData(LoggableData data) {
    data
      ..showName = false
      ..showBrackets = false
      ..prop(
        'value',
        value,
        showName: false,
        view: '${value.toStringAsFixed(1)}±${accuracy.toStringAsFixed(1)}',
        units: 'm/s',
      )
      ..prop('accuracy', accuracy, hidden: true); // For GUI
  }
}

void run() {
  log.d('Speed (short)', data: Speed(143, 2.5));
}
