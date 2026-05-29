import 'package:example/readme_examples/log.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:team_logger/team_logger.dart';

part 'person3.freezed.dart';

@freezed
abstract class Person with _$Person, Loggable {
  const Person._(); // define a private empty constructor

  const factory Person(String name, int age) = _Person;

  @override
  void collectLoggableData(LoggableData data) {
    data
      ..name =
          'Person' // change the name, otherwise _Person will be used as the name
      ..prop('name', name)
      ..prop('age', age);
  }
}

void run() {
  log.d('Person (freezed)', data: Person('John', 42));
}
