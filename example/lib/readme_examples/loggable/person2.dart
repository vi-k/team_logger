import 'package:example/readme_examples/default_log.dart';
import 'package:team_logger/team_logger.dart';

final class Person with Loggable {
  final String name;
  final int age;

  const Person(this.name, this.age);

  @override
  void collectLoggableData(LoggableData data) {
    data
      ..prop('name', name)
      ..prop('age', age);
  }
}

void run() {
  log.d('Person (Loggable)', data: Person('John', 42));
}
