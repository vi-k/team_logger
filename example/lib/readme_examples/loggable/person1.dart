import 'package:example/readme_examples/default_log.dart';

final class Person {
  final String name;
  final int age;

  const Person(this.name, this.age);

  @override
  String toString() => 'Person(name: $name, age: $age)';
}

void run() {
  log.d('Person (usual)', data: Person('John', 42));
}
